
# Filesystems and Repo Symlinks

## 1. Recommendation

According to [CARC storage file systems reference](https://www.carc.usc.edu/user-guides/research-data-management/storage-file-systems.html), for repos that contain large artifacts, submodules, generated files, checkpoints, datasets, build outputs, or many small files, keep the actual repo directory on `/project2`, not `/home1`.

Use `/home1` for small account-level files:

- shell config such as `~/.bashrc`
- SSH config and keys
- small scripts and notes
- lightweight dotfiles

Use `/project2` for most persistent project work:

- large repo checkouts
- shared project code
- Conda environments and package caches, when they are large
- model checkpoints and experiment artifacts that should persist
- datasets and generated outputs associated with a project

Use `/scratch1` for temporary work that can be recreated or deleted.

## 2. Why Not Keep Big Repos in `/home1`

`/home1` has a much smaller per-user quota (100GB) than `/project2` (5TB). A large repo can fill the home quota even when the shared filesystem still has plenty of free space. When that happens, commands like Git may fail with errors such as:

```text
error: could not lock config file .git/config: Disk quota exceeded
```

This can happen during normal Git operations because Git creates lock files before updating config, refs, indexes, and submodule metadata.

Check filesystem capacity with:

```bash
df -h .
```

Check your actual CARC quota with:

```bash
myquota
```

`df -h` reports free space for the whole mounted filesystem. `myquota` reports the limit that matters for your account or project allocation.

## 3. Recommended Layout

Create a user-owned work area under the project allocation:

```bash
mkdir -p /project2/<project_account>/<username>/repos
mkdir -p /project2/<project_account>/<username>/cache
mkdir -p /project2/<project_account>/<username>/data
```

Then put project repos under:

```text
/project2/<project_account>/<username>/repos
```

## 4. Symlink Pattern

It is fine to make `~/repos` a symlink to the `/project2` repo directory. This keeps commands short while ensuring the actual files are stored on `/project2`.

If `/project2/<project_account>/<username>/repos` does not already exist:

```bash
mkdir -p /project2/<project_account>/<username>
mv ~/repos /project2/<project_account>/<username>/repos
ln -s /project2/<project_account>/<username>/repos ~/repos
```

If the target directory already exists, move or copy contents into it intentionally instead of accidentally creating a nested `repos/repos` directory:

```bash
mkdir -p /project2/<project_account>/<username>/repos
rsync -a ~/repos/ /project2/<project_account>/<username>/repos/
mv ~/repos ~/repos.old
ln -s /project2/<project_account>/<username>/repos ~/repos
```

After verifying everything works, remove `~/repos.old` to reclaim `/home1` quota.

## 5. Verify the Symlink

```bash
ls -ld ~/repos
cd ~/repos
pwd
pwd -P
```

Expected result:

```text
pwd    -> /home1/<username>/repos
pwd -P -> /project2/<project_account>/<username>/repos
```

Files created under `~/repos` will count against the `/project2` project quota because the symlink target is on `/project2`.

## 6. Do Not Change `$HOME`

Do not set:

```bash
export HOME=/project2/<project_account>/<username>
```

as a permanent shell setting.

Many tools expect `$HOME` to be the real login home directory. Changing it can confuse SSH, Git, Conda, Jupyter, Slurm jobs, dotfile discovery, and programs that compare `$HOME` with the system account database.

Instead, keep `/home1/<username>` as the real home directory and add conveniences:

```bash
export PROJECT_HOME=/project2/<project_account>/<username>
alias cdp='cd /project2/<project_account>/<username>'
alias cdr='cd /project2/<project_account>/<username>/repos'
```

## 7. Cache Locations

Large package and model caches can also fill `/home1`. Redirect them to `/project2` when needed:

```bash
export XDG_CACHE_HOME=/project2/<project_account>/<username>/cache/xdg
export PIP_CACHE_DIR=/project2/<project_account>/<username>/cache/pip
export CONDA_PKGS_DIRS=/project2/<project_account>/<username>/cache/conda-pkgs
```

For ML workflows, consider redirecting framework-specific caches as well:

```bash
export HF_HOME=/project2/<project_account>/<username>/cache/huggingface
export TORCH_HOME=/project2/<project_account>/<username>/cache/torch
```

## 8. Cautions

- Stop editors, jobs, and Git commands that are actively using `~/repos` before moving it.
- A cross-filesystem `mv` from `/home1` to `/project2` behaves like copy then delete, so it can take time.
- Keep important code pushed to GitHub, GitLab, or another remote. `/project2` is a good working location, but it should not be the only copy of important source code.
- Avoid committing large generated artifacts to Git unless the repo deliberately uses Git LFS or another data-versioning workflow.
