# Project Identity

## AetherOS v0.3.0 — Silicon Sovereign

AetherOS is a Rust-first bare-metal AI operating system / unikernel built for deterministic on-device inference on explicitly targeted x86_64 hardware.

### Primary objective

Reduce the distance between transformer execution and physical silicon by controlling boot, memory, storage, CPU SIMD, GPU command submission, synchronization and telemetry inside one tightly integrated system.

### What it is

- a real bootable `#![no_std]` x86_64 kernel;
- an AI-native inference runtime;
- a direct Intel Gen9 compute environment;
- an AVX2/FMA multi-core execution engine;
- a hardware research platform with serial-first observability;
- a controlled environment for numerical and performance experiments.

### What it is not

AetherOS is not presently positioned as:

- a drop-in replacement for Linux, Windows or macOS;
- a broad hardware compatibility project;
- a POSIX compatibility layer;
- a multi-user operating environment;
- a conventional application ecosystem;
- a claim that every documented experiment is production-promoted.

## Core principles

### Direct execution
The system programs the hardware it depends on instead of assuming a host operating system and user-mode runtime will do so.

### Determinism
AetherOS attempts to reduce scheduler noise, allocation noise, avoidable copies, cache invalidations and residency churn in the inference hot path.

### Observability
RDTSC cycle measurements, serial logs, GPU fences, exactness counters and subsystem state are treated as first-class engineering outputs.

### Qualification before promotion
Performance alone does not promote a kernel. Candidates must satisfy correctness and fault/recovery constraints.

### Narrow hardware focus
The current verified platform is intentionally specific: Intel Core i3-10110U + Intel UHD 620 / Comet Lake GT2.

## Naming history

- **Infinite Horizon** — earlier public identity associated with kernel v0.2.1 and the first end-to-end hardware inference proof.
- **Silicon Sovereign** — current documented identity associated with kernel v0.3.0 and the later Gen9 multi-walker / residency / AVX2 optimization generation.
