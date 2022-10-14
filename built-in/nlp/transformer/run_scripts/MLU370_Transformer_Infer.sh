#!/bin/bash
set -e

CUR_DIR=$(cd $(dirname $0);pwd)
TRANS_DIR=$(cd ${CUR_DIR}/../;pwd)

# env
CORPORA_PATH=${TRANS_DIR}/corpora
CKPT_MODEL_PATH=${TRANS_DIR}/ckpt_model
if [ -z ${IWSLT_CORPUS_PATH} ]; then
  echo "please set environment variable IWSLT_CORPUS_PATH."
  exit 1
fi
if [ -z ${TRANSFORMER_CKPT} ]; then
  echo "please set environment variable TRANSFORMER_CKPT."
  exit 1
fi

if [ ! -d ${CORPORA_PATH} ]; then
  ln -s ${IWSLT_CORPUS_PATH} ${CORPORA_PATH}
fi
if [ ! -d ${CKPT_MODEL_PATH} ]; then
  ln -s ${TRANSFORMER_CKPT} ${CKPT_MODEL_PATH}
fi

pushd $TRANS_DIR
export MLU_VISIBLE_DEVICES=0,1,2,3,4,5,6,7
python transformer_test.py --pretrained ${CKPT_MODEL_PATH}/model_epoch_09.pth
popd
