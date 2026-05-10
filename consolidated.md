# USC CARC Consolidated Guide

> [!IMPORTANT]
> Before proceeding, make sure that you have told your PI to add you to a CARC project so that your account can access the CARC resources.

## 1. Motivation: why not just use CARC OnDemand?

[CARC OnDemand](https://www.carc.usc.edu/user-guides/carc-ondemand/ondemand-overview) is convenient for browser-based access to tools like Jupyter and VSCode, but the experience is still different from developing on your local machine. In practice, it can feel more limited for editor responsiveness, keyboard shortcuts, extensions, and using AI tools like Cursor/Codex.

Using the VSCode/Cursor (or any code editor that's developed upon the VSCode backbone) [Remote SSH](https://code.visualstudio.com/docs/remote/ssh) extension gives you a more normal development workflow: local editor UI, remote files and terminals, inline linting, interactive debugger, and the ability to work in a familiar IDE with your preferred AI coding assistant.

The important constraint on CARC is that you should **not** Remote-SSH directly into a *login node*. CARC explicitly warns that VSCode Remote SSH is blocked on login nodes because it spawns too many processes and can even lead to account holds. The correct pattern is:

1. SSH to the Discovery/Endeavour **login node** from a terminal.
2. Request a **compute node** with Slurm.
3. Use Cursor/VSCode Remote SSH only to the **allocated compute node**.

> [!NOTE]
> CARC has two relevant clusters here:
> `Discovery` is the general-use shared cluster available to CARC users, while `Endeavour` is the [condo cluster](https://www.carc.usc.edu/user-guides/hpc-systems/endeavour/condo-cluster-program) for research groups that have their own dedicated resources through a CARC allocation (which includes us!).
> The storage layout (directory structure) and module system are largely the same on both clusters, so most of this guide applies to both; the main differences are the login host and the Slurm account/partition you request.
> Official references: [Discovery getting started](https://www.carc.usc.edu/user-guides/hpc-systems/discovery/getting-started-discovery), [Endeavour getting started](https://www.carc.usc.edu/user-guides/hpc-systems/endeavour/getting-started-endeavour).

## 2. Connect to Discovery

> [!IMPORTANT] Connect to USC VPN
> Follow [this url](https://itservices.usc.edu/how-to-connecting-with-cisco-anyconnect-mac-os/) for instructions on connecting to USC VPN using Cisco AnyConnect Client.
> If you are not on USC campus, you should always connect to USC VPN before trying to access CARC. Otherwise CARC will reject your connection the login nodes `@discovery.usc.edu` or `@endeavour.usc.edu`.

First connect to Discovery from your local terminal:

Run in: **Local terminal**

```bash
ssh <your_usc_username>@discovery.usc.edu
```

You should see a prompt similar to:

```terminal
Announcement:
From November 1, 2025, /project will be read-only. No new data can be written
there. Data migration from /project to new /project2 can continue while it's
read-only. For full details, please see: https://www.carc.usc.edu/latest-news
Last login: Sun Oct 12 11:14:39 2025 from 10.49.145.213

[<your-usc-uname>@discovery1 ~]$
```

That means you are on a Discovery **login node**, such as `discovery1`.

Now, run `exit` to logout from the login node and return to your local terminal.

> [!NOTE] Discovery vs. Endeavour
> This documentation starts with `Discovery` because it is the more generic CARC entry point and the commands are easier to present without project-specific Slurm account names. If you are working on `Endeavour`, the flow is the same but you should log in with `ssh <your_usc_username>@endeavour.usc.edu` and typically request resources with your project account and condo partition, for example `salloc -A <account> -p <partition> ...`.

## 3. Set up password-less SSH to Discovery

> [!NOTE] Why password-less authentication?
> Before setting up the code-editor-side workflow, it is worth making sure your local machine can authenticate to Discovery login node with a ssh key instead of your USC password. In the final Remote-SSH setup, VSCode/Cursor may need to open fresh SSH connections through the Discovery login host in the background. If that hop still depends on interactive password entry, those background connections tend to fail or hang because the editor cannot reliably answer a USC password prompt for the proxy jump. Key-based login removes that friction and makes the later compute-node connection via Remote-SSH possible.

Run this section on your **local machine terminal** unless otherwise noted.

1 Create an SSH key if you do not already have one:

Run in: **Local terminal**

```bash
ssh-keygen -t ed25519 -C "<your_usc_email>" -f ~/.ssh/id_ed25519
```

(Press Enter for the default empty passphrase. You may optionally set a passphrase if you want extra security.) This creates a new [Ed25519](https://ed25519.cr.yp.to/) SSH keypair.

- `-t ed25519` selects the key type, 
- `-C` adds a readable label such as your USC email, 
- `-f ~/.ssh/id_ed25519` chooses where the private and public key files will be written.

2 Start `ssh-agent` and load the key:

Run in: **Local terminal**

```bash
eval "$(ssh-agent -s)"
chmod 600 ~/.ssh/id_ed25519
ssh-add ~/.ssh/id_ed25519
ssh-add -l
```

- `eval "$(ssh-agent -s)"` starts the background agent process in your current shell. 
- `chmod 600 ~/.ssh/id_ed25519` restricts the private key so only your account can read and write it; SSH will ignore the key if it is more broadly accessible. 
- `ssh-add ~/.ssh/id_ed25519` loads your private key into that agent so SSH clients can use it automatically. 
- `ssh-add -l` lists the keys currently loaded, which is a quick sanity check that the agent is holding the key you expect.

Expected: `ssh-add -l` shows one `ED25519` key fingerprint.

3 Copy your public key to Discovery:

Run in: **Local terminal**

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub <your_usc_username>@discovery.usc.edu
```

This appends your local public key to `~/.ssh/authorized_keys` on Discovery so future logins from your machine can authenticate with the matching private key.

If the terminal prompts `Are you sure you want to continue connecting (yes/no/[fingerprint])?`, type `yes` and press Enter.

Then enter your USC password when prompted.

> [!NOTE] If `ssh-copy-id` is unavailable, use the following fallback.
> Run in: **Local terminal**
>
> ```bash
> cat ~/.ssh/id_ed25519.pub | ssh <your_usc_username>@discovery.usc.edu "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
> ```
>
> The fallback does the copying of ssh key manually: it sends your `.pub` key to Discovery, ensures the remote `~/.ssh` directory exists, appends the key to `authorized_keys`, and fixes the file permissions SSH expects.

4 Verify password-less login:

Run in: **Local terminal**

```bash
ssh <your_usc_username>@discovery.usc.edu
```

You should no longer be prompted for your USC account password, though you may still be prompted for your SSH key passphrase if you set one. Moreover, after steps 1-4, logging into the Endeavour login node should be passwordless as well. To test that, exist from the Discovery login node by running `exit` (which returns you to your local terminal) and try:

```bash
ssh <your_usc_username>@endeavour.usc.edu
```

> [!NOTE] If it still asks for your password
> 1 Confirm the key is loaded locally:
>
> ```bash
> ssh-add -l
> ```
>
> 2 Confirm permissions on Discovery:
>
> ```bash
> ssh <your_usc_username>@discovery.usc.edu "chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys"
> ```
>
> 3 Debug the SSH authentication flow:
>
> ```bash
> ssh -v <your_usc_username>@discovery.usc.edu
> ```
>
> Look for lines like `Offering public key` and `Authentication succeeded (publickey)`.

## 4. Understanding login node, compute node, and the CARC clusters

> [!NOTE] Discovery vs. Endeavour
> If your research group has an active **Endeavour** [condo allocation](https://www.carc.usc.edu/user-guides/hpc-systems/endeavour/condo-cluster-program), that should usually be your default path for GPU work rather than the shared Discovery queue. Discovery is still a useful fallback, but the examples below show the Endeavour-first workflow.

The Discovery/Endeavour **login node** is for lightweight tasks like logging in, editing configs, submitting jobs, and checking queue state. It is **not** where you should run heavy compute or attach Cursor/VSCode Remote SSH.

The **compute node** is where your real work should happen. You get a compute node by making a Slurm allocation, typically with `salloc`. Once allocated, you can run code there and safely point Cursor/VSCode Remote SSH at that node.

The SSH key you copied earlier should usually also work for the Endeavour login host, because CARC uses the same account and home-directory-level SSH setup across these clusters. In other words, after `ssh-copy-id` to Discovery, you should also try:

Run in: **Local terminal**

```bash
ssh <your_usc_username>@endeavour.usc.edu
```

If that works without asking for your USC password, you are ready to use the Endeavour login node as the jump host for the rest of this workflow. Otherwise you should revisit §3. steps 1-4 and explicitly replace all occurrences of `discovery.usc.edu` with `endeavour.usc.edu` in the commands and setup password-less authentication again on Endeavour cluster.

## 5. Allocate a compute node with Slurm

### 5.1 Compute node allocation

Before allocating a node, confirm which Endeavour account and partition CARC has granted to your project. In a public repo, do **not** publish the real Slurm account name or condo partition name for security. Instead, discover them at runtime from `myaccount` and substitute placeholders like `<your_endeavour_account>` and `<your_endeavour_partition>` in the examples below.

Run in: **Endeavour login node**

```bash
myaccount
```

Sanitized example output:

```terminal
[<your_usc_username>@endeavour2 ~]$ myaccount
-----------------------------------------------------------------
Cluster accounts
-----------------------------------------------------------------
User       Account                    Cluster    Default                    QOS
---------- -------------------------- ---------- -------------------------- -----------
<your_usc_username>   <your_endeavour_account>     condo      <your_endeavour_account>     normal
<your_usc_username>   <secondary_account>          condo      <your_endeavour_account>     normal

-----------------------------------------------------------------
Cluster account service units (SUs)
-----------------------------------------------------------------
Account                    Limit           Usage           Remaining
-------------------------- --------------- --------------- ---------------
<your_endeavour_account>   n/a             <current_usage> n/a
<secondary_account>        n/a             <current_usage> n/a

-----------------------------------------------------------------
Allowed cluster partitions
-----------------------------------------------------------------
Partition                  Allowed accounts
-------------------------- --------------------------------------------------
<specialized_partition>    <other_group_account>,<your_endeavour_account>,<secondary_account>,hpcroot
<your_endeavour_partition> <your_endeavour_account>,<secondary_account>,hpcroot
shared                     ALL
```

In that output, the values you usually need for `salloc` are the Endeavour account name and the matching partition name that your account is allowed to use.

Your output should show the account and partition your lab should use on Endeavour. If your group expects access to a particular condo partition or GPU tier and it does not appear in `myaccount`, open a CARC help ticket and include the project name, allocation dates, and the account information shown in the portal.

Then allocate from the Endeavour login node:

```bash
# Discovery fallback example kept for reference:
# ssh <your_usc_username>@discovery.usc.edu
# salloc -p gpu -t 01:00:00 --gres=gpu:1 --cpus-per-task=8 --mem=32G

# 1. SSH to the Endeavour login node
ssh <your_usc_username>@endeavour.usc.edu

# 2. Confirm your allowed accounts and partitions
myaccount

# 3. Allocate a compute node from the project partition
salloc -A <your_endeavour_account> -p <your_endeavour_partition> -t 01:00:00 --gres=gpu:1 --cpus-per-task=8 --mem=32G

# 4. Get the exact node name assigned to you
hostname -f
```

Replace `<your_endeavour_account>` and `<your_endeavour_partition>` with values from `myaccount`. That keeps the guide reproducible without hardcoding lab-internal identifiers.

To inspect available GPU resources:

```bash
noderes -c -g   # configured GPU resources
noderes -f -g   # currently available GPUs
```

To request a specific GPU type, for example a `h200`:

```bash
salloc -A <your_endeavour_account> -p <your_endeavour_partition> -t 01:00:00 --gres=gpu:h200:1 --cpus-per-task=8 --mem=32G
```

`gres` stands for *generic resource* in Slurm. You may also see CARC documentation using flags such as `--gpus-per-task=<gpu_type>:<number>`.

### 5.2 Create a Python environment on the compute node

Before moving on to Remote SSH, it is a good idea to create your Python environment from a GPU-capable compute node rather than on the login node. This repo includes [prepare_conda_env.sh](/Users/KyleWang/repos/carc_usage/prepare_conda_env.sh), which creates a sample `carc_basic` environment with common scientific packages including JAX and PyTorch.

Run in: **Endeavour compute node** (after you have allocated a compute node with `salloc`)

```bash
cd <where-you-cloned-this-repo>
bash prepare_conda_env.sh
```

Then to test the environment, run:

```bash
conda activate carc_basic
python train_tiny_jax_nn.py  # trains a tiny MLP for classification on the MNIST dataset
exit  # exit the compute node to relinquish the allocation
```

If the command `conda` is not found, checkout the [Troubleshooting Conda on a CARC compute node](#7-troubleshooting-conda-on-a-carc-compute-node) section.

> [!TIP] Recommended development pattern:
>
> 1. Request a compute node with GPU access.
> 2. Run `bash prepare_conda_env.sh` once to build or rebuild the environment; or modify the scripts to create a conda environment that meets your needs.
> 3. Reuse that same environment on later compute-node sessions.
> 4. Activate the environment on the compute node before launching experiments or notebooks.

> [!NOTE]
> At this point, you can already use the compute node entirely from the command line if that is all you need. A practical workflow is:
>
> 1. Implement and maintain your repository locally, where you only run small debug tests that need little compute.
> 2. When you need larger experiments, use [rsync](https://linux.die.net/man/1/rsync) or `git` to sync the repository to CARC.
> 3. Activate the environment on the compute node and run the compute-intensive jobs there.
>
> This is often the best option when your edit-run cycle is coarse-grained and you do not need an interactive remote editor attached to the node.

> [!CAUTION] Node usage etiquette
> Do not hold a GPU-equipped compute node just to edit files, read documentation, or stay idle for long periods. If you are not actively using the allocated resources, exit the compute node and release the allocation so those GPUs return to the queue. Reserve the Remote-SSH workflow below for sessions where you genuinely need a tight loop of editing code -> running GPU-backed tests -> inspecting results -> editing code again -> ... .

## 6. Connect Cursor/VSCode to the compute node

This section is for the more interactive development workflow: edit a bit, run a GPU-involved test, inspect the result, then edit again from the same IDE session. Use this when the command-line-only pattern above becomes too slow or awkward for debugging. If your work is mostly "write locally, then launch a longer run remotely," the simpler CLI workflow from §5.2 is usually the better choice.

> [!TIP] Quickly navigating to the `~/.ssh/config` file
> It is recommended to install the Remote-SSH extension in VSCode or Cursor. Then use "cmd + shift + p" (Mac) or "ctrl + shift + p" (Windows) to open the Command Palette in VSCode / Cursor and type "Remote-SSH: Open SSH Configuration File".

1 Repeat the compute-node allocation steps if you are not already on a compute node:

```
ssh <your_usc_username>@endeavour.usc.edu
myaccount
salloc -A <your_endeavour_account> -p <your_endeavour_partition> -t 01:00:00 --gres=gpu:1 --cpus-per-task=8 --mem=32G
hostname -f
```

2 Once you know the compute node hostname from `hostname -f`, configure your local `~/.ssh/config` like this:

```~/.ssh/config
Host Discovery
    HostName discovery.usc.edu
    User <your_usc_username>
    IdentityFile ~/.ssh/id_ed25519
    Port 22

Host Endeavour
    HostName endeavour.usc.edu
    User <your_usc_username>
    IdentityFile ~/.ssh/id_ed25519
    Port 22

Host DiscoveryCompute
    HostName d12-34       # optionally append .hpc.usc.edu if remote ssh fails
    User <your_usc_username>
    ProxyJump Discovery
    LocalForward 8000 127.0.0.1:8000
    ExitOnForwardFailure yes
    ServerAliveInterval 30
    ServerAliveCountMax 4

Host EndeavourCompute
    HostName d12-34       # optionally append .hpc.usc.edu if remote ssh fails
    User <your_usc_username>
    ProxyJump Endeavour
    LocalForward 8000 127.0.0.1:8000
    ExitOnForwardFailure yes
    ServerAliveInterval 30
    ServerAliveCountMax 4
```

- Replace the placeholder HostName `d12-34` with the compute node you actually received from Slurm.
- Replace the placeholder User `<your_usc_username>` with your actual USC username.

3 Then in Cursor or VSCode:

1. Enter in command palette (cmd + shift + p on Mac, ctrl + shift + p on Windows) and type "Remote-SSH: Connect to Host".
2. Connect to `EndeavourCompute`.
3. Edit and run code from that remote window.
4. Keep heavy workloads inside terminals attached to the compute node and within your active Slurm allocation.

> [!IMPORTANT]
>
> - The `HostName` for `EndeavourCompute` must match your **current** allocation.
> - Each time you get a new compute node from `salloc`, you need to update that `HostName` entry in `~/.ssh/config`.
> - When the Slurm job ends or you cancel it, the Remote SSH session will terminate.
> - Conversely, if you terminate the Remote SSH session, the Slurm job does **not** terminate automatically. You need to cancel the job by running `exit` from the compute node terminal. Therefore the best practice is to always exit the compute node terminal when you are done with the session.

This concludes the majority of this tutorial. Appended below are some miscellaneous notes for troubleshooting and housekeeping.

## 7. Miscellaneous notes

### 7.1 Troubleshooting Conda on a CARC compute node

This section follows CARC's official guidance in the Discovery and Endeavour getting-started guides plus the software module documentation.

CARC's current Conda guidance is:

```bash
module purge
module load conda
conda init bash
source ~/.bashrc
```

That is the **first-time shell setup**. `module load conda` is needed before `conda init bash`, because CARC provides Conda through the module system. After `conda init bash` updates your `~/.bashrc`, later login shells can usually use `conda` without loading the module again first.

Official references:

- Discovery getting started: [https://www.carc.usc.edu/user-guides/hpc-systems/discovery/getting-started-discovery](https://www.carc.usc.edu/user-guides/hpc-systems/discovery/getting-started-discovery)
- Endeavour getting started: [https://www.carc.usc.edu/user-guides/hpc-systems/endeavour/getting-started-endeavour](https://www.carc.usc.edu/user-guides/hpc-systems/endeavour/getting-started-endeavour)
- Software module system: [https://www.carc.usc.edu/user-guides/hpc-systems/software/software-modules-lmod](https://www.carc.usc.edu/user-guides/hpc-systems/software/software-modules-lmod)

For an interactive session on a **compute node**, the practical pattern is:

```bash
# On the login node, request a compute node first
salloc -A <your_endeavour_account> -p <your_endeavour_partition> -t 01:00:00 --gres=gpu:1 --cpus-per-task=8 --mem=32G
srun --pty bash -l

# On the compute node
module purge
conda activate carc_basic
```

If `conda activate carc_basic` fails with `conda: command not found`, that means your shell has not been initialized yet or you are in a shell that did not read `~/.bashrc`. In that case run:

```bash
module load conda
conda init bash
source ~/.bashrc
conda activate carc_basic
```

To rebuild the environment from this repo on the compute node:

```bash
bash prepare_conda_env.sh
```

That script now removes any existing `carc_basic` environment, recreates it, activates it, and installs the required packages.

For batch jobs, keep the same idea: start from a clean module state, make sure Conda is available in the shell, then activate the environment before running Python.

### 7.2. Monitor jobs and resource usage

On the compute node, these commands are useful for checking the job and understanding what you are consuming.

See your job and node:

```bash
squeue -u $USER
echo $SLURM_JOBID
scontrol show job $SLURM_JOBID
```

Check live-ish resource usage if enabled:

```bash
sstat -j ${SLURM_JOBID}.batch --format=JobID,MaxRSS,AveRSS,MaxVMSize,AveCPU
```

Get a post-run accounting summary:

```bash
sacct -j $SLURM_JOBID --format=JobID,Elapsed,AllocCPUS,ReqMem,MaxRSS,TotalCPU,State
```

Inspect process count and CPU usage:

```bash
ps -u $USER | wc -l
pgrep -a -u $USER -f "vscode-server|\.vscode-server|cursor|remote"
ps -u $USER -o pid,ppid,%cpu,%mem,cmd --sort=-%cpu | head -n 25
top -u $USER
```

Inspect GPU activity:

```bash
nvidia-smi
```

Inspect VSCode server disk usage:

```bash
du -sh ~/.vscode-server 2>/dev/null || true
du -sh ~/.vscode-server-insiders 2>/dev/null || true
```

### 7.3. Release resources cleanly

When you are done:

- If you are inside the interactive shell, use `exit` until you leave the allocation.
- Or cancel the job explicitly with `scancel $SLURM_JOBID`.
- Close the Remote SSH window in Cursor or VSCode once you are done with the session.

### 7.4. Miscellaneous CARC notes

If you want to launch a Jupyter server through Slurm, one pattern is to submit a batch script from the Endeavour login node. For example, `carc_tutorial.md` references `jupyter_serve.sbatch` and uses:

Run in: **Endeavour login node**

```bash
sbatch jupyter_serve.sbatch
```

Then check the allocation with:

Run in: **Endeavour login node**

```bash
squeue -u $USER
```

You may also want a quick reference for available CARC GPU types:


| GPU type | GPU model   | Partitions       | Max GPUs / node | CUDA cores | GPU memory (CARC)         | FP32 TFLOPS | FP64 TFLOPS | Approx. market price (USD)* |
| -------- | ----------- | ---------------- | --------------- | ---------- | ------------------------- | ----------- | ----------- | --------------------------- |
| h200     | NVIDIA H200 | project-specific | unknown         | not listed | 141 GB HBM3e              | 67          | 34          | ~$25k+                      |
| l40s     | NVIDIA L40S | gpu              | 3               | 18,176     | 48 GB GDDR6               | 91.6        | not listed  | $9-10k                      |
| a100     | NVIDIA A100 | gpu              | 2               | 6,912      | 40 GB or 80 GB HBM2/HBM2e | 19.5        | 9.7         | $5.2k to $24.4k             |
| a40      | NVIDIA A40  | gpu, debug       | 2               | 10,752     | 48 GB GDDR6               | 37.4        | not listed  | $5.5k                       |
| v100     | NVIDIA V100 | gpu              | 2               | 5,120      | 32 GB HBM2                | 15.7        | 7.8         | $1.4k to $1.6k              |
| p100     | NVIDIA P100 | gpu, debug       | 2               | 3,584      | 16 GB HBM2                | 9.3         | 4.7         | $700                        |


## 8. Runnig non-interactive jobs on CARC in batch

The totorial above revolved around using CARC in an interactive mode via `salloc`. However, there are cases where you want to run a non-interactive job on CARC. Use `salloc` when you want an **interactive** allocation and plan to run commands yourself on the compute node. Use `sbatch` when you want Slurm to run a **batch script** for you once resources become available.

The resource requests are similar in both cases: account, partition, time limit, CPUs, memory, and GPUs. The difference is that with `sbatch` you put those requests at the top of a shell script using `#SBATCH` directives, then submit the script from the login node.

Run in: **Endeavour login node**

```bash
sbatch <your_batch_script>.sbatch
```

Example batch script:

```bash
#!/bin/bash
#SBATCH --account=<your_endeavour_account>
#SBATCH --partition=<your_endeavour_partition>
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=16
#SBATCH --gpus=h200:1
#SBATCH --mem=64G
#SBATCH --time=1-00:00:00

# Optional: submit 4 similar jobs at once. Remove this line if you only want one job.
#SBATCH --array=0-3

set -euo pipefail

echo "Job ID: $SLURM_JOB_ID"
echo "Array Task ID: ${SLURM_ARRAY_TASK_ID:-not_an_array_job}"
echo "Running on host: $(hostname)"

cd <your_project_path>

# Choose one script per array index. This is only needed if you keep --array.
scripts=("example0.py" "example1.py" "example2.py" "example3.py")
python "${scripts[$SLURM_ARRAY_TASK_ID]}"
```

Notes:

- `#SBATCH --array=0-3` creates 4 jobs with array indices `0`, `1`, `2`, and `3`.
- Inside the script, Slurm exposes the current index as `SLURM_ARRAY_TASK_ID`.
- If you only want one job, remove the `--array` line and replace the final `python ...` command with the exact command you want to run.
- Submit with `sbatch train_job.sbatch`, check status with `squeue -u <your_usc_username>`, and inspect accounting data later with `sacct -j <job_id>`.

