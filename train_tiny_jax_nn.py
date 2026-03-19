#!/usr/bin/env python3
"""Train a tiny MNIST classifier with JAX + Flax NNX using plain SGD."""

from __future__ import annotations

import argparse
from dataclasses import dataclass

import jax
import jax.numpy as jnp
import numpy as np
from flax import nnx
from torchvision import datasets


NUM_CLASSES = 10
IMAGE_SHAPE = (28, 28)


class TinyMLP(nnx.Module):
    def __init__(self, rngs: nnx.Rngs, hidden_dim: int = 128):
        self.linear1 = nnx.Linear(28 * 28, hidden_dim, rngs=rngs)
        self.linear2 = nnx.Linear(hidden_dim, NUM_CLASSES, rngs=rngs)

    def __call__(self, x: jax.Array) -> jax.Array:
        x = x.reshape((x.shape[0], -1))
        x = self.linear1(x)
        x = jax.nn.relu(x)
        x = self.linear2(x)
        return x


@dataclass
class DatasetSplit:
    images: np.ndarray
    labels: np.ndarray


def load_mnist(data_dir: str) -> tuple[DatasetSplit, DatasetSplit]:
    train_ds = datasets.MNIST(root=data_dir, train=True, download=True)
    test_ds = datasets.MNIST(root=data_dir, train=False, download=True)

    def convert(split: datasets.MNIST) -> DatasetSplit:
        images = split.data.numpy().astype(np.float32) / 255.0
        labels = split.targets.numpy().astype(np.int32)
        return DatasetSplit(images=images, labels=labels)

    return convert(train_ds), convert(test_ds)


def iter_batches(
    split: DatasetSplit,
    batch_size: int,
    *,
    shuffle: bool,
    rng: np.random.Generator,
):
    indices = np.arange(split.images.shape[0])
    if shuffle:
        rng.shuffle(indices)

    for start in range(0, indices.shape[0], batch_size):
        batch_idx = indices[start : start + batch_size]
        images = jnp.asarray(split.images[batch_idx])
        labels = jnp.asarray(split.labels[batch_idx])
        yield images, labels


def cross_entropy_loss(logits: jax.Array, labels: jax.Array) -> jax.Array:
    one_hot = jax.nn.one_hot(labels, NUM_CLASSES)
    log_probs = jax.nn.log_softmax(logits)
    return -jnp.mean(jnp.sum(one_hot * log_probs, axis=-1))


def batch_accuracy(logits: jax.Array, labels: jax.Array) -> jax.Array:
    predictions = jnp.argmax(logits, axis=-1)
    return jnp.mean(predictions == labels)


def evaluate(model: TinyMLP, split: DatasetSplit, batch_size: int) -> tuple[float, float]:
    total_loss = 0.0
    total_acc = 0.0
    total_examples = 0
    rng = np.random.default_rng(0)

    for images, labels in iter_batches(split, batch_size, shuffle=False, rng=rng):
        logits = model(images)
        loss = cross_entropy_loss(logits, labels)
        acc = batch_accuracy(logits, labels)
        batch_examples = int(labels.shape[0])

        total_loss += float(loss) * batch_examples
        total_acc += float(acc) * batch_examples
        total_examples += batch_examples

    return total_loss / total_examples, total_acc / total_examples


@nnx.jit
def train_step(model: TinyMLP, images: jax.Array, labels: jax.Array, lr: float):
    def loss_fn(m: TinyMLP):
        logits = m(images)
        loss = cross_entropy_loss(logits, labels)
        acc = batch_accuracy(logits, labels)
        return loss, acc

    grad_fn = nnx.value_and_grad(loss_fn, has_aux=True)
    (loss, acc), grads = grad_fn(model)
    nnx.update(model, jax.tree.map(lambda p, g: p - lr * g, nnx.state(model), grads))
    return loss, acc


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", default="./data", help="Where MNIST will be downloaded.")
    parser.add_argument("--batch-size", type=int, default=256, help="Training batch size.")
    parser.add_argument("--epochs", type=int, default=5, help="Number of SGD passes over MNIST.")
    parser.add_argument("--lr", type=float, default=0.1, help="SGD learning rate.")
    parser.add_argument("--hidden-dim", type=int, default=128, help="Hidden width for the MLP.")
    parser.add_argument("--seed", type=int, default=0, help="Random seed.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    np_rng = np.random.default_rng(args.seed)
    model = TinyMLP(nnx.Rngs(args.seed), hidden_dim=args.hidden_dim)
    train_split, test_split = load_mnist(args.data_dir)

    for epoch in range(1, args.epochs + 1):
        epoch_loss = 0.0
        epoch_acc = 0.0
        seen_examples = 0

        for images, labels in iter_batches(
            train_split,
            args.batch_size,
            shuffle=True,
            rng=np_rng,
        ):
            loss, acc = train_step(model, images, labels, args.lr)
            batch_examples = int(labels.shape[0])
            epoch_loss += float(loss) * batch_examples
            epoch_acc += float(acc) * batch_examples
            seen_examples += batch_examples

        train_loss = epoch_loss / seen_examples
        train_acc = epoch_acc / seen_examples
        test_loss, test_acc = evaluate(model, test_split, args.batch_size)
        print(
            f"epoch={epoch:02d} "
            f"train_loss={train_loss:.4f} train_acc={train_acc:.4f} "
            f"test_loss={test_loss:.4f} test_acc={test_acc:.4f}"
        )


if __name__ == "__main__":
    main()
