# Contributing to AetherOS-Showcase

Thank you for taking the time to improve the public AetherOS technical record.

## Repository scope

This repository is primarily documentation and research evidence. The private kernel is not mirrored here.

Useful contributions include:

- documentation corrections;
- architecture review;
- benchmark-methodology critique;
- reproducibility improvements;
- terminology cleanup;
- Mermaid / diagram improvements;
- typo and link fixes;
- questions that reveal ambiguous claims;
- research references relevant to bare-metal inference or Intel Gen9 architecture.

## Evidence discipline

Please do not rewrite evidence labels casually.

In particular, preserve the distinction between:

- implemented;
- hardware-verified;
- bit-exact;
- shadow;
- production-promoted;
- laboratory-only.

A performance number without its execution class can be misleading.

## Pull request expectations

A good PR should state:

1. what changed;
2. why it improves the public technical record;
3. what evidence supports any new factual claim;
4. whether the change affects current-vs-historical wording;
5. whether the change exposes implementation detail that should remain private.

## Sensitive implementation material

Do not submit private kernel source, unpublished compiler/backend code, private logs, credentials, or proprietary third-party material into this public repository.

## Style

- Prefer precise technical language over marketing superlatives.
- Use tables when comparing measured states.
- Include units in every performance number.
- State the hardware target when reporting performance.
- Separate inference from extrapolation.
- Avoid calling a shadow benchmark “current production performance.”

## Security issues

Do not open a public issue for a vulnerability that could affect unpublished/private AetherOS implementation. Follow [`SECURITY.md`](SECURITY.md).
