#!/bin/bash
set -e
# env
CUR_DIR=$(cd $(dirname $0);pwd)
MaskRCNN_DIR=$(cd ${CUR_DIR}/../models;pwd)

# 帮助函数
function usage () {
    echo -e "\033[32m Usage : \033[0m"
    echo -e "\033[32m ------------------------------------------------------------------- \033[0m"
    echo "|  bash $0 [-c] [config_file] precision-device-[options...]"
    echo "|      Supported options:"
    echo "|             net: bert_msra"
    echo "|             precision: fp32, O0, O1, O2, O3, amp"
    echo "|             device: mlu, gpu"
    echo "|             option1(multicards): ddp"
    echo "|                                                   "
    echo "|  eg.1. bash test_benchmark.sh fp32-mlu"
    echo "|      which means running maskrcnn on single MLU card with fp32 precision."
    echo "|                                                   "
    echo "|  eg.2. export MLU_VISIBLE_DEVICES=0,1,2,3 && bash test_benchmark.sh O1-mlu-ddp"
    echo "|      which means running maskrcnn on 4 MLU cards with O1 precision."
    echo -e "\033[32m ------------------------------------------------------------------- \033[0m"
}

# 获取用户指定config函数并执行,得到对应config的参数配置
config_file=""
while getopts 'hc:' opt; do
   case "$opt" in
       h)  usage ; exit 1 ;;
       c)  config_file=$OPTARG ;;
       ?)  echo "unrecognized optional arg : "; $opt; usage; exit 1;;
   esac
done
## 加载参数配置
config=$1
if [[ $config_file != "" ]]; then
    source $config_file
else
    source ${CUR_DIR}/params_config.sh
fi
set_configs "$config"


PORT=${PORT:-29503}
MASTER_ADDR=${MASTER_ADDR:-"127.0.0.1"}

# train cmd
run_cmd="MaskRCNN_train.py \
        --config-file configs/e2e_mask_rcnn_R_101_FPN_1x.yaml \
        --prefix mask \
        --seed 0 "

# config配置到网络脚本的转换
main() {
    export DATASET_NAME="COCO2017"
    pushd $MaskRCNN_DIR
    pip install cython==0.29.16
    pip install -r requirements.txt
    python setup.py build develop
    rm -fr "datasets"
    mkdir "datasets"
    ln -sf ${PYTORCH_TRAIN_DATASET}/COCO2017 "./datasets/coco"
    # 配置DDP相关参数
    if [[ $ddp == "True" ]]; then
      run_cmd="-m torch.distributed.launch --master_addr=$MASTER_ADDR --master_port=$PORT --nproc_per_node=${card_num} $run_cmd"
    fi

    # 配置混合精度相关参数
    if [[ ${precision} =~ ^O[0-3]{1}$ ]]; then  
      run_cmd="${run_cmd} --cnmix --opt_level ${precision} "
    elif [[ ${precision} == "amp" ]]; then
      echo "MaskRCNN have not supported pytorch AMP yet, please run precision fp32 instead."
      exit 1
    fi

    # 是否跳过推理部分
    if [[ ${evaluate} == "False" ]]; then
         run_cmd="$run_cmd --skip-test"
    fi

    run_cmd="$run_cmd \
              MODEL.DEVICE mlu \
              MODEL.RPN.FPN_POST_NMS_TOP_N_TRAIN 2000 \
              MODEL.WEIGHT $ckpt \
              SOLVER.IMS_PER_BATCH $batch_size \
              SOLVER.BASE_LR $lr \
              SOLVER.MAX_ITER $train_iters \
              TEST.MAX_ITER $eval_iters \
              DATALOADER.NUM_WORKERS $num_workers"

    # 清除历史训练数据
    if [ -d "maskrcnn" ]; then
	rm -rf "maskrcnn"
    fi

    # 参数配置完毕，运行脚本
    # To avoid system being overloaded in multicard training process, we need to limit the value of OMP_NUM_THREADS
    echo "python $run_cmd"
    eval "OMP_NUM_THREADS=1 python $run_cmd"

    popd
}

pushd $CUR_DIR
main
popd
