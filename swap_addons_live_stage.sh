#!/bin/sh
rm -rf /data/mxr-data/amo-old
mv /data/mxr-data/amo /data/mxr-data/amo-old
mv /data/mxr-data/amo-stage /data/mxr-data/amo
rsync -av --exclude=/amo /data/mxr-data/amo/ /data/mxr-data/amo-stage
mkdir /data/mxr-data/amo-stage/amo
