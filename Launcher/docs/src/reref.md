# Computing the Reference Interval of Pages

Algorithm overview. We keep a stack of referenced addresses (encoded as UInt64) which are
the start addresses for pages. Addresses at the top of the stack are the most recently
referenced addresses.

The running application is sampled by writing to `/proc/$pid/clear_refs`, which clears the
reference bits on all pages currently mapped to the process. Some time later (specified by
the sleep period) the pages used by the process are read by reading `/proc/$pid/smaps`.

This is parsed to find the addresses of pages that have been referenced.

```@doc
Launcher.parse_smaps
```

We then traverse the stack from top to bottom, noting any addresses be come across that have
been recently referenced (i.e., in the set returned by `parse_smaps`). We note the depths of
these pages in a Dict, while traversing the old stack, a new stack is created with the newly
referenced pages on top.
