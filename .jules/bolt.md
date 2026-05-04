## Performance Learnings
- **Iterable Optimization**: Avoid repeated `Iterable.where().fold()` chains. For multiple aggregations on the same dataset, use a single-pass  loop to compute all totals concurrently. This significantly reduces redundant iterations and closure allocations.
- Avoided repeated Iterable.where().fold() chains by using a single-pass loop to improve processing time of long transaction lists.
