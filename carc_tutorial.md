
# USC Carc Computing Guide

A previous guide written by Sungje can be found [here](https://docs.google.com/document/d/1b6jEppO-_wirL7g4uxfjG9moCHU8IWSpovGV60Wytx4/edit?tab=t.0).


## 1. Connect to [Discovery Cluster](https://www.carc.usc.edu/user-guides/hpc-systems/discovery/getting-started-discovery) using SSH

1\. First make sure you are connected to [USC VPN](https://www.carc.usc.edu/user-guides/quick-start-guides/anyconnect-vpn-setup). Follow the previous link if you encounter `Could not resolve hostname discovery.usc.edu: nodename nor servname provided, or not known`.

2\. Then run the following command to connect to the Discovery cluster:

Run in: **Local terminal**

```bash
ssh <your_usc_username>@discovery.usc.edu
```

You should see your terminal output something like

```terminal
Announcement:
From November 1, 2025, /project will be read-only. No new data can be written 
there. Data migration from /project to new /project2 can continue while it's 
read-only. For full details, please see: https://www.carc.usc.edu/latest-news
Last login: Sun Oct 12 11:14:39 2025 from 10.49.145.213

[<your-usc-uname>@discovery1 ~]$ 

```

This means you are in a Discovery *login node*, which is made evident by the `@discovery1 ~ █` suffix.


On discovery:
```
cat ~/.ssh/id_ed22519.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
chmod 700 ~/.ssh
```

## 2. Set up password-less SSH to Discovery (reproducible flow)

Run this section on your **local machine terminal** (not on `discovery1`).

1\. Create an SSH key (skip only if you already have one on your local machine):

Run in: **Local terminal**

```bash
ssh-keygen -t ed25519 -C "<your_usc_email>" -f ~/.ssh/id_ed25519
```

Press Enter for defaults. You may set a passphrase if you want extra security.

2\. Start `ssh-agent` and load the key:

Run in: **Local terminal**

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
ssh-add -l
```

Expected: one `ED25519` key fingerprint is listed by `ssh-add -l`.

3\. Copy your public key to Discovery:

Run in: **Local terminal**

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub <your_usc_username>@discovery.usc.edu
```

If `ssh-copy-id` is unavailable, use this fallback:

Run in: **Local terminal**

```bash
cat ~/.ssh/id_ed25519.pub | ssh <your_usc_username>@discovery.usc.edu "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

4\. Verify password-less login:

Run in: **Local terminal**

```bash
ssh <your_usc_username>@discovery.usc.edu
```

Expected: you should no longer be prompted for your USC account password (you may still be prompted for your key passphrase if you set one).

5\. (Optional but recommended) Add a local SSH config entry:

```sshconfig
Host discovery
  HostName discovery.usc.edu
  User <your_usc_username>
  IdentityFile ~/.ssh/id_ed25519
  IdentitiesOnly yes
```

Save this in `~/.ssh/config`, then connect with:

Run in: **Local terminal**

```bash
ssh discovery
```

### If it still asks for password

1\. Confirm key is loaded locally:

Run in: **Local terminal**

```bash
ssh-add -l
```

2\. Confirm permissions on Discovery:

Run in: **Local terminal** (this command connects to the login node and runs remote permission fixes)

```bash
ssh <your_usc_username>@discovery.usc.edu "chmod 700 ~/.ssh; chmod 600 ~/.ssh/authorized_keys"
```

3\. Debug exactly which auth method is used:

Run in: **Local terminal**

```bash
ssh -v <your_usc_username>@discovery.usc.edu
```

Look for lines like `Offering public key` and `Authentication succeeded (publickey)`.

## 3. CARC Miscellaneous


First take a quick look at [jupyter_serve.sbatch](./jupyter_serve.sbatch). This submits a slurm job that runs a jupyter server. To submit this job, run on a Discovery login node (`discovery1`, `discovery2`, etc.):

Run in: **Discovery login node**

```bash
sbatch jupyter_discovery.sbatch
```

Then check whether the job has started and examine which compute node the job is allocated with:

Run in: **Discovery login node**

```bash
squeue -u $USER
```

You should see something like

```bash
[<your-usc-uname>@discovery1 ~]$ squeue -u $USER
JOBID      PARTITION     NAME     USER S            T      TIME  NODES  NODELIST(REASON)
1234567     debug        ood/jupy <your-usc-uname>  R      43:16     1  b11-09
```



## [GPU Nodes](https://www.carc.usc.edu/user-guides/advanced-hpc-programming/gpu-programming)

| GPU type | GPU model   | Partitions | Max GPUs / node | CUDA cores | GPU memory (CARC)         | Processing frequency (clock speed) | Approx. market price (USD)*                                                |
| -------: | ----------- | ---------- | --------------- | ---------: | ------------------------- | ---------------------------------- | -------------------------------------------------------------------------- |
|     l40s | NVIDIA L40S | gpu        | 3               |     18 176 | 48 GB GDDR6               | Base: 1,065 MHz; Boost: 2,520 MHz  | $9–10k                                                                     |
|     a100 | NVIDIA A100 | gpu        | 2               |      6 912 | 40 GB or 80 GB HBM2/HBM2e | 40GB PCIe: Base 765; Boost 1,410 MHz. 80GB PCIe: Base 1,065; Boost 1,410 MHz | 40 GB ≈ \$5.2k. 80 GB ≈ \$24.4k                                           |
|      a40 | NVIDIA A40  | gpu, debug | 2               |     10 752 | 48 GB GDDR6               | Base: 1,305 MHz; Boost: 1,740 MHz  | $5.5k                                                                      |
|     v100 | NVIDIA V100 | gpu        | 2               |      5 120 | 32 GB HBM2                | Base: 1,230–1,245 MHz; Boost: 1,380 MHz | $1.4–1.6k                                                               |
|     p100 | NVIDIA P100 | gpu, debug | 2               |      3 584 | 16 GB HBM2                | Base: 1,189 MHz; Boost: 1,328 MHz  | $700                                                                       |

