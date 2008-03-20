#!/bin/sh
# Run this from cron to update the source tree that lxr sees.
# Created 12-Jun-98 by jwz.
# Updated 27-Feb-99 by endico. Added multiple tree support.

CVSROOT=:pserver:anonymous@cvs-mirror.mozilla.org:/cvsroot
export CVSROOT

PATH=/opt/local/bin:/opt/cvs-tools/bin:$PATH
export PATH

TREE=$1
export TREE

lxr_dir=.
db_dir=`sed -n 's@^dbdir:[ 	]*\(.*\)@\1@p' < $lxr_dir/lxr.conf`/$TREE

if [ "$TREE" = '' ]
then
    #since no tree is defined, assume sourceroot is defined the old way 
    #grab sourceroot from config file indexing only a single tree where
    #format is "sourceroot: dirname"
    src_dir=`sed -n 's@^sourceroot:[    ]*\(.*\)@\1@p' < $lxr_dir/lxr.conf`
 
else
    #grab sourceroot from config file indexing multiple trees where
    #format is "sourceroot: treename dirname"
    src_dir=`sed -n 's@^sourceroot:[    ]*\(.*\)@\1@p' < $lxr_dir/lxr.conf | grep $TREE | sed -n "s@^$TREE \(.*\)@\1@p"`
fi 

log=$db_dir/cvs.log

exec > $log 2>&1
set -x

date

# update the lxr sources
pwd
time cvs -d $CVSROOT update -dP

date

# then update the Mozilla sources
cd $src_dir
cd ..

# endico: check out the source
case "$1" in

'classic')
    time cvs -Q -d $CVSROOT checkout -P -rMozillaSourceClassic_19981026_BRANCH MozillaSource
    ;;
'ef')
    time cvs -Q -d $CVSROOT checkout -P mozilla/ef
    time cvs -Q -d $CVSROOT checkout -P mozilla/nsprpub
    ;;
'grendel')
    time cvs -Q -d $CVSROOT checkout -P Grendel
    ;;
'mailnews')
    time cvs -Q -d $CVSROOT checkout -P SeaMonkeyMailNews
    ;;
'mozilla')
    time cvs -Q -d $CVSROOT checkout -P mozilla
    ;;
'nspr')
    time cvs -Q -d $CVSROOT checkout -P NSPR
    ;;
'seamonkey')
    time cvs -Q -d $CVSROOT checkout -P SeaMonkeyAll
    ;;
esac


date
uptime

exit 0
