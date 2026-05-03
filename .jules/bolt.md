* Replaced multiple `Iterable.where().fold()` chains with a single-pass loop when calculating summary amounts to prevent O(N*X) iteration complexity.
