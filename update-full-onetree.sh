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
OUT1=`perl update-src.pl $CRON "$TREE" 2>&1`
OUT2=`perl update-xref.pl $CRON $UNIT "$TREE" 2>&1`
OUT3=`perl update-search.pl $CRON "$TREE" 2>&1`
if [ -n "$OUT1" ] || [ -n "$OUT2" ] || [ -n "$OUT3" ]; then
  echo "Updating $TREE..."
  echo "$OUT1"
  echo "$OUT2"
  echo "$OUT3"
fi

