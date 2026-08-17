# AetherOS Public Brand Guide

## Brand hierarchy

**Primary name:** AetherOS  
**Current technical edition:** Silicon Sovereign  
**Category:** Bare-Metal AI Operating System / Inference Unikernel

## Core positioning

AetherOS should be presented as a **systems-engineering research project that co-designs the operating system and the inference engine**.

The strongest differentiator is not “another LLM runtime.” It is the ownership of the full execution path:

> boot → memory → storage → tensor layout → CPU/GPU execution → synchronization → telemetry → token

## Primary tagline

> **Boot to model. Model to silicon. Evidence before claims.**

## Alternate taglines

- **Bare metal. Native inference. Direct silicon.**
- **An operating system built around inference, not around applications.**
- **From GGUF to Gen9 without the conventional stack.**
- **AI-native systems engineering at Ring 0.**

## One-line description

> AetherOS is a Rust-first x86_64 bare-metal AI system executing LLM inference through direct Intel Gen9 GPGPU and AVX2 multi-core paths.

## Short profile description

> Bare-metal AI unikernel in Rust. Direct Intel Gen9 GPGPU + AVX2 transformer inference, GGUF-native model execution, real-hardware qualification and deterministic telemetry.

## 100-word project description

AetherOS is a Rust-first x86_64 bare-metal AI operating system / inference unikernel. It boots directly on physical Intel hardware, loads GGUF models through its own storage stack, executes transformer operators using hand-controlled AVX2 CPU kernels and direct Intel Gen9 GPGPU command streams, and validates optimized paths against reference execution before promotion. The project treats memory residency, tensor layout, device queues, core topology, GPU synchronization and inference telemetry as one system rather than separate software layers. Current documented work centers on LLaMA-3.2-1B-Instruct. The supplied hardware logs contain a peak clean 128-token result of ~3.411 tokens/s in ROUND18EO, while the newest observed architecture is ROUND18FB; the brand therefore separates peak benchmark from latest architecture.

## Messaging pillars

### 1. Full-stack ownership
AetherOS is interesting because the project controls layers usually delegated to an operating system, framework or vendor runtime.

### 2. Real silicon
Public claims should lead with physical-hardware evidence, not emulator-only architecture diagrams.

### 3. Numerical discipline
Bit-exact qualification and shadow execution are part of the brand. Correctness is not buried behind performance screenshots.

### 4. Systems depth
The story spans boot, memory, PCI, xHCI, NVMe, Gen9, AVX2, GGUF, transformer execution and UI/telemetry.

### 5. Research, not hype
Avoid “world's fastest,” “revolutionary,” “SOTA” or vendor-comparison claims unless a reproducible apples-to-apples benchmark exists.

## Visual direction

### Personality
- technical;
- sovereign;
- precise;
- low-level;
- high-contrast;
- premium research-lab aesthetic.

### Recommended visual motifs
- silicon die / execution-unit grids;
- ring-buffer arcs;
- memory-page lattices;
- transformer flow lines;
- telemetry traces;
- address/register typography;
- restrained dark navy / graphite backgrounds with limited luminous accents.

### Avoid
- generic robot heads;
- glowing humanoid AI faces;
- stock neural-brain imagery;
- excessive cyberpunk clutter;
- performance numbers without units/context;
- fake terminal screenshots.

## Repository social preview

Recommended size: 1280×640.

Text hierarchy:

1. **AetherOS**
2. **SILICON SOVEREIGN**
3. `BARE-METAL AI · INTEL GEN9 · AVX2 · RUST`
4. Optional small footer: `BOOT → MODEL → SILICON`

Do not place 3.41 TPS on the social preview; benchmark values age faster than identity.
