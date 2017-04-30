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
import json
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

# ===| Function: contains |====================================================

def funcContains(_strNeedle, _strHaystack):
    if type(_strHaystack) is str:
        if _strNeedle in _strHaystack:
            return True
        else:
            return False
    if type(_strHaystack) is list:
        for _value in _strHaystack:
            if _value in _strNeedle:
                return True
            else:
                return False
    else:
        funcOutputMessage('errorGen', 'Incorrect funcContains usage')

# =============================================================================

# ===| Main |==================================================================

# Define initial vars
strCurrentPath = os.getcwd()
fileXREFJson = 'config.json'

# Find and read config.json
if os.path.exists(fileXREFJson):
    pathXREFJson = fileXREFJson
elif os.path.exists('../' + fileXREFJson):
    pathXREFJson = '../' + fileXREFJson
elif os.path.exists('../datastore/' + fileXREFJson):
    pathXREFJson = '../datastore/' + fileXREFJson
else:
    funcOutputMessage('errorGen', 'Could not find ' + fileXREFJson)

# Simple Arguments
if not len(sys.argv) > 1:
    funcOutputMessage('errorGen', 'You must specify a repository')
else:
    strRepository = sys.argv[1]

# Define more vars
dictXREFJson = funcReadJson(pathXREFJson)
strXRefPath = dictXREFJson['setup']['wwwroot']
strMXRDataPath = dictXREFJson['setup']['dbDir'] + '/' + strRepository + '/source/'
strGitRepoBranch = ''

# Ensure active-source exists in json
if strRepository not in dictXREFJson['active-sources']:
    funcOutputMessage('errorGen', strRepository + ' is not an active source in your config.json')

# Print the Repository name
funcOutputMessage('statusGen', 'Repository ' + strRepository)

# Determine where the Git Repo lives
if dictXREFJson['active-sources'][strRepository]['mode'] == 'mangle':
    strGitRepoPath = dictXREFJson['setup']['repoDir'] + '/' + dictXREFJson['active-sources'][strRepository]['localRepo'] + '/'
else:
    strGitRepoPath = strMXRDataPath

# Git
if dictXREFJson['active-sources'][strRepository]['mode'] == 'mangle':
    funcOutputMessage('statusGen', 'Updating repository (mangle mode)')
    strGitRepoBranch = dictXREFJson['active-sources'][strRepository]['gitBranch']
    subprocess.call('"{0}" {1}'.format('git', 'fetch'), shell=True, cwd=strGitRepoPath)
    subprocess.call('"{0}" {1} {2}'.format ('git', 'checkout', strGitRepoBranch), shell=True, cwd=strGitRepoPath)
    subprocess.call('"{0}" {1}'.format('git', 'pull'), shell=True, cwd=strGitRepoPath)
elif dictXREFJson['active-sources'][strRepository]['mode'] == 'basic':
    funcOutputMessage('statusGen', 'Updating repository (standard mode)')
    subprocess.call('"{0}" {1}'.format('git', 'pull'), shell=True, cwd=strMXRDataPath)

# Custom Command
if dictXREFJson['active-sources'][strRepository]['mode'] == 'custom':
    strCustomCommand = dictXREFJson['active-sources'][strRepository]['customCommand'][0]
    strCustomArguments = dictXREFJson['active-sources'][strRepository]['customCommand'][1]
    funcOutputMessage('statusGen', 'Executing command {0} {1} (custom mode)'.format(strCustomCommand, strCustomArguments))
    subprocess.call('"{0}" {1}'.format(strCustomCommand, strCustomArguments), shell=True, cwd=strMXRDataPath)

# RSync
if dictXREFJson['active-sources'][strRepository]['mode'] == 'mangle':
    funcOutputMessage('statusGen', 'Executing RSync (mangle mode)')
    subprocess.call('"{0}" {1} {2} {3}'.format('rsync', "-r --delete --exclude '.git'", strGitRepoPath, strMXRDataPath), shell=True, cwd=strXRefPath)

# XRef Perl Scripts
funcOutputMessage('statusGen', '(Re)generate XRef ident and search databases')
subprocess.call('"{0}" {1} {2}'.format('perl', 'update-xref.pl', strRepository), shell=True, cwd=strXRefPath)
subprocess.call('"{0}" {1} {2}'.format('perl', 'update-search.pl', strRepository), shell=True, cwd=strXRefPath)

# =============================================================================

