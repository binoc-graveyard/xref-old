<?php
// == | Setup | =======================================================================================================

const CGI_COMPONENTS = array(
  'find'      => 'find.cgi',
  'ident'     => 'ident.cgi',
  'search'     => 'search.cgi',
  'source'    => 'source.cgi'
);

// ====================================================================================================================

// == | Global Functions | ============================================================================================

/**********************************************************************************************************************
* Local Authentication from a pre-defined json file with user and hashed passwords
*
* @dep ROOT_PATH
* @dep DOTDOT
* @dep JSON_EXTENSION
* @dep gfError()
* @dep gfSuperVar()
* @dep gfBuildPath()
* @dep gfBasicAuthPrompt()
* @param $aTobinOnly   Only Tobin's username is valid
***********************************************************************************************************************/
function gfLocalAuth($aTobinOnly = null) {
  global $gaRuntime;

  $username = gfSuperVar('server', 'PHP_AUTH_USER');
  $password = gfSuperVar('server', 'PHP_AUTH_PW');

  if ((!$username || !$password) || ($aTobinOnly && $username != 'mattatobin')) {
    gfBasicAuthPrompt();
  }
 
  if (!array_key_exists($username, $gaRuntime['xref']['users']) ||
      !gfPasswordVerify($password, $gaRuntime['xref']['users'][$username])) {
    gfBasicAuthPrompt();
  }

  $gaRuntime['authentication']['username'] = $username;
}

/**********************************************************************************************************************
* Execute CGI
***********************************************************************************************************************/
function gfExecuteCGI($aScript) {
  global $gaRuntime;
  global $gvXrefTree;
  global $gvXrefComponent;

  // Make sure the script actually exists
  if (!file_exists($aScript)) {
    gfError('Unable to find' . SPACE . basename($aScript));
  }

  if (!is_executable($aScript)) {
    gfError('Unable to execute' . SPACE . basename($aScript));
  }

  $scriptURI = gfBuildPath($gaRuntime['currentPath'][0], $gaRuntime['currentPath'][1]);

  $scriptQuery = $_GET ?? EMPTY_ARRAY;
  unset($scriptQuery['component']);
  unset($scriptQuery['path']);

  // Rebuild the query string
  $scriptQuery = http_build_query($scriptQuery);

  // Figure out CGI Path Info
  $pathInfo = SLASH;

  if (count($gaRuntime['currentPath']) > 1) {
     $pathInfo = str_replace(SLASH . $gvXrefTree . SLASH . $gvXrefComponent, EMPTY_STRING, $gaRuntime['qPath']);
  }

  // Create an array of environmental variables to be assigned to the local environment
  $env = array(
    'BINOC_CGI'         => '1',
    'DOCUMENT_URI'      => $scriptURI,
    'PATH_INFO'         => $pathInfo,
    'QUERY_STRING'      => gfSuperVar('check', $scriptQuery),
    'REQUEST_URI'       => $scriptQuery ? ($gaRuntime['qPath'] . '?' . $scriptQuery) : $gaRuntime['qPath'],
    'SCRIPT_FILENAME'   => ROOT_PATH . $scriptURI,
    'SCRIPT_NAME'       => substr($scriptURI, 0, -1),
  );
  // gfError($env);
  // Apply our array on top of PHP's $_SERVER array
  $env = array_merge($_SERVER, $env);

  // Assign our environmental variables to the local environment
  foreach ($env as $_key => $_value) {
    if (!$_value) {
      continue;
    }

    putenv($_key . '=' . $_value);
  }

  // Start building the CGI Command including prepending a timeout so scripts don't run a muck
  $cgiCommand = 'timeout 55' . SPACE . $aScript;

  // If debug pipe stderr to stdout
  if ($gaRuntime['debugMode']) {
    $cgiCommand .= SPACE . '2>&1';
  }

  // Execute the CGI Script
  $cgi = popen($cgiCommand, 'r');

  // Keep track of if Headers happened and if we got an HTML Header
  $gotHeaders = null;
  $headerlessContent = EMPTY_STRING;

  if ($gaRuntime['currentPath'][1] == 'source' && gfSuperVar('get', 'raw') == 1) {
    gfHeader('bin');
    $gotHeaders = true;
  }

  if ($gaRuntime['currentPath'][1] == 'source' && gfSuperVar('get', 'raw') == 2) {
    gfHeader('text');
    $gotHeaders = true;
  }

  // Read from stdout until the end.
  while ($line = fgets($cgi)) {
    if (!$gaRuntime['debugMode']) {
      if (str_starts_with($line, 'Content-Type:') || str_starts_with($line, 'Last-Modified:') ||
          str_starts_with($line, 'Set-Cookie:') || str_starts_with($line, 'Refresh:')) {
        if (!$gotHeaders) {
          $gotHeaders = true;
        }

        header($line);
        continue;
      }

      // If we have gotten at least one header then print the line
      if ($gotHeaders) {
        print($line);
        continue;
      }
    }

    // Otherwise put the line in a string that will be output with the special template
    $headerlessContent .= $line;
  }

  // Close the stream
  $exitCode = pclose($cgi);
 
  if (gfSuperVar('check', $headerlessContent)) {
    if ($gaRuntime['debugMode']) {
      gfHeader('text');
      print($headerlessContent . NEW_LINE . NEW_LINE . 'Exit Code:' . SPACE . $exitCode);
      exit();
    }

    gfError('Did not receive headers from' . SPACE . basename($aScript) . DOT . SPACE .
            'This may indicate the script failed. Try using ?debug=1 to merge stderr into stdout.');
  }

  // We're done here
  exit();
}

// ====================================================================================================================

// == | Main | ========================================================================================================

// Read the XREF Configuration
$gaRuntime['xref'] = gfReadFile(ROOT_PATH . SLASH . '.config.json');

if (!$gaRuntime['xref']) {
  gfError('Unable to read xref configuration.');
}

// Handle the most recent obsolete trees
if ($gaRuntime['currentPath'][0] == 'moonchild-central' || $gaRuntime['currentPath'][0] == 'binoc-central') {
  $gaRuntime['currentPath'][0] = 'goanna-central';
  gfRedirect(gfBuildPath(...$gaRuntime['currentPath']));
}

// --------------------------------------------------------------------------------------------------------------------

$gvTrees = EMPTY_ARRAY;

foreach ($gaRuntime['xref']['sources'] as $_key => $_value) {
  $gvTrees[$_key] = $_value['description'];
}

foreach ($gaRuntime['xref']['archived'] as $_value) {
  $_tree = gfExplodeString(DASH, $_value);
  $_desc = $gaRuntime['xref']['generic-desc'][$_tree[0]] ??
           'The {%TREE_NAME} tree' . DOT;

  switch ($_tree[0]) {
    case 'palemoon':
      if (str_starts_with($_tree[1], 'rel')) {
        $_version = str_replace('rel', EMPTY_STRING,$_tree[1]);
        $_desc = str_replace('{%VERSION}', $_version, $_desc);
      }
      break;
    case 'mozilla':
    case 'comm':
      $_desc = str_replace('{%TREE_NAME}', $_value, $_desc);
      break;
  }

  $gvTrees[$_value] = $_desc;
}

// --------------------------------------------------------------------------------------------------------------------

if (array_key_exists($gaRuntime['currentPath'][0], $gvTrees)) {
  $gvXrefTree = $gaRuntime['currentPath'][0];
  $gvXrefComponent = $gaRuntime['currentPath'][1] ?? null;

  if (in_array($gvXrefTree, $gaRuntime['xref']['protectedTrees'])) {
    gfLocalAuth();
  }

  if ($gvXrefComponent) {
    if (array_key_exists($gvXrefComponent, CGI_COMPONENTS)) {
      gfExecuteCGI(gfBuildPath(ROOT_PATH, CGI_COMPONENTS[$gvXrefComponent]));
    }

    gfError('Invalid CGI Component');
  }

  if (!str_ends_with($gaRuntime['qPath'], SLASH)) {
    gfRedirect($gaRuntime['qPath'] . SLASH);
  }

  $content = gfReadFile(ROOT_PATH . SLASH . 'media' . SLASH . 'templates' . SLASH . 'template-source-index');

  if (!$content) {
    gfError('Could not load source index template');
  }

  $content = gfSubst('string',
                     ['$treename' => strtolower($gvXrefTree),
                      '$rootname' => 'source',
                      '$treedesc' => $gvTrees[$gvXrefTree]],
                     $content);

  gfHeader('html');
  print($content);
  exit();
}

unset($gaRuntime['xref']['access']);

if ($gaRuntime['qPath'] == SLASH) {
  $content = gfReadFile(ROOT_PATH . SLASH . 'media' . SLASH . 'templates' . SLASH . 'template-root-index');

  if (!$content) {
    gfError('Could not load root index template');
  }

  $trees = '<h2>Sources</h2>' . NEW_LINE;

  foreach (array_keys($gaRuntime['xref']['sources']) as $_value) {
    $trees .= '<dt><a href="/' . $_value . '/">' .
              $_value . '</a></dt>' . NEW_LINE;
    $trees .= '<dd class="note">' . $gvTrees[$_value] . '</dd>' . NEW_LINE;
  }

  $trees .= '<h2>Archived and Historical</h2>' . NEW_LINE;

  foreach ($gaRuntime['xref']['archived'] as $_value) {
    $trees .= '<dt><a href="/' . $_value . '/">' .
              $_value . '</a></dt>' . NEW_LINE;
    $trees .= '<dd class="note">' . $gvTrees[$_value] . '</dd>' . NEW_LINE;
  }

  $content = str_replace('$sources', $trees, $content);

  gfHeader('html');
  print($content);
  exit();
}
else {
  // No idea what we should do so 404
  gfHeader(404);
}

// ====================================================================================================================

?>
