# AetherOS Documentation Index

This directory is the public technical map of AetherOS v0.3.0 **Silicon Sovereign**.

The documentation is organized from identity and system architecture through silicon-level compute, transformer execution, validation evidence, and development history.

## Reading paths

### Executive / technical overview
1. [Project Identity](00-project-identity.md)
2. [System Architecture](01-architecture.md)
3. [Latest real-hardware state](18-latest-hardware-state.md)
4. [Performance](08-performance.md)
4. [Proof Matrix](09-proof-matrix.md)

### Kernel / systems engineering
1. [Hardware Platform](02-hardware-platform.md)
2. [Boot, Memory & Runtime](03-boot-memory-runtime.md)
3. [I/O & Storage](04-io-storage.md)
4. [Security & Determinism](12-security-determinism.md)
5. [Debug & Telemetry](13-debug-telemetry.md)

### AI / accelerator engineering
1. [Intel Gen9 GPGPU](05-gen9-gpu-compute.md)
2. [CPU AVX2 & AMP](06-cpu-amp.md)
3. [Transformer Runtime](07-transformer-runtime.md)
4. [Validation Methodology](10-validation-methodology.md)
5. [Development Lineage](14-development-lineage.md)

### Public-repository context
1. [Public / Private Boundary](15-public-private-boundary.md)
2. [Glossary](16-glossary.md)
3. [FAQ](17-faq.md)
4. [Complete System Reference](99-complete-system-reference.md)

## Evidence terminology

Throughout the documentation:

- **HW-VERIFIED** means observed on physical target hardware.
- **BIT-EXACT** means an optimized path matched its reference output under the documented qualification test.
- **SHADOW** means measured without publishing the candidate into the production inference path.
- **PRODUCTION-PROMOTED** means the candidate passed the project's promotion gate and became the active execution route.
- **LAB** means exploratory instrumentation or research code that must not be presented as a production feature.

This distinction is critical to reading AetherOS performance history correctly.


## Latest evidence

For post-ROUND18EW evidence, current benchmark semantics, and the ROUND18FB state, read [Latest Real-Hardware State](18-latest-hardware-state.md).
