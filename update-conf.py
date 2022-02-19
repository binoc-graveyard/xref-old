#!/bin/bash

# == | Setup | ========================================================================================================

# The beginning of this script is both valid shell and valid python, such that the script starts with the shell and
# is re-executed with the right python.
'''echo' $0: Starting up...
if BINOC_PYTHON="$(which python2.7 2>/dev/null)"; then
  exec $BINOC_PYTHON $0 "$@"
else
  echo "$0 error: Python 2.7 was not found on this system"
  exit 1
fi
'''

# ---------------------------------------------------------------------------------------------------------------------

# Python Modules
from __future__ import print_function
from collections import OrderedDict
import os
import sys
import json
"""
import hashlib
"""

# ---------------------------------------------------------------------------------------------------------------------

# Basic vars
# Python does not have constants because Python is SUPPOSED to be a basic scripting language that shouldn't be much
# more complex than a bash script but without the bullshit of the effectively regex-as-a-language Perl.
# Just don't overwrite these...
NEW_LINE = "\n"
SLASH = "/"
SPACE = ' '
TAB = SPACE + SPACE

EMPTY_STRING = ''
EMPTY_LIST = []
EMPTY_DICT = {}

CURRENT_PATH = os.getcwd()

# =====================================================================================================================

# == | Global Functions | =============================================================================================

def gfOutput(aType, aMsg):
  if aType == 'status':
    output = '{0}: {1}'.format(__file__, aMsg)
  else:
    output = '{0}: {1}: {2}'.format(__file__, aType, aMsg)

  print(output)

  if aType == 'error':
    sys.exit(1)

# ---------------------------------------------------------------------------------------------------------------------

def gfError(aMsg):
  gfOutput('error', aMsg);

# ---------------------------------------------------------------------------------------------------------------------

def gfJsonEncode(aJson):
  try:
    rv = json.dumps(aJson, sort_keys=False, ensure_ascii=False, indent=2)
  except:
    gfError('Unable to JSON Encode data')

  return rv

# ---------------------------------------------------------------------------------------------------------------------

def gfReadFile(aFile):
  try:
    with open(os.path.normpath(aFile), 'rb') as f:
      if aFile.endswith('.json'):
        rv = json.load(f, object_pairs_hook=OrderedDict)
      else:
        rv = f.read()
  except:
    return None

  return rv

# ---------------------------------------------------------------------------------------------------------------------

def gfWriteFile(aData, aFile):
  try:
    with open(os.path.normpath(aFile), 'w') as f:
      if aFile.endswith('.json'):
        f.write(gfJsonEncode(aData))
      else:
        f.write(aData)
  except:
    return None

  return True

"""
# ---------------------------------------------------------------------------------------------------------------------

def gfSha256(aFile, block_size=65536):
  sha256 = hashlib.sha256()

  with open(os.path.normpath(aFile), 'rb') as f:
    for block in iter(lambda: f.read(block_size), b''):
      sha256.update(block)

  return sha256.hexdigest()
"""

# =====================================================================================================================

# == | Main | =========================================================================================================

XREF_CONFIG = gfReadFile(CURRENT_PATH + SLASH + '.config.json')

if not XREF_CONFIG:
  gfError('Unable to read configuration.')

# ---------------------------------------------------------------------------------------------------------------------

TREES = XREF_CONFIG['sources'].keys() + XREF_CONFIG['archived']
LXR_SOURCES = EMPTY_STRING

for _value in TREES:
  LXR_SOURCES += 'sourceroot: {1} {0}/{1}/source'.format(XREF_CONFIG['setup']['datastore'], _value) + NEW_LINE
  LXR_SOURCES += 'sourceprefix: {0} source'.format(_value) + NEW_LINE

# ---------------------------------------------------------------------------------------------------------------------

LXR_CONFIG = '''baseurl: {0}/
incprefix: /include
dbdir: {1}
glimpsebin: /usr/bin/glimpse

bonsaihome: http://bonsai.mozilla.org
htmlhead: .{2}/template-head
htmltail: .{2}/template-tail
htmldir:  .{2}/template-dir
sourcehead: .{2}/template-source-head
sourcetail: .{2}/template-source-tail
sourcedirhead: .{2}/template-sourcedir-head
sourcedirtail: .{2}/template-sourcedir-tail
treechooser: .{2}/template-tree
treeentry: .{2}/template-tree-entry
revchooser: .{2}/template-rev
reventry: .{2}/template-rev-entry
identref: .{2}/template-ident-fileref

{3}'''.format(XREF_CONFIG['setup']['domain'],
              XREF_CONFIG['setup']['datastore'],
              XREF_CONFIG['setup']['templates'],
              LXR_SOURCES)

# ---------------------------------------------------------------------------------------------------------------------

LXR_FILE = gfWriteFile(LXR_CONFIG, CURRENT_PATH + SLASH + 'lxr.conf')

if not LXR_FILE:
  gfError('Failed to write LXR Configuration')

gfOutput('status', 'Wrote LXR Configuration')

# =====================================================================================================================
