## Security Findings
- Fixed missing transaction input validation in `lib/features/transactions/widgets/manual_entry_sheet.dart`. Enforced amounts to be strictly greater than zero to prevent negative balance exploits.
