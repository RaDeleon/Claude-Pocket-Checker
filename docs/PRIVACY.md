# Privacy and access

This experimental tool processes conversation text locally to estimate visible text size. It does not save chat bodies, credentials, attachment contents or raw drafts, and sends no usage report to a separate service.

macOS Accessibility permission is broad; inspect the source before granting it. This app reads only the official Claude bundle and does not type, click, install event taps or intercept requests. Account labels are local preferences. The numeric JSON ledger uses hashed chat IDs and separate scope bindings, with mode 0600 under a mode 0700 folder. It is not a cloud database or administrator report.

Draft text is transient. A local heuristic produces model/effort hints, with user override and hypothetical API scenarios. No draft is sent to a model, stored in the ledger or included in the structural probe output. There is no native browser, credential handling or API key.

“Local” does not mean anonymous: identifiers, timestamps and your labels can still be sensitive. Do not upload ledgers or exports in public issues. Removing an app/extension and removing its data are separate operations; follow the README. There is no central deletion endpoint because the project operates no telemetry service.
