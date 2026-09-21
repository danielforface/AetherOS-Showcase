# HAR verification report

Local build and correctness verified; physical HAR execution and TPS gain are
pending. USB deployment completed2026-09-18T10:45:00Z. The release and exact
HAQ rollback passed flushed readback;249 log/chat/config files matched their
predeployment hashes. Model hash was verified before deployment. Temporary
swap/staging files were removed only after the recoverable backup was verified.
See `evidence/USB_DEPLOY_READBACK.json`. Deployment is not physical execution.

Release:6652208 bytes, SHA256
`EC4C359BFC4D68E866A09520F790955B26C7725D203E262F36662D0A3073EF27`.
Rollback is exact HAQ:
`2E0E0FB0C73844512B97B0C4D26EBD8EFEE297950CE8A754E8C1C9737E194480`.
USB serial03036621022521015400. Model identity is pinned in COMMON and recorded
in `evidence/MODEL_PREDEPLOY.json`.

## Executed checks

- 61 native Rust tests passed. Four new cases specifically cover cold-install
  exclusion from the steady gate, balanced order/all samples, mandatory warm-up
  correctness and immediate stop on a timed-arm transport failure.
- Seven integration checks and22 isolation checks passed. Fourteen runtime
  files are byte-identical to HAQ. Shader builder, physical dispatch, installer,
  threshold, finite-bitwise comparison and warm single/triple entry functions
  are unchanged, except diagnostic tag normalization in the installer.
- All29 EU streams decoded with Intel IGA; shared coefficient analogue compiled
  with Intel IGC. These are local structural/compiler tests, not HAR hardware.
- Locked/offline release build passed in59.20s, with1314 warnings. Unrelated
  warnings remain; this was not a warning-free build.
- All29 PowerShell scripts parsed successfully. The HAR collector rejects the
  real stale HAQ boot marker. All91 adversarial cases passed:90 in the initial
  broad run and the final duplicate-warmup case in a targeted rerun. That last
  fixture initially appended a single character because PowerShell indexed a
  scalar string; its array wrapper was corrected and two actual duplicate rows
  confirmed. Runtime and collector logic were not changed to make it pass.

Test and build transcripts are preserved under `evidence/test_results`.
No independent reviewer was used. Source review and tests were performed locally.

## Acceptance boundaries

HAR changes projection qualification, not the shader or arithmetic order. It
does not lower thresholds, force promotion, ignore failed warm-up values, remove
physical hashes, select only fast samples or count shadows as production. Cost
of warm-up and installation remains visible in request wall/TTFT. Steady-state
dispatch is unchanged; a speed increase depends on fresh physical promotion.

The HAQ log has no numeric invariant/fatal failures but a short request6 makes
the fixed5..8 full128 matrix incomplete. Approximate6.75TPS observations and
paired component gains are documented with denominators in the full audit.
HAR improvement, matched-prompt comparison, answer semantics, final-pixel timing,
long-history behavior and multi-boot stability remain open.
