# CARC Workflow Notes

This repo is a small working set of notes and scripts for using USC CARC with a local-editor workflow, especially when you want to develop locally, allocate a GPU node with Slurm, and then work on that compute node through VSCode or Cursor Remote SSH.

## What Is In This Repo

- [consolidated.md](/Users/KyleWang/repos/carc_usage/consolidated.md): the main guide. It covers CARC access prerequisites, VPN, SSH key setup, Discovery vs. Endeavour, Slurm allocations, Conda setup on a compute node, and the Remote-SSH workflow.
- [prepare_conda_env.sh](/Users/KyleWang/repos/carc_usage/prepare_conda_env.sh): a bootstrap script that recreates a `carc_basic` Conda environment and installs a JAX-oriented stack, including Flax NNX, PyTorch, Brax, Diffrax, Orbax, and related packages.
- [train_tiny_jax_nn.py](/Users/KyleWang/repos/carc_usage/train_tiny_jax_nn.py): a minimal MNIST classifier written with JAX and Flax NNX, trained with plain SGD. This is meant as a quick sanity check after the environment is built.

## Recommended Order

1. Read and follow [consolidated.md](/Users/KyleWang/repos/carc_usage/consolidated.md).
2. On a CARC compute node, run `bash prepare_conda_env.sh`.
3. Activate the environment with `conda activate carc_basic`.
4. Verify the setup with `python train_tiny_jax_nn.py`.

## Notes

- The guide assumes you already have CARC access through your PI or project.
- The intended pattern is: connect to a CARC login node, request a compute node with Slurm, and only then attach VSCode/Cursor Remote SSH to that compute node.
- Do not attach Remote SSH directly to a login node.
- The environment bootstrap is opinionated and recreates the target Conda environment from scratch.

## Quick Example

```bash
ssh <your_usc_username>@endeavour.usc.edu
myaccount
salloc -A <your_endeavour_account> -p <your_endeavour_partition> -t 01:00:00 --gres=gpu:1 --cpus-per-task=8 --mem=32G
cd <where-you-cloned-this-repo>
bash prepare_conda_env.sh
conda activate carc_basic
python train_tiny_jax_nn.py
```
