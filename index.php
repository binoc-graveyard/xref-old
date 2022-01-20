<?php
error_reporting(E_ALL);
ini_set("display_errors", "on");

// ============================================================================

function pc_validate($user,$pass) {
  $users = array(
    'testout' => 'time03',
  );

  if (isset($users[$user]) && ($users[$user] == $pass)) {
    return true;
  }
  else {
    return false;
  }
}

// ============================================================================

// == | Function: funcError |==================================================

function funcError($_value) {
  die('Error: ' . $_value);
  
  // We are done here
  exit();
}

// ============================================================================

// == | Function: funcHTTPGetValue |===========================================

function funcHTTPGetValue($_value) {
  $_arrayGET = array_unique($_GET);
  if (!isset($_GET[$_value]) || $_GET[$_value] === '' || $_GET[$_value] === null || empty($_GET[$_value])) {
    return null;
  }
  else {  
    $_finalValue = preg_replace('/[^-a-zA-Z0-9_\-\/\{\}\@\.]/', '', $_GET[$_value]);
    return $_finalValue;
  }
}

// ============================================================================

// == | Function: funcCheckVar | ==============================================

function funcCheckVar($_value) {
  if ($_value === '' || $_value === 'none' || $_value === null || empty($_value)) {
    return null;
  }
  else {
    return $_value;
  }
}

// ============================================================================

// == | funcSendHeader | ======================================================

function funcSendHeader($_value) {
  $_arrayHeaders = array(
    '400' => 'HTTP/1.1 400 Bad Request',
    '404' => 'HTTP/1.0 404 Not Found',
    '501' => 'HTTP/1.0 501 Not Implemented',
    'html' => 'Content-Type: text/html',
    'text' => 'Content-Type: text/plain',
    'xml' => 'Content-Type: text/xml',
    'css' => 'Content-Type: text/css',
    'bin' => 'Content-Type: application/octet-stream'
  );
  
  if (array_key_exists($_value, $_arrayHeaders)) {
    @header($_arrayHeaders[$_value]);
    
    if ($_value == '404') {
      // We are done here
      exit();
    }
  }
}

// ============================================================================

// == | Function: funcRedirect |===============================================

function funcRedirect($_strURL) {
	header('Location: ' . $_strURL , true, 302);
  
  // We are done here
  exit();
}

// ============================================================================

// == | Functions: startsWith, endsWith, and contains |========================

function startsWith($haystack, $needle) {
   $length = strlen($needle);
   return (substr($haystack, 0, $length) === $needle);
}

function endsWith($haystack, $needle) {
  $length = strlen($needle);
  if ($length == 0) {
    return true;
  }
  return (substr($haystack, -$length) === $needle);
}

function contains($needle, $haystack) {
  return strpos($haystack, $needle) !== false;
}

// ============================================================================

// == | funcReadManifest | ====================================================

function funcReadManifest() {
  $_manifestFile = 'config.json';
  
  if (file_exists('./' . $_manifestFile)) {
    $_manifestFilePath = './' . $_manifestFile;
  }
  elseif (file_exists('../' . $_manifestFile)) {
    $_manifestFilePath = '../' . $_manifestFile;
  }
  elseif (file_exists('../datastore/' . $_manifestFile)) {
    $_manifestFilePath = '../datastore/' . $_manifestFile;
  }
  else {
    funcError('Could not find manifest file');
  }
  
  $_manifestRaw = file_get_contents($_manifestFilePath)
    or funcError('Could not find manifest file for ' . $_slug);
  $_manifest = json_decode($_manifestRaw, true);
  
  return $_manifest;
}

// ============================================================================

/**********************************************************************************************************************
* Splits a path into an indexed array of parts
*
* @param $aPath   URI Path
***********************************************************************************************************************/
function funcSplitPath($aPath) {
  if ($aPath == '/') {
    return null;
  }
  return array_values(array_filter(explode('/', $aPath), 'strlen'));
}

// == | Vars | ================================================================

$strRequestRaw = funcHTTPGetValue('raw');
$strRequestPath = funcHTTPGetValue('path');

$arrayManifest = funcReadManifest();
$arrayQueryString = funcCheckVar($_GET);
$strQueryString = '';

$arrayRequestPath = funcSplitPath($strRequestPath);

/*
$arrayRequestPath = array_replace_recursive(
  array(
    null,
    null,
    null
  ),
  explode('/', $strRequestPath)
);
*/

$strXRefTree = funcCheckVar($arrayRequestPath[0] ?? null);
$strXRefComponent = funcCheckVar($arrayRequestPath[1] ?? null);

/*
unset($arrayRequestPath[1]);
unset($arrayRequestPath[2]);
*/

if (count($arrayRequestPath) == 1) {
  $strCGIPathInfo = str_replace('/' . $strXRefTree, '', $strRequestPath);
}
elseif (count($arrayRequestPath) > 1) {
  $strCGIPathInfo = str_replace('/' . $strXRefTree . '/' . $strXRefComponent, '', $strRequestPath);
}
else {
  $strCGIPathInfo = '/';
}

//funcError(var_export($strCGIPathInfo, true));

$arrayValidXRefComponents = array(
  'find' => 'libs/mxr/find.cgi',
  'ident' => 'libs/mxr/ident.cgi',
  'search' => 'libs/mxr/search.cgi',
  'source' => 'libs/mxr/source.cgi'
);


// ============================================================================

// ==| Main |==================================================================

if ($_SERVER['REQUEST_URI'] == '/') {
  $strRequestPath = '/';
}

if (contains('.git/', $_SERVER['REQUEST_URI'])) {
  funcSendHeader('404');
}

if ($_SERVER['SERVER_NAME'] == 'xref.binaryoutcast.com') {
  funcRedirect('http://xref.palemoon.org' . $strRequestPath);
}

if (startsWith($strRequestPath, '/moonchild-central')) {
  funcRedirect('http://xref.palemoon.org' . str_replace('moonchild-central', 'goanna-central', $strRequestPath));
}

if ($strXRefTree == 'goanna-central' || $strXRefTree == 'xp-hackjob') {
  if (!pc_validate($_SERVER['PHP_AUTH_USER'] ?? null, $_SERVER['PHP_AUTH_PW'] ?? null)) {
    header('WWW-Authenticate: Basic realm="BinOC XRef"');
    header('HTTP/1.0 401 Unauthorized');
    echo "You need to enter a valid username and password.";
    exit;
  }
}

// This is the primary conditional to determine what we are gonna do.
// For XRef we will only consider running the CGI scripts if the URI
// '/[tree]/[script][...]' is valid. Tree is defined in config.json
// under 'active-sources' and 'inactive-sources' where-as script is
// defined under $arrayValidXRefComponents
// Root and Source index is handled in the additional elseif statements
if ($strXRefTree != null && startsWith($strRequestPath, '/' . $strXRefTree)) {
  if (array_key_exists($strXRefTree, $arrayManifest['active-sources']) || array_key_exists($strXRefTree, $arrayManifest['inactive-sources'])) {
    if ($strRequestPath == '/' . $strXRefTree) {
      funcRedirect('/' . $strXRefTree . '/');
    }
    elseif ($strRequestPath == '/' . $strXRefTree . '/') {
      $strPageContent = file_get_contents('./media/templates/template-source-index')
        or funcError('Unable to load source template');
      funcSendHeader('html');
      $strPageContent = str_replace('$treename', strtolower($strXRefTree), $strPageContent);
      $strPageContent = str_replace('$rootname', 'source', $strPageContent);
      print($strPageContent); 
    }
    elseif ($strXRefComponent != null && array_key_exists($strXRefComponent, $arrayValidXRefComponents)) {
      $strCGIExec = './' . $arrayValidXRefComponents[$strXRefComponent];
      
      // Rebuild QUERY_STRING for CGI
      if ($arrayQueryString != null && count($arrayQueryString) > 0) {
        foreach ($arrayQueryString as $_key => $_value) {
          if ($_key != 'path') {
            $strQueryString .= $_key . '=' . $_value . '&';
          }
        }
        $strQueryString = rtrim($strQueryString, '&');
      }

      // Assign PHP Environmental Variables to Local Environmental Variables
      foreach ($_SERVER as $_key => $_value) {
        putenv($_key . '=' . $_value);
      }

      // Assign or Override Local Environmental Variables
      putenv('BINOC_CGI=1');
      putenv('PATH_INFO=' . $strCGIPathInfo);
      putenv('QUERY_STRING=' . $strQueryString);
      putenv('DOCUMENT_URI=' .
        '/' . $strXRefTree .
        '/' . $strXRefComponent
      );
      putenv('REQUEST_URI=' .
        '/' . $strXRefTree .
        '/' . $strXRefComponent .
        '?' . $strQueryString
      );
      putenv('SCRIPT_FILENAME=' . 
        $_SERVER['DOCUMENT_ROOT'] .
        '/' . $strXRefTree .
        '/' . $strXRefComponent
      );
      putenv('SCRIPT_NAME=' .
        '/' . $strXRefTree .
        '/' . $strXRefComponent
      );
      putenv('PERL5LIB=' .
             $_SERVER['DOCUMENT_ROOT'] . '/libs/mxr:' .
             $_SERVER['DOCUMENT_ROOT'] . '/libs/mxr/lib');

      // Prepare to run the CGI script if it is existent and executable
      // We set a timeout of 55 seconds to keep any CGI scripts running
      // a muck from eating resources for more than a designated time
      // This should be adjusted later
      if (file_exists($strCGIExec) && is_executable($strCGIExec)) {
        $cgiHeaderCaptured = null;
        $cgiHeaderHTML = null;

        if ($strXRefComponent == 'source') {
          if ($strRequestRaw == 1) {
            funcSendHeader('bin');
            $cgiHeaderCaptured = true;
          }
        }

        $fh = popen('timeout 65 ' . $strCGIExec .  ' 2>&1', 'r');

        while($line = fgets($fh)) {
          if (startsWith($line, 'Content-Type:') || startsWith($line, 'Set-Cookie:') || startsWith($line, 'Refresh:')) {
            header($line);
            $cgiHeaderCaptured = true;
            if ($line == 'Content-Type: text/html') {
              $cgiHeaderHTML = true;
            }
            continue;
          }

          if (!$cgiHeaderCaptured) {
            funcSendHeader('text');
          }
          print($line);
        }
        $exitStatus = pclose($fh);

        print("\n\n" . 'Exit Status: ' . $exitStatus);
        exit();
      }
    }
    else {
      funcSendHeader('404');
    }
  }
  else {
    funcSendHeader('404');
  }
}
elseif ($strRequestPath == '/') {
  if (count($arrayManifest['active-sources']) == 1 && count($arrayManifest['inactive-sources']) == 0) {
    funcRedirect('/' . key($arrayManifest['active-sources']) . '/');
  }
  elseif (file_exists('./root-index.inc')) {
    $strPageContent = file_get_contents('./root-index.inc')
      or funcError('Unable to read ./root-index.inc');
    
    $strRepoContent = '';
    
    if (count($arrayManifest['active-sources']) >= 1) {
      $strRepoContent .= '<h2>Sources</h2>' . "\n";
      foreach ($arrayManifest['active-sources'] as $_key => $_value) {
        $strRepoContent .= '<dt><a href="' . $_key . '/">' . $arrayManifest['active-sources'][$_key]['xrefName'] . '</a></dt>' . "\n";
        $strRepoContent .= '<dd class="note">' . $arrayManifest['active-sources'][$_key]['xrefDesc'] . '</dd>' . "\n";
      }
    }
    
    if (count($arrayManifest['inactive-sources']) > 0) {
      $strRepoContent .= '<h2>Archived and Historical</h2>' . "\n";
      foreach ($arrayManifest['inactive-sources'] as $_key => $_value) {
        if ($_key == 'xp-hackjob') {
          continue;
        }
        $strRepoContent .= '<dt><a href="' . $_key . '/">' . $arrayManifest['inactive-sources'][$_key]['xrefName'] . '</a></dt>' . "\n";
        $strRepoContent .= '<dd class="note">' . $arrayManifest['inactive-sources'][$_key]['xrefDesc'] . '</dd>' . "\n";
      }
    }
    
    $strPageContent = str_replace('{{', '{', $strPageContent);
    $strPageContent = str_replace('}}', '}', $strPageContent);
    $strPageContent = str_replace('{0}', $strRepoContent, $strPageContent);
  }
  else {
    funcError('Unknown Error');
  }
  
  funcSendHeader('html');
  print($strPageContent);
}
else {
  // We don't know what the request was so 404 it
  funcSendHeader('404');
}

// ============================================================================

?>
