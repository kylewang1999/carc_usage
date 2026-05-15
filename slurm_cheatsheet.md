# Slurm Cheatsheet

## Check GPU Resources

Run these commands from a login node.

### Show GPU Partitions and Configured GPUs

```bash
sinfo -o "%20P %10a %10l %8D %30G %N"
```

Useful columns:

- `PARTITION`: partition name
- `AVAIL`: whether the partition is available
- `TIMELIMIT`: max wall time
- `NODES`: number of nodes
- `GRES`: generic resources, commonly GPUs
- `NODELIST`: node names

### Show Node-Level GPU Availability

```bash
sinfo -N -o "%20N %10P %10t %12C %30G"
```

Useful columns:

- `NODELIST`: node name
- `PARTITION`: partition name
- `STATE`: node state
- `CPUS(A/I/O/T)`: allocated, idle, other, and total CPUs
- `GRES`: configured generic resources, such as `gpu:a100:4`

If you know the GPU partition name, filter to it:

```bash
sinfo -p gpu -N -o "%20N %10t %12C %30G"
```

Replace `gpu` with the actual partition name from `sinfo`.

### Inspect a Specific Node

```bash
scontrol show node <node-name> | egrep "NodeName|State=|Gres=|CfgTRES|AllocTRES"
```

Look for fields like:

```text
Gres=gpu:a100:4
CfgTRES=...,gres/gpu=4
AllocTRES=...,gres/gpu=2
```

This means the node has 4 GPUs configured and 2 GPUs currently allocated.

### Show Jobs Requesting GPUs

```bash
squeue -o "%.18i %.9P %.8u %.2t %.10M %.6D %b %R"
```

The `%b` column shows requested GRES, often like:

```text
gpu:1
gpu:a100:2
```

### Quick GPU Resource Snapshot

```bash
sinfo -N -o "%N %P %t %G"
squeue -o "%.18i %.9P %.8u %.2t %.6D %b %R"
```

Use this when you just want a quick look at GPU nodes and active GPU requests.
