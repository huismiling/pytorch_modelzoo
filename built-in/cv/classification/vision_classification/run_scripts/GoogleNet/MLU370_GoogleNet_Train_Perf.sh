#!/bin/bash
set -e

CUR_DIR=$(cd $(dirname $0);pwd)

pushd $CUR_DIR
export MLU_VISIBLE_DEVICES=0,1,2,3
bash $CUR_DIR/../../test/test_benchmark.sh googlenet-fp32-mlu-ddp
#bash $CUR_DIR/../../test/test_benchmark.sh googlenet-amp-mlu-ddp
popd

