# Edit and Run Code with CARC using VSCode Extension


## 1 Motivation & the CARC “gotcha”

Remote SSH (Cursor/VSCode) is great for remote development: file explorer, inline linting, debugging, and a familiar terminal—without living in a browser IDE provided by [CARC OnDemand](https://www.carc.usc.edu/user-guides/carc-ondemand/ondemand-overview). ==On CARC Discovery, the key gotcha is: do *not* Remote-SSH into the login node.==  [CARC Discovery Documentation -> Logging in](https://www.carc.usc.edu/user-guides/hpc-systems/discovery/getting-started-discovery#logging-in) explicitly says VSCode Remote SSH is blocked because it spawns too many processes on *login nodes*:

> Accessing the cluster via the Remote SSH extension of VSCode is blocked. ==This extension spawns too many processes on the login nodes, exceeding the process limit==. Additionally, the processes started by Remote SSH are not properly killed after the user logs out of the application, which may lead to an **account hold** preventing the user from accessing the cluster, even from the terminal. It is recommended to use the SSH-FS extension in VSCode instead. These measures are set in place to prevent the login nodes, as shared resources, from becoming saturated and sluggish.

## 2 Best practice: use Cursor/VSCode Remote SSH *only* to a compute node you’ve allocated (via Slurm)
Goal: keep the VSCode/Cursor server + your terminals running **on the compute node**, inside an interactive allocation.
### 2.1 Allocate an interactive compute node (from a terminal on the login node)
```bash
# 1. SSH to login node
ssh <user>@discovery.usc.edu
# 2. Allocate a compute node (not requesting a specific gpu - you might get whatever is available)
salloc -p gpu -t 01:00:00 --gres=gpu:1 --cpus-per-task=8 --mem=32G
# 3. Enter the allocated node shell (if salloc didn’t drop you in):
srun --pty bash -l
# 4.  Get the exact node name assigned to you (use this for HostName):
hostname -f
```

To find the current compute node available on carc, run:
```bash
noderes -c -g   # configured GPU resources
noderes -f -g   # currently available GPUs
```

To request a specific gpu, run, for example, for a v100:
```bash
salloc -p gpu -t 01:00:00 --gres=gpu:v100:1 --cpus-per-task=8 --mem=32G
```

> `gres` stands for *generic resource* in [Slurm](https://slurm.schedmd.com/). You could also use `--gpus-per-task=<gpu_type>:<number>` to align with the [CARC documentation](https://www.carc.usc.edu/user-guides/advanced-hpc-programming/gpu-programming).


### 2.2 connect Cursor/VSCode Remote SSH to that compute node (via ProxyJump)
In your local `~/.ssh/config`, set:
```bash
Host CARC_LOGIN
    HostName discovery.usc.edu
    User <user> # <-- replace with your user name
    Port 22

Host CARC_COMPUTE
	HostName d14-07.hpc.usc.edu # <-- replace with the node you actually got
	User <your_username> # <-- replace with your user name
	ProxyJump CARC_LOGIN
	LocalForward 8000 127.0.0.1:8000
	ExitOnForwardFailure yes
	ServerAliveInterval 30
	ServerAliveCountMax 4
```

The VSCode/Cursor Remote SSH extension will then use the ProxyJump to connect to the compute node.

Then, in Cursor/VSCode:
- Remote SSH → connect to `CARC_COMPUTE`
- Do your editing/debugging in that window.
- Run heavy code only in terminals attached to the compute node (inside the allocation).

Notes:
- The compute node `HostName` must match your **current** allocation. That is, each time you run `salloc` in the *login node*, you need to update the `HostName` in `~/.ssh/config -> Host CARC_COMPUTE` 
- When the Slurm job ends (either due to time limit reached or `scancel` being invoked in *login node*), the Remote SSH session will die (expected).

## 3 Housekeeping in *compute node*

**Slurm-level** (what you requested vs what you’re using)
1\. See your job + node:
```bash
squeue -u $USER
echo $SLURM_JOBID
scontrol show job $SLURM_JOBID
```
2\. Live-ish usage (if enabled on the cluster):
```bash
sstat -j ${SLURM_JOBID}.batch --format=JobID,MaxRSS,AveRSS,MaxVMSize,AveCPU
```
3\. Post-run accounting summary:
```bash
sacct -j $SLURM_JOBID --format=JobID,Elapsed,AllocCPUS,ReqMem,MaxRSS,TotalCPU,State
```

**Resource usage: process count, CPU/GPU/disk usage**
1\. How many processes you’re spawning:
```bash
ps -u $USER | wc -l
```
2\. Find VSCode/Cursor server processes:
```bash
pgrep -a -u $USER -f "vscode-server|\.vscode-server|cursor|remote"
```
3\. Top offenders:
```bash
ps -u $USER -o pid,ppid,%cpu,%mem,cmd --sort=-%cpu | head -n 25
top -u $USER        # or: htop (if available)
```
4\. GPU utilization + processes:
```bash
nvidia-smi
```
5\. VSCode server disk usage footprint:
```
du -sh ~/.vscode-server 2>/dev/null || true
du -sh ~/.vscode-server-insiders 2>/dev/null || true
```

## 4 Release the resources cleanly (and clean up stray VSCode servers)

To release Slurm resources 
- If you’re inside the interactive shell: just `exit` until you leave the allocation.
- Or cancel explicitly from anywhere: `scancel $SLURM_JOBID`

<!-- 
2\. Stop VSCode/Cursor remote server processes (compute node or login node)
- Option 1 (quick kill by pattern):
```bash
pkill -u $USER -f "vscode-server|\.vscode-server|cursor|remote" || true
```
- Option 2 (use your cleanup script):
```bash
./cleanup_vscode.sh
```

3\. (Optional, last resort) wipe the remote server install so it re-installs fresh next time
Only do this if the server is corrupted / repeatedly respawning:
```bash
rm -rf ~/.vscode-server
```

4\. Close tunnels
- Close the Remote SSH window in Cursor/VSCode (this drops the SSH session + forwards).
- If you made a manual `ssh -L ...` tunnel in a terminal, close that terminal or Ctrl-C it. -->
