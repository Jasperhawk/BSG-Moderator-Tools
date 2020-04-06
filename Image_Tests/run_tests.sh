#!/bin/bash

# Runs the image generation tests using the default version of the gimp
IFS='
'

mkdir -p results
cd data
for x in *csv; do
   gimp -i -b "(script-fu-BSGP-Run-Batch \"$x\")" -b '( gimp-quit 1 )'
   mv ${x/csv/jpg} ../results
done
