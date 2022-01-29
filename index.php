<?php
// == | Setup | =======================================================================================================

// Enable Error Reporting
error_reporting(E_ALL);
ini_set("display_errors", "on");
ini_set('html_errors', false);

// This has to be defined using the function at runtime because it is based
// on a variable. However, constants defined with the language construct
// can use this constant by some strange voodoo. Keep an eye on this.
// NOTE: DOCUMENT_ROOT does NOT have a trailing slash.
define('ROOT_PATH', $_SERVER['DOCUMENT_ROOT']);

// Debug flag
define('DEBUG_MODE', $_GET['debug'] ?? null);

// Define basic constants for the software
const SOFTWARE_NAME       = 'Cross-Reference';
const SOFTWARE_VERSION    = '1.0.0a1';
const SOFTWARE_REPO       = '#';
const DATASTORE_RELPATH   = '/datastore/';
const OBJ_RELPATH         = '/.obj/';
const BASE_RELPATH        = '/base/';
const SKIN_RELPATH        = '/skin/';
const COMPONENTS_RELPATH  = '/components/';
const MODULES_RELPATH     = '/modules/';
const JSMODULES_RELPATH   = '/jsmodules/';
const LIB_RELPATH         = '/libraries/';

// Define components
const COMPONENTS = array(
  'site'            => ROOT_PATH . BASE_RELPATH . 'site.php',
  'special'         => ROOT_PATH . BASE_RELPATH . 'special.php',
);

// Define modules
const MODULES = null

// Define JS Modules
const JSMODULES = null;

// Define libraries
const LIBRARIES = null;

// Load fundamental constants and global functions
require_once('./fundamentals.php');

// ====================================================================================================================

// == | Global Functions | ============================================================================================

/**********************************************************************************************************************
* Basic Content Generation using the Special Component's Template
*
* @dep SOFTWARE_NAME
* @dep SOFTWARE_VERSION
* @dep gfError()
* @param $aTtitle     Title of the page
* @param $aContent    Content of the page
* @param $aTextBox    Use textbox for content
* @param $aList       Use list for content
* @param $aError      Is an Error Page
***********************************************************************************************************************/
function gfGenContent($aMetadata, $aLegacyContent = null, $aTextBox = null, $aList = null, $aError = null) {
  $ePrefix = __FUNCTION__ . DASH_SEPARATOR;
  $skinPath = '/skin/default';

  // Anonymous functions
  $contentIsStringish = function($aContent) {
    return (!is_string($aContent) && !is_int($aContent)); 
  };

  $textboxContent = function($aContent) {
    return '<textarea class="special-textbox aligncenter" name="content" rows="36" readonly>' .
           $aContent . '</textarea>';
  };

  $template = gfReadFile(DOT . $skinPath . SLASH . 'template.xhtml');

  if (!$template) {
    gfError($ePrefix . 'Special Template is busted...', null, true);
  }

  $pageSubsts = array(
    '{$SKIN_PATH}'        => $skinPath,
    '{$SITE_NAME}'        => defined('SITE_NAME') ? SITE_NAME : SOFTWARE_NAME . SPACE . SOFTWARE_VERSION,
    '{$SITE_MENU}'        => EMPTY_STRING,
    '{$PAGE_TITLE}'       => null,
    '{$PAGE_CONTENT}'     => null,
    '{$SOFTWARE_NAME}'    => SOFTWARE_NAME,
    '{$SOFTWARE_VERSION}' => SOFTWARE_VERSION,
  );

  if ($aLegacyContent) {
    if (is_array($aMetadata)) {
      gfError($ePrefix . 'aMetadata may not be an array in legacy mode.');
    }

    if ($aTextBox && $aList) {
      gfError($ePrefix . 'You cannot use both textbox and list');
    }

    if ($contentIsStringish($aLegacyContent)) {
      $aLegacyContent = var_export($aLegacyContent, true);
      $aTextBox = true;
      $aList = false;
    }

    if ($aTextBox) {
      $aLegacyContent = $textboxContent($aLegacyContent);
    }
    elseif ($aList) {
      // We are using an unordered list so put aLegacyContent in there
      $aLegacyContent = '<ul><li>' . $aLegacyContent . '</li><ul>';
    }

    if (!$aError && ($GLOBALS['gaRuntime']['qTestCase'] ?? null)) {
      $pageSubsts['{$PAGE_TITLE}'] = 'Test Case' . DASH_SEPARATOR . $GLOBALS['gaRuntime']['qTestCase'];

      foreach ($GLOBALS['gaRuntime']['siteMenu'] ?? EMPTY_ARRAY as $_key => $_value) {
        $pageSubsts['{$SITE_MENU}'] .= '<li><a href="' . $_key . '">' . $_value . '</a></li>';
      }
    }
    else {
      $pageSubsts['{$PAGE_TITLE}'] = $aMetadata;
    }

    $pageSubsts['{$PAGE_CONTENT}'] = $aLegacyContent;
  }
  else {
    if ($aTextBox || $aList) {
      gfError($ePrefix . 'Mode attributes are deprecated.');
    }

    if (!array_key_exists('title', $aMetadata) && !array_key_exists('content', $aMetadata)) {
      gfError($ePrefix . 'You must specify a title and content');
    }

    $pageSubsts['{$PAGE_TITLE}'] = $aMetadata['title'];
    $pageSubsts['{$PAGE_CONTENT}'] = $contentIsStringish($aMetadata['content']) ?
                                     $textboxContent(var_export($aMetadata['content'], true)) :
                                     $aMetadata['content'];

    foreach ($aMetadata['menu'] ?? EMPTY_ARRAY as $_key => $_value) {
      $pageSubsts['{$SITE_MENU}'] .= '<li><a href="' . $_key . '">' . $_value . '</a></li>';
    }
  }

  if ($pageSubsts['{$SITE_MENU}'] == EMPTY_STRING) {
    $pageSubsts['{$SITE_MENU}'] = '<li><a href="/">Root</a></li>';
  }

  if (!str_starts_with($pageSubsts['{$PAGE_CONTENT}'], '<p') &&
      !str_starts_with($pageSubsts['{$PAGE_CONTENT}'], '<ul') &&
      !str_starts_with($pageSubsts['{$PAGE_CONTENT}'], '<h1') &&
      !str_starts_with($pageSubsts['{$PAGE_CONTENT}'], '<h2') &&
      !str_starts_with($pageSubsts['{$PAGE_CONTENT}'], '<table')) {
    $pageSubsts['{$PAGE_CONTENT}'] = '<p>' . $pageSubsts['{$PAGE_CONTENT}'] . '</p>';
  }

  $template = gfSubst('string', $pageSubsts, $template);

  // If we are generating an error from gfError we want to clean the output buffer
  if ($aError) {
    ob_get_clean();
  }

  // Send an html header
  header('Content-Type: text/html', false);

  // write out the everything
  print($template);

  // We're done here
  exit();
}

/**********************************************************************************************************************
* 404 or Error
*
* @param $aErrorMessage   Error message if debug
***********************************************************************************************************************/
function gfErrorOr404($aErrorMessage) {
  global $gaRuntime;

  if ($gaRuntime['debugMode'] ?? null) {
    gfError($aErrorMessage);
  }

  gfHeader(404);
}


// ====================================================================================================================

// == | Main | ========================================================================================================

// Define an array that will hold the current application state
$gaRuntime = array(
  'currentDomain'       => null,
  'currentSubDomain'    => null,
  'currentScheme'       => gfSuperVar('server', 'SCHEME') ?? (gfSuperVar('server', 'HTTPS') ? 'https' : 'http'),
  'debugMode'           => null,
  'phpServerName'       => gfSuperVar('server', 'SERVER_NAME'),
  'phpRequestURI'       => gfSuperVar('server', 'REQUEST_URI'),
  'remoteAddr'          => gfSuperVar('server', 'HTTP_X_FORWARDED_FOR') ?? gfSuperVar('server', 'REMOTE_ADDR'),
  'qComponent'          => gfSuperVar('get', 'component'),
  'qPath'               => gfSuperVar('get', 'path'),
);

// --------------------------------------------------------------------------------------------------------------------

// Offline check
if (file_exists(ROOT_PATH . SLASH . '.offline')) {
  gfError('Site Offline');
}

// --------------------------------------------------------------------------------------------------------------------

// Root (/) won't set a component or path
if (!$gaRuntime['qComponent'] && !$gaRuntime['qPath']) {
  $gaRuntime['qComponent'] = 'site';
  $gaRuntime['qPath'] = SLASH;
}

// --------------------------------------------------------------------------------------------------------------------

// Set the current domain and subdomain
$gaRuntime['currentDomain'] = gfSuperVar('var', gfGetDomain($gaRuntime['phpServerName']));
$gaRuntime['currentSubDomain'] = gfSuperVar('var', gfGetDomain($gaRuntime['phpServerName'], true));

// --------------------------------------------------------------------------------------------------------------------

// Handle Debug Mode
if (DEBUG_MODE) {
  $gaRuntime['debugMode'] = true;
}

// --------------------------------------------------------------------------------------------------------------------

// If we have a path then explode it and check for component pretty-paths
if ($gaRuntime['qPath']) {
  // Explode the path if it exists
  $gaRuntime['currentPath'] = gfExplodePath($gaRuntime['qPath']);

  // These paths override the site component
  switch ($gaRuntime['currentPath'][0]) {
    case 'special':
      $gaRuntime['qComponent'] = $gaRuntime['currentPath'][0];
      break;
  }
}

// --------------------------------------------------------------------------------------------------------------------

// Load component based on qComponent
if ($gaRuntime['qComponent'] && array_key_exists($gaRuntime['qComponent'], COMPONENTS)) {
  require_once(COMPONENTS[$gaRuntime['qComponent']]);
}
else {
  gfErrorOr404('Invalid component.');
}

// ====================================================================================================================

?>