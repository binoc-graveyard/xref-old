#!/bin/bash
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# ===| BASH Stub |=============================================================

# The beginning of this script is both valid shell and valid python,
# such that the script starts with the shell and is reexecuted with
# the right python.

'''echo' $0: Starting up...
if ! BINOC_PYTHON_PATH="$(which python2.7 2>/dev/null)"; then
    echo "$0 error: Python 2.7 was not found on this system"
    exit 1
fi

exec $BINOC_PYTHON_PATH $0 "$@"
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
        if _messageTemplates[_messageType].find('error') != -1:
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
