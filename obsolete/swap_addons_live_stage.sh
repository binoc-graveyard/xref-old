#!/bin/sh
## save the curent 'addons-old'... will use this later
#mv /data/mxr-data/addons-old /data/mxr-data/addons-next-stage
## These are basically instant
#mv /data/mxr-data/addons /data/mxr-data/addons-old
#mv /data/mxr-data/addons-stage /data/mxr-data/addons
## at this point, there is no addons-stage... take the 'old' tree and make it the new stage
#mv /data/mxr-data/addons-next-stage /data/mxr-data/addons-stage
#rsync -av --delete --exclude=/addons /data/mxr-data/addons/ /data/mxr-data/addons-stage
#rm -rf /data/mxr-data/addons-stage/addons # (should be unnecessary, unless exclude messes us up)
#mkdir /data/mxr-data/addons-stage/addons

cd /var/www/webtools/mxr

# Clean out stage
rm -rf /data/mxr-data/addons-stage/addons # should already be empty
mkdir /data/mxr-data/addons-stage/addons

# Run the update against stage - *NOT* update-full-onetree.sh
OUT1=`perl update-src.pl -cron addons-stage 2>&1`

# Swap stage into live
mv /data/mxr-data/addons/addons /data/mxr-data/addons/addons-old
mv /data/mxr-data/addons-stage/addons /data/mxr-data/addons/addons
rm -rf /data/mxr-data/addons/addons-old &

# xref and index on live, so that the paths are correct
OUT2=`perl update-xref.pl -cron addons 2>&1`
OUT3=`perl update-search.pl -cron addons 2>&1`
if [ -n "$OUT1" ] || [ -n "$OUT2" ] || [ -n "$OUT3" ]; then
  echo "Updating addons..."
  echo "$OUT1"
  echo "$OUT2"
  echo "$OUT3"
fi

wait
