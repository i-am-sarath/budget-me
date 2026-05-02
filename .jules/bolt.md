Refactored repeated Iterable.where().fold() chains into a single pass to save unnecessary loop passes. This avoids O(k * N) time complexity, saving cycles.
