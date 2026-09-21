# Reviewer Start Here

This release is intentionally reviewable without reading the entire ROUND18 archive.

## 10-minute path

1. Watch the 104-second public RUN01 cut.
2. Read `CLAIMS_AND_LIMITS.md`.
3. Inspect `evidence/inspectable/BY/`.
4. Inspect `evidence/inspectable/DV/`.
5. Inspect `evidence/inspectable/HAR/`.
6. If a claim still looks unsupported, use `evidence/ENGINEERING_CHRONICLE_V1.md` to locate the broader lineage.

## What would falsify the core claims?

- A BY log/source mismatch would weaken the causal-repair story.
- A DV report/log mismatch would weaken the "local win, no E2E promotion" story.
- A HAR collector/raw-log mismatch would weaken the 7.0775 tok/s qualification.
- A RUN01 serial/video inconsistency would weaken the visual reproduction claim.

## Important status

This is **internally produced evidence**, not independent third-party certification.

The purpose of this release is to make the evidence inspectable enough that an external systems/GPU engineer can challenge it directly.

## AI-assisted development

AetherOS uses AI-assisted engineering workflows. The relevant question for this release is therefore not "was AI used?" but whether the author can explain, reproduce and defend the architecture, source changes, failure mechanisms and physical evidence.

The release is designed to make that test possible.
