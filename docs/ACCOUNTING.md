# Accounting model

- Text-size estimate: `ceil(UTF-8 bytes / 4)`, not a tokenizer measurement.
- Standard API-equivalent cost: input estimate × bundled input price + output estimate × bundled output price. Rate tables are snapshots; update them when prices change. Unknown models remain unpriced.
- Hidden system/project instructions, attachments, tool payloads, cache behavior, hidden thinking and internal calls are not fully observed. The estimate can overstate or understate actual API usage.
- A subscription's purchase price is not a token allowance. API-equivalent cost does not establish plan consumption, invoice amount or savings.
- Browser quota deltas, when available, are official page readings at two times, account-wide and rounded. They do not isolate an individual prompt.
- Desktop advisor comparisons assume the same visible input and a user-selected hypothetical output size. Neither effort multipliers nor equal answer quality can be inferred. Advice is a local rule-based starting point.

Prices: [Anthropic pricing](https://platform.claude.com/docs/en/about-claude/pricing). Effort semantics: [official effort guide](https://platform.claude.com/docs/en/build-with-claude/effort). Check the bundled rate date in source rather than assuming automatic updates.
