#!/bin/bash
dir=exp/tri6_nnet
train_stage=-10
realign_epochs="6 10"

. conf/common_vars.sh
. ./lang.conf

# This parameter will be used when the training dies at a certain point.
train_stage=-100
. ./utils/parse_options.sh

dir=${dir}_realign$(echo $realign_epochs | tr ' ' '_')
set -e
set -o pipefail
set -u

# Wait till the main run.sh gets to the stage where's it's 
# finished aligning the tri5 model.
echo "Waiting till exp/tri5_ali/.done exists...."
while [ ! -f exp/tri5_ali/.done ]; do sleep 30; done
echo "...done waiting for exp/tri5_ali/.done"

if [ ! -f $dir/.done ]; then

  if [[ $(hostname -f) == *.clsp.jhu.edu ]] && [ ! -d $dir/egs/storage ]; then
    utils/create_split_dir.pl /export/b0{1,2,3,4}/$USER/kaldi-data/egs/babel-$(date +'%m_%d_%M_%H')/s5/$dir/egs/storage $dir/egs/storage
  fi

  for e in $realign_epochs; do
    if [[ $(hostname -f) == *.clsp.jhu.edu ]] && [ ! -d $dir/egs_$e/storage ]; then
      utils/create_split_dir.pl /export/b0{1,2,3,4}/$USER/kaldi-data/egs/babel-$(date +'%m_%d_%M_%H')/s5/$dir/egs_$e/storage $dir/egs_$e/storage
    fi
  done

  steps/nnet2/train_pnorm.sh \
    --stage $train_stage --mix-up $dnn_mixup \
    --initial-learning-rate $dnn_init_learning_rate \
    --final-learning-rate $dnn_final_learning_rate \
    --num-hidden-layers $dnn_num_hidden_layers \
    --pnorm-input-dim $dnn_input_dim \
    --pnorm-output-dim $dnn_output_dim \
    --cmd "$train_cmd" \
    --realign-epochs "$realign_epochs" --num-jobs-align $train_nj \
    --align-use-gpu no --align-cmd "$decode_cmd" \
    "${dnn_gpu_parallel_opts[@]}" \
    data/train data/lang exp/tri5_ali $dir || exit 1

  touch $dir/.done
fi

