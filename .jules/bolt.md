# Bolt Journal: Critical Performance Learnings

- Optimized multiple `.where().toList()` passes in list filtering to a single loop pass. This avoids repeating loops and intermediate list allocations, improving list processing performance, especially for long transaction lists.