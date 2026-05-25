# Bolt Journal ⚡

* Avoid using multiple `.where().fold()` chains to calculate various metrics on the same list, as this triggers multiple passes over the list and allocates intermediate Iterables. Instead, combine the logic into a single-pass `for` loop, saving memory and CPU cycles.
