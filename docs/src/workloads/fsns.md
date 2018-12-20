# FSNS

## Script Arguments

```sh
/street/python/vgsl_train.py:
  --final_learning_rate: Final learning rate
    (default: '2e-05')
    (a number)
  --initial_learning_rate: Initial learning rate
    (default: '2e-05')
    (a number)
  --learning_rate_halflife: Halflife of learning rate
    (default: '1600000')
    (an integer)
  --master: Name of the TensorFlow master to use.
    (default: '')
  --max_steps: Number of steps to train for.
    (default: '10000')
    (an integer)
  --model_str: Network description.
    (default: '1,150,600,3[S2(4x150)0,2 Ct5,5,16 Mp2,2 Ct5,5,64 Mp3,3([Lrys64 Lbx128][Lbys64 Lbx128][Lfys64 Lbx128])S3(3x0)2,3Lfx128 Lrx128 S0(1x4)0,3 Do Lfx256]O1c134')
  --num_preprocess_threads: Number of input threads
    (default: '4')
    (an integer)
  --optimizer_type: Optimizer from:GradientDescent, AdaGrad, Momentum, Adam
    (default: 'Adam')
  --ps_tasks: Number of tasks in the ps job.If 0 no ps job is used.
    (default: '0')
    (an integer)
  --task: Task id of the replica running the training.
    (default: '0')
    (an integer)
  --train_data: Training data filepattern
  --train_dir: Directory where to write event logs.
    (default: '/tmp/mdir')

tensorflow.python.platform.app:
  -h,--[no]help: show this help
    (default: 'false')
  --[no]helpfull: show full help
    (default: 'false')
  --[no]helpshort: show this help
    (default: 'false')

absl.flags:
  --flagfile: Insert flag definitions from the given file into the command line.
    (default: '')
  --undefok: comma-separated list of flag names that it is okay to specify on the command line even if the program does not define a flag with that name.  IMPORTANT: flags in this list that
    have arguments MUST use the --flag=value format.
    (default: '')
```

### File Changes

* `shapes.py`, line 48: `range(num_dims) -> list(range(num_dims))`
* `nn_ops.py`, line 22: add `from tensorflow.python.framework import ops`
* `nn_ops.py`, line 103: `@tf -> @ops`
* `vgsl_model.py`, line 447: Swap `self.sparse_labels, ctc_input` arguments. See
    <https://github.com/mozilla/DeepSpeech/issues/287> for a similar error.
