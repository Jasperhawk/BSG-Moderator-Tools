#!/bin/bash

set -e
# Runs the image generation tests using the default version of the gimp
IFS='
'

mkdir -p results
cd data
for x in *csv; do
   fullname=$(readlink -f "$x")
   gimp -i -b "(script-fu-BSGP-Run-Batch \"$fullname\")" -b '( gimp-quit 1 )'
   mv ${x/csv/jpg} ../results
   rm ${x/csv/xcf}
   rm *log
done
