#!/bin/sh
cd `dirname $0`
TREE="$1"
CRON=""
if [ -n "$2" ] && [ "$1" == "-cron" ]; then
    TREE="$2"
    CRON="$1"
fi
if [ "$TREE" == "amo-stage"]; then
OUT5=`rsync -a --delete /data/mxr-data/amo/ /data/mxr-data/amo-backup 2>&1`
fi
OUT1=`perl update-src.pl $CRON "$TREE" 2>&1`
OUT2=`perl update-xref.pl $CRON "$TREE" 2>&1`
OUT3=`perl update-search.pl $CRON "$TREE" 2>&1`
if [ "$TREE" == "amo-stage"]; then
OUT4=`perl update-root.pl $CRON "$TREE" /data/mxr-data/amo/amo 2>&1`
fi
if [ -n "$OUT1" ] || [ -n "$OUT2" ] || [ -n "$OUT3" ] || [ -n "$OUT4" ] || [ -n "$OUT5" ]; then
  echo "Updating $TREE..."
  echo "$OUT5"
  echo "$OUT1"
  echo "$OUT2"
  echo "$OUT3"
  echo "$OUT4"
fi

