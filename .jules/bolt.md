## Critical Performance Learnings

- Always cache `DateFormat` instances outside of loops. `DateFormat` instantiation and pattern parsing are expensive operations. Calling `DateFormat('pattern')` repeatedly inside list iterations or `build()` methods (e.g., when grouping transactions) causes measurable performance bottlenecks and unneeded object creation. Create a single `final formatter = DateFormat('pattern');` before the loop and reuse it.
