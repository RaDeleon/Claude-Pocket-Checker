# Validation and evidence

## Public preview — 0.2.2

- **24 offline tests pass** locally on 2026-11-15.
- Swift XCTest verifies pricing, unknown models, account-label matching, scope rejection, fresh-chat and hydration tracking, replay, retries, persistence fields and local advisor rules.
- The generalized public app compiles as an arm64 binary with a separate bundle/data identity; an isolated copy passes strict ad-hoc signature verification.
- CI repeats source tests and native compilation/signature checks on macOS. CI status is the live badge, not an assumed pass.

## Predecessor installed-build observations

A regular Personal Desktop Chat captured two new responses; the numeric ledger retained exactly two records through a full companion process restart. The owner confirmed normal physical typing and draft advice with native Computer Use off. Separate account-label and conflict cases have synthetic fixture coverage.

These observations concern the predecessor identity before public branding/default generalization. They are not a fresh live installation of this publication checkout and do not establish broad team or platform acceptance. No private conversations, account IDs, raw ledgers or native activity logs are published as evidence.

## Still manual

- Live public-identity installation and Work-account switching.
- Long/virtualized histories, voice, interrupted replies and very fast retries.
- Clean-Mac setup, broader team deployment, Intel runtime compatibility and Developer ID/notarized distribution. Both architecture slices are cross-compiled and verified; that is not a live Intel acceptance pass.
- Manual keyboard reliability alongside other Accessibility/input tools.

## Measurement limits

Visible-text estimates are not provider-reported tokenizer counts. Cache, hidden context, files and internal calls are incomplete or unavailable. API-equivalent dollars and model scenarios do not measure exact subscription consumption or prove savings. Advisory rules do not guarantee equal answer quality. See [ACCOUNTING](ACCOUNTING.md) and [PRIVACY](PRIVACY.md).

## Prebuilt distribution checks — 0.2.2

- All 24 offline tests pass locally on 2026-11-15.
- Optimized universal app includes `arm64` and `x86_64`, each targeting macOS 14.0; linked dynamic libraries are system libraries only.
- Exact app bundle contains the executable, Info.plist, project icon, MIT license and resource signature. No user defaults, account labels, ledger, chat export or other local runtime data is packaged.
- Both extracted ZIP and read-only-mounted DMG pass checksum, strict signature and bundle checks. Their executable hashes match. The disk image has an Applications shortcut and installation guide.
- The extracted app's native read-only `--probe` exits successfully; empty public account defaults correctly pause tracking on an unrecognized account. This is not GUI installation or broad account-switch acceptance.
- Signature is ad-hoc, with no TeamIdentifier. Gatekeeper rejects the unnotarized extracted app in the local assessment. No Developer ID certificate was available; first-launch approval is documented, not silently bypassed.
- Existing installed Claude Floating Meter and official Claude Desktop were not replaced, stopped or granted new permissions during packaging.
