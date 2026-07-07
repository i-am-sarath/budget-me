Replaced chained .where() list operations with a single-pass for loop to reduce O(N) passes and intermediate allocations.
