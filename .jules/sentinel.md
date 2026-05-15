# Sentinel Journal

## Security Learnings

- **Input Validation:** Always strictly enforce that parsed transaction amounts are greater than zero (`parsed > 0`). Only relying on `double.tryParse` is insufficient, as it allows negative or zero values, which could lead to negative balance exploits in the system.
