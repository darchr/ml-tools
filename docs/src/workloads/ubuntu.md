# Ubuntu Workloads

Workloads that run under the official `ubuntu` docker image.

## Test

A simple shell script that prints a message, sleeps for a few seconds, prints another
message and exits. The point of this workload is to provide a simple and quick to run
test to decrease debugging time.

* File name: `/workloads/ubuntu/sleep.sh`
* Container entry point: `/home/startup/sleep.sh`

**Launcher Docs**
```@docs
Launcher.TestWorkload
```
