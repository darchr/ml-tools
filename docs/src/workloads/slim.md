# Tensorflow Slim

This is actually a collection of models implemented using using Tensorflow's Slim framework.
The original repo for these models is 
<https://github.com/tensorflow/models/tree/master/research/slim>.

When I benchmarked this against the official tensorflow models for Resnet, this 
implementation seemed to train a little faster. Plus, the official models did not have
VGG implemented, which is why I ended up using this implementation.

## Using from Launcher

```@docs
Launcher.Slim
```

Navigate to the `Launcher/` directory, and launch julia with the command
```
julia --project
```
From inside Julia, to launch resnet 50 with a batchsize of 32, use the following command:
```julia
julia> using Launcher

julia> workload = Launcher.Slim(args = (model_name = "resnet_v1_50", batchsize = 32))
```

**Valid Networks**

The following is the list of valid inputs for the `model_name` argument:
```
alexnet_v2
cifarnet
overfeat
vgg_a
vgg_16
vgg_19
vgg_416
inception_v1
inception_v2
inception_v3
inception_v4
inception_resnet_v2
lenet
resnet_v1_50
resnet_v1_101
resnet_v1_152
resnet_v1_200
resnet_v2_50
resnet_v2_101
resnet_v2_152
resnet_v2_200
mobilenet_v1
mobilenet_v1_075
mobilenet_v1_050
mobilenet_v1_025
mobilenet_v2
mobilenet_v2_140
mobilenet_v2_035
nasnet_cifar
nasnet_mobile
nasnet_large
pnasnet_large
pnasnet_mobile
```

## Automatically Applied Arguments

These are arguments automatically supplied by Launcher.

* `--dataset_dir`: Binds the dataset at `imagenet_tf_slim` into `/imagenet` in the container.

* `--dataset_name`: Defaults to `imagenet`.

* `clone_on_cpu`: Defaults to `true`.


## Script Arguments:

```
Generic training script that trains a model using a given dataset.
flags:

/models/slim/train_image_classifier.py:
  --adadelta_rho: The decay rate for adadelta.
    (default: '0.95')
    (a number)
  --adagrad_initial_accumulator_value: Starting value for the AdaGrad accumulators.
    (default: '0.1')
    (a number)
  --adam_beta1: The exponential decay rate for the 1st moment estimates.
    (default: '0.9')
    (a number)
  --adam_beta2: The exponential decay rate for the 2nd moment estimates.
    (default: '0.999')
    (a number)
  --batch_size: The number of samples in each batch.
    (default: '32')
    (an integer)
  --checkpoint_exclude_scopes: Comma-separated list of scopes of variables to exclude when restoring from a checkpoint.
  --checkpoint_path: The path to a checkpoint from which to fine-tune.
  --[no]clone_on_cpu: Use CPUs to deploy clones.
    (default: 'false')
  --dataset_dir: The directory where the dataset files are stored.
  --dataset_name: The name of the dataset to load.
    (default: 'imagenet')
  --dataset_split_name: The name of the train/test split.
    (default: 'train')
  --end_learning_rate: The minimal end learning rate used by a polynomial decay learning rate.
    (default: '0.0001')
    (a number)
  --ftrl_initial_accumulator_value: Starting value for the FTRL accumulators.
    (default: '0.1')
    (a number)
  --ftrl_l1: The FTRL l1 regularization strength.
    (default: '0.0')
    (a number)
  --ftrl_l2: The FTRL l2 regularization strength.
    (default: '0.0')
    (a number)
  --ftrl_learning_rate_power: The learning rate power.
    (default: '-0.5')
    (a number)
  --[no]ignore_missing_vars: When restoring a checkpoint would ignore missing variables.
    (default: 'false')
  --label_smoothing: The amount of label smoothing.
    (default: '0.0')
    (a number)
  --labels_offset: An offset for the labels in the dataset. This flag is primarily used to evaluate the VGG and ResNet architectures which do not use a background class for the ImageNet
    dataset.
    (default: '0')
    (an integer)
  --learning_rate: Initial learning rate.
    (default: '0.01')
    (a number)
  --learning_rate_decay_factor: Learning rate decay factor.
    (default: '0.94')
    (a number)
  --learning_rate_decay_type: Specifies how the learning rate is decayed. One of "fixed", "exponential", or "polynomial"
    (default: 'exponential')
  --log_every_n_steps: The frequency with which logs are print.
    (default: '10')
    (an integer)
  --master: The address of the TensorFlow master to use.
    (default: '')
  --max_number_of_steps: The maximum number of training steps.
    (an integer)
  --model_name: The name of the architecture to train.
    (default: 'inception_v3')
  --momentum: The momentum for the MomentumOptimizer and RMSPropOptimizer.
    (default: '0.9')
    (a number)
  --moving_average_decay: The decay to use for the moving average.If left as None, then moving averages are not used.
    (a number)
  --num_clones: Number of model clones to deploy. Note For historical reasons loss from all clones averaged out and learning rate decay happen per clone epochs
    (default: '1')
    (an integer)
  --num_epochs_per_decay: Number of epochs after which learning rate decays. Note: this flag counts epochs per clone but aggregates per sync replicas. So 1.0 means that each clone will go
    over full epoch individually, but replicas will go once across all replicas.
    (default: '2.0')
    (a number)
  --num_preprocessing_threads: The number of threads used to create the batches.
    (default: '4')
    (an integer)
  --num_ps_tasks: The number of parameter servers. If the value is 0, then the parameters are handled locally by the worker.
    (default: '0')
    (an integer)
  --num_readers: The number of parallel readers that read data from the dataset.
    (default: '4')
    (an integer)
  --opt_epsilon: Epsilon term for the optimizer.
    (default: '1.0')
    (a number)
  --optimizer: The name of the optimizer, one of "adadelta", "adagrad", "adam","ftrl", "momentum", "sgd" or "rmsprop".
    (default: 'rmsprop')
  --preprocessing_name: The name of the preprocessing to use. If left as `None`, then the model_name flag is used.
  --quantize_delay: Number of steps to start quantized training. Set to -1 would disable quantized training.
    (default: '-1')
    (an integer)
  --replicas_to_aggregate: The Number of gradients to collect before updating params.
    (default: '1')
    (an integer)
  --rmsprop_decay: Decay term for RMSProp.
    (default: '0.9')
    (a number)
  --rmsprop_momentum: Momentum.
    (default: '0.9')
    (a number)
  --save_interval_secs: The frequency with which the model is saved, in seconds.
    (default: '600')
    (an integer)
  --save_summaries_secs: The frequency with which summaries are saved, in seconds.
    (default: '600')
    (an integer)
  --[no]sync_replicas: Whether or not to synchronize the replicas during training.
    (default: 'false')
  --task: Task id of the replica running the training.
    (default: '0')
    (an integer)
  --train_dir: Directory where checkpoints and event logs are written to.
    (default: '/tmp/tfmodel/')
  --train_image_size: Train image size
    (an integer)
  --trainable_scopes: Comma-separated list of scopes to filter the set of variables to train.By default, None would train all the variables.
  --weight_decay: The weight decay on the model weights.
    (default: '4e-05')
    (a number)
  --worker_replicas: Number of worker replicas.
    (default: '1')
    (an integer)
```

## Dataset
This workload uses the [Imagenet](@ref) dataset.

## File Changes

**`train_image_classifier.py`**

* Line 62: Change default value of `log_every_n_steps` from 10 to 5.

