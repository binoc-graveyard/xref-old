<?php
error_reporting(E_ALL);
ini_set("display_errors", "on");

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
        header($_arrayHeaders[$_value]);
        
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

// == | Vars | ================================================================

$strRequestRaw = funcHTTPGetValue('raw');
$strRequestPath = funcHTTPGetValue('path');

$arrayManifest = funcReadManifest();
$arrayQueryString = funcCheckVar($_GET);
$strQueryString = '';

$arrayRequestPath = array_replace_recursive(
    array(
        null,
        null,
        null
    ),
    explode('/', $strRequestPath)
);

$strXRefTree = funcCheckVar($arrayRequestPath[1]);
$strXRefComponent = funcCheckVar($arrayRequestPath[2]);

unset($arrayRequestPath[1]);
unset($arrayRequestPath[2]);

$strCGIPathInfo = implode('/', $arrayRequestPath);

$arrayValidXRefComponents = array(
    'find',
    'ident',
    'search',
    'source'
);


// ============================================================================

// ==| Main |==================================================================

if ($_SERVER['REQUEST_URI'] == '/') {
    $strRequestPath = '/';
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
        elseif ($strXRefComponent != null && in_array($strXRefComponent, $arrayValidXRefComponents)) {
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

            // Prepare to run the CGI script if it is existent and executable
            // We set a timeout of 65 seconds to keep any CGI scripts running
            // a muck from eating resources for more than a designated time
            // This should be adjusted later
            if (file_exists('./' . $strXRefComponent) && is_executable('./' . $strXRefComponent)) {
                // If the XRef component is 'source' and the query 'raw=1' is specified
                // then we should pass though stdout with a binary stream
                // NOTE: If the script errors it won't be printed in the browser
                if ($strXRefComponent == 'source' && $strRequestRaw == 1) {
                    funcSendHeader('bin');
                    passthru('timeout 65 ' . $strXRefComponent . ' 2>&1');
                }
                else {
                    exec('timeout 65 ./' . $strXRefComponent . ' 2>&1', $arrayCGIResult, $intCGIExitCode);
                    
                    // CGI sends raw headers as part of the result and we need to capture that
                    $arrayCGIHeaders = array();
                    
                    // Iterate over the indexes of the result array to find headers and
                    // remove them as we go
                    foreach($arrayCGIResult as $_value) {
                        // XRef specifically has a blank line after all the headers so
                        // we should break out of the loop when we hit one else push
                        // each index/line to an array containing CGI supplied headers
                        if ($_value == '') {
                            $intCGIResultIndex = array_search($_value, $arrayCGIResult);
                            unset($arrayCGIResult[$intCGIResultIndex]);
                            break;
                        }
                        else {
                            array_push($arrayCGIHeaders, $_value);
                            $intCGIResultIndex = array_search($_value, $arrayCGIResult);
                            unset($arrayCGIResult[$intCGIResultIndex]);
                        }
                    }
                    
                    // Iterate over all CGI supplied headers and have PHP send them
                    foreach ($arrayCGIHeaders as $_value) {
                        header($_value);
                    }
                    
                    // implode the result array to a string and print it
                    print(implode("\n", $arrayCGIResult));
                    unset($arrayCGIResult);
                }
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