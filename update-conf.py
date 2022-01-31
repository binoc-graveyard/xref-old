#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# ===| BASH Stub |=============================================================

# The beginning of this script is both valid shell and valid python,
# such that the script starts with the shell and is reexecuted with
# the right python.

'''echo' $0: Starting up...
if [ -f "/opt/rh/python27/root/usr/bin/python2.7" ];then
  BINOC_PYTHON_ARGS=$@
  exec scl enable python27 "python $0 $BINOC_PYTHON_ARGS"
elif BINOC_PYTHON_PATH="$(which python2.7 2>/dev/null)"; then
  exec $BINOC_PYTHON_PATH $0 "$@"
else
  echo "$0 error: Python 2.7 was not found on this system"
  exit 1
fi
'''
# =============================================================================

# ===| Imports |===============================================================

from __future__ import print_function
from collections import OrderedDict
import platform
import os
import sys
import pprint
import json
import re
import argparse
import subprocess

# =============================================================================

# ===| Function: Output Message |==============================================

def funcOutputMessage(_messageType, _messageBody):
  _messagePrefix = 'xRef:'
  _errorPrefix = '{0} error:'.format(_messagePrefix)
  _warnPrefix = '{0} warning:'.format(_messagePrefix)
  _messageTemplates = {
    'statusGen' : '{0} {1}'.format(_messagePrefix, _messageBody),
    'warnGen' : '{0} {1}'.format(_warnPrefix, _messageBody),
    'errorGen' : '{0} {1}'.format(_errorPrefix, _messageBody)
  }
  
  if _messageType in _messageTemplates:
    print(_messageTemplates[_messageType])
    if _messageType == 'errorGen':
      sys.exit(1)
  else:
    print('{0} Unknown error - Referenced as \'{1}\' internally.'.format(_messagePrefix, _messageType))
    sys.exit(1)

# =============================================================================

# ===| Function: Read JSON |===================================================

def funcReadJson(filename):
  with open(filename) as json_data:
    _jsonData = json.load(json_data, object_pairs_hook=OrderedDict)
  return(_jsonData)

# =============================================================================

# ===| Function: Generate lxr.conf |===========================================

def funcGenLXRConf(_input): 
  _lxrSources = ''
  for _source in _input['active-sources']:
    _sourcePrefix = ''
    if _source.endswith('-trunk'):
      _sourcePrefix = re.sub('\-trunk$', '', _source)
    elif "-rel" in _source:
      _sourcePrefix = re.sub('\-rel([0-9]+)', '', _source)
    else:
      _sourcePrefix = _source
    _lxrSources += 'sourceroot: {0} {1}/{0}/{2}'.format(_source, _input['setup']['dbDir'], 'source') + "\n"
    _lxrSources += 'sourceprefix: {0} {1}'.format(_source, 'source') + "\n"

  for _source in _input['inactive-sources']:
    _sourcePrefix = ''
    if _source.endswith('-trunk'):
      _sourcePrefix = re.sub('\-trunk$', '', _source)
    elif "-rel" in _source:
      _sourcePrefix = re.sub('\-rel([0-9]+)', '', _source)
    elif "-esr" in _source:
      _sourcePrefix = re.sub('\-esr([0-9]+)', '', _source)
    else:
      _sourcePrefix = _source
    _lxrSources += 'sourceroot: {0} {1}/{0}/{2}'.format(_source, _input['setup']['dbDir'], 'source') + "\n"
    _lxrSources += 'sourceprefix: {0} {1}'.format(_source, 'source') + "\n"
    
  _lxrConf = '''
baseurl: {0}
bonsaihome: http://bonsai.mozilla.org
htmlhead: ./media/templates/template-head
htmltail: ./media/templates/template-tail
htmldir:  ./media/templates/template-dir
sourcehead: ./media/templates/template-source-head
sourcetail: ./media/templates/template-source-tail
sourcedirhead: ./media/templates/template-sourcedir-head
sourcedirtail: ./media/templates/template-sourcedir-tail
treechooser: ./media/templates/template-tree
treeentry: ./media/templates/template-tree-entry
revchooser: ./media/templates/template-rev
reventry: ./media/templates/template-rev-entry
identref: ./media/templates/template-ident-fileref

{1}
incprefix: /include
dbdir: {2}
glimpsebin: /usr/bin/glimpse'''

  return _lxrConf.format(_input['setup']['baseURL'], _lxrSources, _input['setup']['dbDir'])

# =============================================================================

# ===| Main |==================================================================

# Define initial vars
pathCurrent = os.getcwd()
fileXREFJson = '.config.json'

# Find config.json
if os.path.exists(fileXREFJson):
  pathXREFJson = fileXREFJson
else:
  funcOutputMessage('errorGen', 'Could not find ' + fileXREFJson)

# Read json into a dict
dictXREFJson = funcReadJson(pathXREFJson)

# Read mxr-data directory list
try:
  listMXRData = os.listdir(dictXREFJson['setup']['dbDir'])
except:
  listMXRData = []
  funcOutputMessage('warnGen', 'The directory ' + dictXREFJson['setup']['dbDir'] + ' is either empty or does not exist')

if len(listMXRData) is not 0:
  for _item in listMXRData:
    if (_item not in dictXREFJson['active-sources']) and (_item not in dictXREFJson['inactive-sources']):
      if _item in ('.config.json', 'update.sh'):
        continue
      funcOutputMessage('warnGen', 'MXR Data item: ' + _item + ' is not listed in config.json')

# Create lxr.conf File
funcOutputMessage('statusGen', '(Re)generating LXR Configuration')
try:
  fileLXRConf = open('lxr.conf', 'wb')
  fileLXRConf.write(funcGenLXRConf(dictXREFJson))
  fileLXRConf.close
  funcOutputMessage('statusGen', 'Wrote LXR Configuration to ./lxr.conf')
except:
  funcOutputMessage('errorGen', 'Unable to write to ./lxr.conf') 
  sys.exit(1)

# =============================================================================


