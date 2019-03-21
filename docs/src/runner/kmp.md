## Documentation on KMP_HW_SUBSET:

Specifies the number of sockets, cores per socket, and the number of threads per 
core, to use with an OpenMP application, as an alternative to writing explicit 
affinity settings or a process affinity mask. You can also specify an offset value to 
set which resources to use.

An extended syntax is available when `KMP_TOPOLOGY_METHOD=hwloc`. Depending on what 
resources are detected, you may be able to specify additional resources, such as NUMA 
nodes and groups of hardware resources that share certain cache levels. For example, 
tiles are sets of cores that share an L2 cache on some processors in the Intel® Xeon 
Phi™ family.

Basic syntax:

```
socketsS[@offset],coresC[@offset],threadsT
```

S, C and T are not case-sensitive.

- sockets: The number of sockets to use.
- cores: The number of cores to use per socket.
- threads: The number of threads to use per core.
- offset: (Optional) The number of sockets or cores to skip.

Extended syntax when `KMP_TOPOLOGY_METHOD=hwloc:`

```
socketsS[@offset],numasN[@offset],tilesL2[@offset],coresC[@offset],threadsT
```

S, N, L2, C and T are not case-sensitive. Some designators are aliases on some 
machines. 

Specifying duplicate or multiple alias designators for the same resource type is not 
allowed.

- sockets: The number of sockets to use.
- numas: If detectable, the number of NUMA nodes to use per socket,where available.
- tiles: If detectable, the number of tiles to use per NUMA node, where available, 
      otherwise per socket.
- cores: The number of cores to use per socket, where available, otherwise per NUMA 
      node, or per socket.
- threads: The number of threads to use per core.
- offset: (Optional) The number of sockets or cores to skip.

**NOTE**

If you don't specify one or more types of resource, sockets, cores or threads, all 
available resources of that type are used.

**NOTE**

If a particular type of resource is specified, but detection of that resource is not 
supported by the chosen topology detection method, the setting of `KMP_HW_SUBSET` is 
ignored.

**NOTE** 

This variable does not work if the OpenMP affinity is set to disabled.
Default: If omitted, the default value is to use all the available hardware 
resources.

## Examples

2s,4c,2t: Use the first 2 sockets (s0 and s1), the first 4 cores on each socket 
(c0 - c3), and 2 threads per core.

2s@2,4c@8,2t: Skip the first 2 sockets (s0 and s1) and use 2 sockets (s2-s3), skip 
the first 8 cores (c0-c7) and use 4 cores on each socket (c8-c11), and use 2 threads 
per core.

5C@1,3T: Use all available sockets, skip the first core and use 5 cores, and use 3 
threads per core.

2T: Use all cores on all sockets, 2 threads per core.

4C@12: Use 4 cores with offset 12, all available threads per core.
