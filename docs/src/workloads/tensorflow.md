# Tensorflow Models

## Resnet

A model for ResNet that can be trained on either Cifar or ImageNet, though as of now only
ImageNet is supported.

* File: `/workloads/tensorflow/official/resnet/imagenet_main.py`
* Container entry point: `/models/official/resnet/imagenet_main.py`
* Dataset: 
* Volume Binds:

* **Script Arguments**

Common flags:
    * `--batch_size=size` : Configure batch size. Default: `32`
    * `--resnet_size=size` : Define the version of ResNet to use. Choices: 
        `18, 34, 50, 101, 152, 200`. Default: `50`
    * `--train_epochs=N` : Number of epochs to train for. Default: `90`
    * `--data_dir=path` : Path (inside the container) to the data directory. Default 
        provided by Launcher.  **NOTE**: If this is set to something besides `/imagenet` - 
        things will probably break horribly.

All flags:

```sh
Runs a ResNet model on the ImageNet dataset.
flags:

absl.app:
  -?,--[no]help: show this help
    (default: 'false')
  --[no]helpfull: show full help
    (default: 'false')
  -h,--[no]helpshort: show this help
    (default: 'false')
  --[no]helpxml: like --helpfull, but generates XML output
    (default: 'false')
  --[no]only_check_args: Set to true to validate args and exit.
    (default: 'false')
  --[no]pdb_post_mortem: Set to true to handle uncaught exceptions with PDB post mortem.
    (default: 'false')
  --profile_file: Dump profile information to a file (for python -m pstats). Implies --run_with_profiling.
  --[no]run_with_pdb: Set to true for PDB debug mode
    (default: 'false')
  --[no]run_with_profiling: Set to true for profiling the script. Execution will be slower, and the output format might change over time.
    (default: 'false')
  --[no]use_cprofile_for_profiling: Use cProfile instead of the profile module for profiling. This has no effect unless --run_with_profiling is set.
    (default: 'true')

absl.logging:
  --[no]alsologtostderr: also log to stderr?
    (default: 'false')
  --log_dir: directory to write logfiles into
    (default: '')
  --[no]logtostderr: Should only log to stderr?
    (default: 'false')
  --[no]showprefixforinfo: If False, do not prepend prefix to info messages when it's logged to stderr, --verbosity is set to INFO level, and python logging is used.
    (default: 'true')
  --stderrthreshold: log messages at this level, or more severe, to stderr in addition to the logfile.  Possible values are 'debug', 'info', 'warning', 'error', and 'fatal'.
    Obsoletes --alsologtostderr. Using --alsologtostderr cancels the effect of this flag. Please also note that this flag is subject to --verbosity and requires logfile not
    be stderr.
    (default: 'fatal')
  -v,--verbosity: Logging verbosity level. Messages logged at this level or lower will be included. Set to 1 for debug logging. If the flag was not set or supplied, the
    value will be changed from the default of -1 (warning) to 0 (info) after flags are parsed.
    (default: '-1')
    (an integer)

official.resnet.resnet_run_loop:
  --[no]eval_only:
    Skip training and only perform evaluation on the latest checkpoint.
    (default: 'false')
  -ft,--[no]fine_tune:
    If True do not train any parameters except for the final layer.
    (default: 'false')
  --[no]image_bytes_as_serving_input:
    If True exports savedmodel with serving signature that accepts JPEG image bytes
    instead of a fixed size [HxWxC] tensor that represents the image. The former is
    easier to use for serving at the expense of image resize/cropping being done as
    part of model inference. Note, this flag only applies to ImageNet and cannot be
    used for CIFAR.
    (default: 'false')
  -pmcp,--pretrained_model_checkpoint_path:
    If not None initialize all the network except the final layer with these values
  -rs,--resnet_size: <18|34|50|101|152|200>:
    The size of the ResNet model to use.
    (default: '50')
  -rv,--resnet_version: <1|2>:
    Version of ResNet. (1 or 2) See README.md for details.
    (default: '1')

official.utils.flags._base:
  -bs,--batch_size:
    Batch size for training and evaluation. When using multiple gpus, this is the
    global batch size for all devices. For example, if the batch size is 32 and
    there are 4 GPUs, each GPU will get 8 examples on each step.
    (default: '32')
    (an integer)
  --[no]clean:
    If set, model_dir will be removed if it exists.
    (default: 'false')
  -dd,--data_dir:
    The location of the input data.
    (default: '/tmp')
  -ebe,--epochs_between_evals:
    The number of training epochs to run between evaluations.
    (default: '1')
    (an integer)
  -ed,--export_dir:
    If set, a SavedModel serialization of the model will be exported to this
    directory at the end of training. See the README for more details and relevant
    links.
  -hk,--hooks:
    A list of (case insensitive) strings to specify the names of training hooks.
      Hook:
        loggingtensorhook
        loggingmetrichook
        examplespersecondhook
        profilerhook
      Example: `--hooks ProfilerHook,ExamplesPerSecondHook`
    See official.utils.logs.hooks_helper for details.
    (default: 'LoggingTensorHook')
    (a comma separated list)
  -md,--model_dir:
    The location of the model checkpoint files.
    (default: '/tmp')
  -ng,--num_gpus:
    How many GPUs to use with the DistributionStrategies API. The default is 1 if
    TensorFlow can detect a GPU, and 0 otherwise.
    (default: '0')
    (an integer)
  -st,--stop_threshold:
    If passed, training will stop at the earlier of train_epochs and when the
    evaluation metric is  greater than or equal to stop_threshold.
    (a number)
  -te,--train_epochs:
    The number of epochs used to train.
    (default: '90')
    (an integer)

official.utils.flags._benchmark:
  -bld,--benchmark_log_dir:
    The location of the benchmark logging.
  --benchmark_logger_type: <BaseBenchmarkLogger|BenchmarkFileLogger|BenchmarkBigQueryLogger>:
    The type of benchmark logger to use. Defaults to using BaseBenchmarkLogger
    which logs to STDOUT. Different loggers will require other flags to be able to
    work.
    (default: 'BaseBenchmarkLogger')
  -bti,--benchmark_test_id:
    The unique test ID of the benchmark run. It could be the combination of key
    parameters. It is hardware independent and could be used compare the performance
    between different test runs. This flag is designed for human consumption, and
    does not have any impact within the system.
  -bds,--bigquery_data_set:
    The Bigquery dataset name where the benchmark will be uploaded.
    (default: 'test_benchmark')
  -bmt,--bigquery_metric_table:
    The Bigquery table name where the benchmark metric information will be
    uploaded.
    (default: 'benchmark_metric')
  -brst,--bigquery_run_status_table:
    The Bigquery table name where the benchmark run status information will be
    uploaded.
    (default: 'benchmark_run_status')
  -brt,--bigquery_run_table:
    The Bigquery table name where the benchmark run information will be uploaded.
    (default: 'benchmark_run')
  -gp,--gcp_project:
    The GCP project name where the benchmark will be uploaded.

official.utils.flags._misc:
  -df,--data_format: <channels_first|channels_last>:
    A flag to override the data format used in the model. channels_first provides a
    performance boost on GPU but is not always compatible with CPU. If left
    unspecified, the data format will be chosen automatically based on whether
    TensorFlow was built for CPU or GPU.

official.utils.flags._performance:
  -ara,--all_reduce_alg:
    Defines the algorithm to use for performing all-reduce.See
    tf.contrib.distribute.AllReduceCrossTowerOps for more details and available
    options.
  --datasets_num_parallel_batches:
    Determines how many batches to process in parallel when using map and batch
    from tf.data.
    (an integer)
  --datasets_num_private_threads:
    Number of threads for a private threadpool created for alldatasets
    computation..
    (an integer)
  -dt,--dtype: <fp16|fp32>:
    The TensorFlow datatype used for calculations. Variables may be cast to a
    higher precision on a case-by-case basis for numerical stability.
    (default: 'fp32')
  -inter,--inter_op_parallelism_threads:
    Number of inter_op_parallelism_threads to use for CPU. See TensorFlow
    config.proto for details.
    (default: '0')
    (an integer)
  -intra,--intra_op_parallelism_threads:
    Number of intra_op_parallelism_threads to use for CPU. See TensorFlow
    config.proto for details.
    (default: '0')
    (an integer)
  -ls,--loss_scale:
    The amount to scale the loss by when the model is run. Before gradients are
    computed, the loss is multiplied by the loss scale, making all gradients
    loss_scale times larger. To adjust for this, gradients are divided by the loss
    scale before being applied to variables. This is mathematically equivalent to
    training without a loss scale, but the loss scale helps avoid some intermediate
    gradients from underflowing to zero. If not provided the default for fp16 is 128
    and 1 for all other dtypes.
    (an integer)
  -mts,--max_train_steps:
    The model will stop training if the global_step reaches this value. If not set,
    training will run until the specified number of epochs have run as usual. It is
    generally recommended to set --train_epochs=1 when using this flag.
    (an integer)
  -gt_mode,--tf_gpu_thread_mode:
    Whether and how the GPU device uses its own threadpool.
  -synth,--[no]use_synthetic_data:
    If set, use fake data (zeroes) instead of a real dataset. This mode is useful
    for performance debugging, as it removes input processing steps, but will not
    learn anything.
    (default: 'false')

absl.flags:
  --flagfile: Insert flag definitions from the given file into the command line.
    (default: '')
  --undefok: comma-separated list of flag names that it is okay to specify on the command line even if the program does not define a flag with that name.  IMPORTANT: flags
    in this list that have arguments MUST use the --flag=value format.
    (default: '')
```

**Launcher Docs**
```@docs
Launcher.ResnetTF
```

## Changes Made to `imagenet_main.py`

* Lines 42-47: Made script expect training and validation files to be in `train` and 
    `validation` directories respectively whereas the original expected both to be in
    the same directory.

    Aditionally, made the `_NUM_TRAIN_FILES` and `_NUM_VALIDATION_FILES` be assigned to
    the number of files in these directories.

    This allows us to operate on a subset of the ImageNet data by just pointing to another
    folder.

    Also hardcoded `_DATA_DIR` to `/imagenet` to allow this to take place. This limits the
    migratability of this project outside of docker, but we'll deal with that when we need
    to.
