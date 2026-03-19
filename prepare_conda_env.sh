#!/usr/bin/env bash
set -euo pipefail

# -----------------------------------------------------------------------------
# prepare_conda_env.sh — CARC Conda environment bootstrap
#
# Default behavior:
# - Removes any existing Conda environment named `carc_basic`.
# - Creates a fresh Conda environment named `carc_basic` with Python 3.11.
# - Activates that environment and installs the required packages.
#
# Requirements:
# - `conda` must already be available in the shell. On USC CARC, the first-time
#   setup is typically:
#       module purge
#       module load conda
#       conda init bash
#       source ~/.bashrc
#
# Optional env knobs:
#   ENV_NAME=carc_basic  (default carc_basic)
#   PYTHON_VERSION=3.11  (default 3.11)
#   INSTALL_TORCH=1   (default 1)
#   TORCH_CUDA=cu126  (default cu126; use cpu for CPU-only)
#   FLAX_SOURCE=git   (default git; use pypi to install release)
# -----------------------------------------------------------------------------

ENV_NAME="${ENV_NAME:-carc_basic}"
PYTHON_VERSION="${PYTHON_VERSION:-3.11}"

if ! command -v conda >/dev/null 2>&1; then
  echo "Error: conda is not available in this shell." >&2
  echo "On USC CARC, run: module purge && module load conda && conda init bash && source ~/.bashrc" >&2
  exit 1
fi

eval "$(conda shell.bash hook)"

while [[ -n "${CONDA_DEFAULT_ENV:-}" ]]; do
  conda deactivate
done

echo "=== Recreating Conda environment: ${ENV_NAME} ==="
conda env remove -n "${ENV_NAME}" -y >/dev/null 2>&1 || true
conda create -n "${ENV_NAME}" "python=${PYTHON_VERSION}" -y
conda activate "${ENV_NAME}"

echo "=== Python ==="
python -V

echo "=== pip ==="
python -m pip install --upgrade pip setuptools wheel

# Base scientific stack + your deps
echo "=== Installing base deps ==="
python -m pip install -U \
  numpy pandas \
  matplotlib \
  imageio-ffmpeg mediapy ImageIO\
  tqdm rich nbformat ipython ipykernel \
  hydra-core einops \
  wandb \
  jax-dataloader \

# JAX (CUDA 12)
# Note: wheels for cuda extras are linux-only.
echo "=== Installing JAX (cuda12) ==="
python -m pip install -U "jax[cuda12]"

# (Optional) Fix for some CuSolver/CuBLAS-related issues you referenced
echo "=== Applying NVIDIA CuBLAS pin (if needed) ==="
python -m pip install -U nvidia-cublas-cu12==12.9.0.13

# JAX ecosystem
echo "=== Installing JAX ecosystem ==="
python -m pip install -U diffrax orbax-checkpoint

# Brax + mjx (install after JAX)
echo "=== Installing Brax / MJX ==="
python -m pip install -U mujoco-mjx brax

# Flax / NNX
# Choose either latest from GitHub (most recent) or latest PyPI release.
FLAX_SOURCE="${FLAX_SOURCE:-git}"
echo "=== Installing Flax (source: ${FLAX_SOURCE}) ==="
if [[ "${FLAX_SOURCE}" == "git" ]]; then
  python -m pip install -U "git+https://github.com/google/flax.git"
else
  python -m pip install -U flax
fi

# Torch (only needed because you use pytorch backend in jax-dataloader)
INSTALL_TORCH="${INSTALL_TORCH:-1}"
TORCH_CUDA="${TORCH_CUDA:-cu126}"

if [[ "${INSTALL_TORCH}" == "1" ]]; then
  echo "=== Installing Torch (${TORCH_CUDA}) ==="
  if [[ "${TORCH_CUDA}" == "cpu" ]]; then
    python -m pip install -U torch torchvision --index-url https://download.pytorch.org/whl/cpu
  else
    python -m pip install -U torch torchvision --index-url "https://download.pytorch.org/whl/${TORCH_CUDA}"
  fi
else
  echo "=== Skipping Torch install (INSTALL_TORCH=0) ==="
fi

# Trajax + lqrax (after JAX)
echo "=== Installing Trajax / lqrax ==="
python -m pip install -U lqrax
python -m pip install -U "git+https://github.com/google/trajax"

echo "=== pip sanity check ==="
python -m pip check || true

echo "=== Quick verification: JAX backend + Flax NNX ==="
python - <<'PY'
import jax
import flax
from flax import nnx

print("flax:", flax.__version__)
print("nnx module:", nnx.__file__)
print("has nnx.List?", hasattr(nnx, "List"))
print("jax backend:", jax.default_backend())
print("jax devices:", jax.devices())
print("GPU available:", any(d.platform == "gpu" for d in jax.devices()))
PY

echo "=== Done ==="
