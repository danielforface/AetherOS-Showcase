# Security, Isolation & Determinism

## Scope

AetherOS security is currently oriented around kernel integrity, memory safety controls, deterministic benchmarking and hardware isolation—not multi-user tenant security.

## Kernel protections

The documented architecture includes:

- stack smashing protection;
- KASLR-lite heap sliding;
- hardware entropy through RDRAND when available;
- controlled page-table mappings;
- IOMMU/VT-d scaffolding where hardware/firmware allows it.

## Determinism controls

Inference benchmarking benefits from:

- pre-touching memory;
- allocator warmup;
- persistent scratch buffers;
- reduced allocation in the hot path;
- explicit core roles;
- optional compositor suppression;
- model/GGTT residency management;
- serial/cycle telemetry.

## Security non-goals

The current public design should not be described as a hardened multi-user production OS. Ring-0-first execution intentionally trades conventional isolation boundaries for direct control and low-overhead research execution.

## Responsible disclosure

Security issues concerning public repository material should follow [`../SECURITY.md`](../SECURITY.md). Sensitive issues involving the unpublished kernel should not be posted as public issues.
