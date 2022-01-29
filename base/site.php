<?php
// == | Setup | =======================================================================================================

const CGI_COMPONENTS = array(
  'find'      => 'find.cgi',
  'ident'     => 'ident.cgi',
  'serch'     => 'search.cgi',
  'source'    => 'source.cgi'
)

const PROTECTED_TREES = ['goanna-central'];

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
 
  if (!array_key_exists($username, $gaRuntime['xref']['access']) ||
      !password_verify($password, $gaRuntime['xref']['access'][$username])) {
    gfBasicAuthPrompt();
  }

  $gaRuntime['authentication']['username'] = $username;
}

/**********************************************************************************************************************
* Execute CGI
***********************************************************************************************************************/
function gfExecuteCGI($aScript) {
  global $gaRuntime;

  // Make sure the script actually exists
  if (!file_exists($aScript)) {
    gfError('Unable to find' . SPACE . basename($aScript));
  }

  if (!is_executable($aScript)) {
    gfError('Unable to execute' . SPACE . basename($aScript));
  }

  $scriptURI = gfBuildPath($gaRuntime['currentPath'][0], $gaRuntime['currentPath'][1]);
  $scriptQuery = gfSuperVar('server', 'QUERY_STRING');

  // Rebuild the query string
  if ($scriptQuery) {
    str_replace('component=' . $gaRuntime['qComponent'], EMPTY_STRING, $scriptQuery);
    str_replace('path=' . $gaRuntime['qPath'], EMPTY_STRING, $scriptQuery);
    $scriptQuery = gfSuperVar('check', $scriptQuery);
  }

  // Create an array of environmental variables to be assigned to the local environment
  $env = array(
    'BINOC_CGI'         => '1',
    'DOCUMENT_URI'      => $scriptURI,
    'PATH_INFO'         => implode(SLASH, array_slice($gaRuntime['currentPath'], 2)) . SLASH,
    'QUERY_STRING'      => $scriptQuery ?? null,
    'REQUEST_URI'       => $scriptQuery ? ($scriptURI . '?' . $scriptQuery) : $scriptURI,
    'SCRIPT_FILENAME'   => ROOT_PATH . $scriptURI,
    'SCRIPT_NAME'       => $scriptURI,
  );

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
  $cgiCommand = 'timeout 65' . SPACE . $aScript;

  // If debug pipe stderr to stdout
  if ($gaRuntime('debugMode') {
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

  // Read from stdout until the end.
  while ($line = fgets($cgi)) {
    if (!$gaRuntime['debugMode']) {
      if (str_starts_with($line, 'Content-Type:') || str_starts_with($line, 'Last-Modified:') ||
          str_starts_with($line, 'Set-Cookie:') || str_starts_with($line, 'Refresh:') {
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
$gaRuntime['xref'] = gfReadFile(gfBuildPath(ROOT_PATH, '.config.json'));

$gvXrefTree = $gaRuntime['currentPath'][0];
$gvXrefComponent = $gaRuntime['currentPath'][1] ?? null;

if (in_array($gvXrefTree, PROTECTED_TREES) {
  gfLocalAuth();
}

unset($gaRuntime['xref']['access']);

if (array_key_exists($gvXrefTree, $gaRuntime['xref']['active-sources']) ||
    array_key_exists($gvXrefTree, $gaRuntime['xref']['inactive-sources'])) {

  switch ($gvXrefComponent) {
    default:
      if (array_key_exists($gvXrefComponent, CGI_COMPONENTS)) {
        gfExecuteCGI(gfBuildPath(ROOT_PATH, CGI_COMPONENTS[$gvXrefComponent]));
      }
  }

  // Source Index Page
}
elseif ($gaRuntime['qPath'] == SLASH) {
  // Root index
}
else {
  // No idea what we should do so 404
  gfHeader(404);
}

// ====================================================================================================================

?>
