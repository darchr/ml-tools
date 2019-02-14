# RNN Translator

```@docs
Launcher.Translator
```

## Script Arguments

```
optional arguments:
  -h, --help            show this help message and exit

dataset setup:
  --dataset-dir DATASET_DIR
                        path to directory with training/validation data
                        (default: None)
  --max-size MAX_SIZE   use at most MAX_SIZE elements from training dataset
                        (useful for benchmarking), by default uses entire
                        dataset (default: None)

results setup:
  --results-dir RESULTS_DIR
                        path to directory with results, it it will be
                        automatically created if does not exist (default:
                        ../results)
  --save SAVE           defines subdirectory within RESULTS_DIR for results
                        from this training run (default: gnmt_wmt16)
  --print-freq PRINT_FREQ
                        print log every PRINT_FREQ batches (default: 5)

model setup:
  --model-config MODEL_CONFIG
                        GNMT architecture configuration (default:
                        {'hidden_size': 1024,'num_layers': 4, 'dropout': 0.2,
                        'share_embedding': True})
  --smoothing SMOOTHING
                        label smoothing, if equal to zero model will use
                        CrossEntropyLoss, if not zero model will be trained
                        with label smoothing loss based on KLDivLoss (default:
                        0.1)

general setup:
  --math {fp32,fp16}    arithmetic type (default: fp32)
  --seed SEED           set random number generator seed (default: None)
  --disable-eval        disables validation after every epoch (default: False)
  --workers WORKERS     number of workers for data loading (default: 0)
  --cuda                enables cuda (use '--no-cuda' to disable) (default:
                        True)
  --cudnn               enables cudnn (use '--no-cudnn' to disable) (default:
                        True)

training setup:
  --batch-size BATCH_SIZE
                        batch size for training (default: 128)
  --epochs EPOCHS       number of total epochs to run (default: 8)
  --optimization-config OPTIMIZATION_CONFIG
                        optimizer config (default: {'optimizer': 'Adam', 'lr':
                        5e-4})
  --grad-clip GRAD_CLIP
                        enabled gradient clipping and sets maximum gradient
                        norm value (default: 5.0)
  --max-length-train MAX_LENGTH_TRAIN
                        maximum sequence length for training (default: 50)
  --min-length-train MIN_LENGTH_TRAIN
                        minimum sequence length for training (default: 0)
  --target-bleu TARGET_BLEU
                        target accuracy (default: None)
  --bucketing           enables bucketing (use '--no-bucketing' to disable)
                        (default: True)

validation setup:
  --eval-batch-size EVAL_BATCH_SIZE
                        batch size for validation (default: 32)
  --max-length-val MAX_LENGTH_VAL
                        maximum sequence length for validation (default: 150)
  --min-length-val MIN_LENGTH_VAL
                        minimum sequence length for validation (default: 0)
  --beam-size BEAM_SIZE
                        beam size (default: 5)
  --len-norm-factor LEN_NORM_FACTOR
                        length normalization factor (default: 0.6)
  --cov-penalty-factor COV_PENALTY_FACTOR
                        coverage penalty factor (default: 0.1)
  --len-norm-const LEN_NORM_CONST
                        length normalization constant (default: 5.0)

checkpointing setup:
  --start-epoch START_EPOCH
                        manually set initial epoch counter (default: 0)
  --resume PATH         resumes training from checkpoint from PATH (default:
                        None)
  --save-all            saves checkpoint after every epoch (default: False)
  --save-freq SAVE_FREQ
                        save checkpoint every SAVE_FREQ batches (default:
                        5000)
  --keep-checkpoints KEEP_CHECKPOINTS
                        keep only last KEEP_CHECKPOINTS checkpoints, affects
                        only checkpoints controlled by --save-freq option
                        (default: 0)

distributed setup:
  --rank RANK           rank of the process, do not set! Done by multiproc
                        module (default: 0)
  --world-size WORLD_SIZE
                        number of processes, do not set! Done by multiproc
                        module (default: 1)
  --dist-url DIST_URL   url used to set up distributed training (default:
                        tcp://localhost:23456)
```
