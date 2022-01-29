<?php

// == | Functions | ===================================================================================================

/**********************************************************************************************************************
* Checks the exploded count against the number of path parts in an exploded path and 404s it if it is greater
***********************************************************************************************************************/
function gfCheckPathCount($aExpectedCount) {
  global $gaRuntime;
  if (count($gaRuntime['explodedPath']) > $aExpectedCount) {
    gfHeader(404);
  }
}

// == | Main | ========================================================================================================

// Explode the path
$gaRuntime['explodedPath'] = gfExplodePath($gaRuntime['qPath']);

// The Special Component never has more than one level below it
// We still have to determine the root of the component though...
if (count($gaRuntime['explodedPath']) == 1) {
  $gvSpecialFunction = 'root';
}
else {
  gfCheckPathCount(2);
  $gvSpecialFunction = $gaRuntime['explodedPath'][1];
}

$gaRuntime['siteMenu'] = array(
  '/'                         => 'Root',
  '/special/'                 => 'Special',
  '/special/test/'            => 'Test Cases',
  '/special/software-state/'  => 'Software State',
  '/special/phpinfo/'         => 'PHP Info',
);

switch ($gvSpecialFunction) {
  case 'root':
    gfGenContent(['title'   => 'Special Component',
                  'content' => '<h2>Welcome to the Special Component!</h2>' .
                               '<p>Please select a function from the command bar above.</p>',
                  'menu'    => $gaRuntime['siteMenu']]);
    break;
  case 'test':
    $gaRuntime['qTestCase'] = gfSuperVar('get', 'case');
    $gvTestsPath = gfBuildPath(ROOT_PATH, 'base', 'tests');
    $gaGlobTests = glob($gvTestsPath . WILDCARD . PHP_EXTENSION);
    $gaTests = EMPTY_ARRAY;

    foreach ($gaGlobTests as $_value) {
      $gaTests[] = str_replace(PHP_EXTENSION, EMPTY_STRING, str_replace($gvTestsPath, EMPTY_STRING, $_value));
    }

    if ($gaRuntime['qTestCase']) {
      if (!in_array($gaRuntime['qTestCase'], $gaTests)) {
        gfError('Unknown test case');
      }

      require_once($gvTestsPath . $gaRuntime['qTestCase'] . PHP_EXTENSION);
      exit();
    }

    $gvContent = EMPTY_STRING;

    foreach ($gaTests as $_value) {
      $gvContent .= '<li><a href="/special/test/?case=' . $_value . '">' . $_value . '</a></li>';
    }

    if ($gvContent == EMPTY_STRING) {
      $gvContent = '<p>There are no test cases.</p>';
    }
    else {
      $gvContent = '<h2>Please select a test case&hellip;</h2><ul>' . $gvContent . '</ul>';
    }

    gfGenContent(['title' => 'Test Cases', 'content' => $gvContent, 'menu' => $gaRuntime['siteMenu']]);
    break;
  case 'software-state':
    gfGenContent(['title' => 'Software State', 'content' => $gaRuntime, 'menu' => $gaRuntime['siteMenu']]);
    break;
  case 'phpinfo':
    gfHeader('html');
    phpinfo(INFO_GENERAL | INFO_CONFIGURATION | INFO_ENVIRONMENT | INFO_VARIABLES);
    break;
  default:
    gfHeader(404);
}

// ====================================================================================================================

?>