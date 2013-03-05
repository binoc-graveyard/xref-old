#!/bin/sh
cd `dirname $0`
TREE="$1"
CRON=""
UNIT=""
if [ -n "$2" ] && [ "$1" = "-cron" ]; then
    TREE="$2"
    CRON="$1"
fi
if [ -n "$3" ] && [ "$2" = "--by-unit" ]; then
    TREE="$3"
    UNIT="$2"
fi

DURATION=""
if [ ${TREE} = "addons" ]; then
    DURATION="long"
elif [ ${TREE} = "projects-central" ]; then
    DURATION="medium"
else
    DURATION="short"
fi    

LOCKFILE=/var/lock/mxr/${DURATION}/${TREE}.lock

if [ -f $LOCKFILE ]; then
    LOCKPID=`cat $LOCKFILE`
    ps $LOCKPID > /dev/null
    if [ $? -eq 0 ]
    then
        logger -p local7.err -t ${TREE} "ERR: Tried to start a new job while a previous one was still running. Aborting this one."
        exit 0
    else
        logger -p local7.warning -t ${TREE} "WARN: stale lockfile found, removing."
        rm $LOCKFILE
    fi
fi
echo $$ > $LOCKFILE

logger -p local7.info -t ${TREE} "INFO: Starting."

# Debug logging... currently just informational, but eventually could institute an abort or sleep on this
NUMRUNNING=$(find /var/lock/mxr -type f | wc -l)
logger -p local7.debug -t ${TREE} "DEBUG: ${NUMRUNNING} total running or stale MXR jobs."

TREE_PATH=$(grep "^sourceroot: $TREE " /data/www/mxr.mozilla.org/lxr.conf | head -n 1 | awk '{print $3}')

OUT1=`perl update-src.pl $CRON "$TREE" 2>&1`

if [ -f "${TREE_PATH}/last-processed" ] && [ -z "$(find ${TREE_PATH} -type f -newer ${TREE_PATH}/last-processed ! -path "*/.hg/*" ! -path "*/CVS/*" ! -path "*/.git/*" ! -path "${TREE_PATH}/.mozconfig.out" -print -quit)" ]; then
	echo "$TREE: No files changed, skipping xref and indexing"
	logger -p local7.info -t ${TREE} "INFO: No files changed, skipping xref and indexing"
	OUT2=''
	OUT3=''
else
	echo "$TREE: Has changes, running xref and search..."
	logger -p local7.info -t ${TREE} "INFO: Has changes, running xref and search"
	OUT2=`perl update-xref.pl $CRON $UNIT "$TREE" 2>&1`
	OUT3=`perl update-search.pl $CRON "$TREE" 2>&1`
	touch "${TREE_PATH}/last-processed"
fi

if [ -n "$OUT1" ] || [ -n "$OUT2" ] || [ -n "$OUT3" ]; then
  echo "Updating $TREE..."
  echo "$OUT1"
  echo "$OUT2"
  echo "$OUT3"
fi

logger -p local7.info -t ${TREE} "INFO: Done."

rm $LOCKFILE
