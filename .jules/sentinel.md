
## Missing Transaction Input Validation
- Discovered that multiple input sheets (Manual Entry, Subscriptions, Recurring Transactions) failed to explicitly validate that transaction amounts were strictly greater than zero (`> 0`).
- This allowed for negative amounts which could lead to negative balance exploits where an expense acts as an income (or vice-versa).
- Added checks on `double.tryParse` values and form validators across `manual_entry_sheet.dart`, `subscriptions_screen.dart`, and `recurring_screen.dart` to fix this vulnerability.
