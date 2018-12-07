# PAPI Notes

The following issues about PAPI are either known or were discovered:

- Some hardware performance counters such as single precision and double precision floating
    point instruction counters do not seem to work on AMD EPYC processors:
    <https://bitbucket.org/icl/papi/issues/56/dp-and-sp-validation-tests-on-amd>

- PAPI version `stable-5.6.0`: Function `PAPI_read` (and related functions that read from
    event counters) trigger an integer divide by zero exception on the AMD EPYC system I 
    tried, rendering this version unusable. It's possible that this would work on Intel 
    hardware, but I haven't tried.

- PAPI master `0fdac4fc7f95f0ac8039e431419a5133088911af`: Reads from hardware counters 
    monitoring L1 cache loads and stores (as well as loads and stores for other levels
    in the memory hierarchy) return negative numbers both consistently and sporadically on 
    Intel systems. The hardware counters I believe are 48-bits, thus we should not be seeing
    any counter overflow. I'm calling this a bug.

- PAPI version `stable-5.5.0`: No hardware events are recognized on the Intel system. 
    I think this may be due to `libpfm` being an older version.

- The version of PAPI that works for me and seems to return consistent and reasonable results
    across trials is `stable-5.5.1`. However, this version is old and I have concerns that
    it may be lacking support for newer generations of processors (i.e. Cascade Lake)    

**Final Solution**: After playing around with `git bisesct`, I discovered that the integer
division bug cropped up when reading of performance counters via the `rdpmc` instruction was
switched to the default (sometime after the 5.5.1 release). The `rdpmc` instruction is a
x86 instruction for reading quickly from the performance counters. It seems that the PAPI
implementation of using this instruction is quite buggy. By compiling PAPI with `rdpmc`
turned off:
```
./configure --enable-perfevent-rdpmc=no
```
I was once again getting consistent and sensible numbers. Thus, I finally ended up using
the master released, but disabling `rdpmc`.

## Finding Perf Codes

A VERY helpful resource for finding event codes and such: 
<http://www.bnikolic.co.uk/blog/hpc-prof-events.html>.
