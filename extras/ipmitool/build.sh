#!/bin/bash

set -e

rm -rf packages pkg src

docker build -t ipmibuild .

docker run -it --rm -v $(pwd):/home/builder ipmibuild 

cp packages/home/x86_64/ipmitool-*.apk ../..
