# AetherOS — Complete System Architecture, Identity, Proof & Performance Reference

> **Composite Documentation Edition:** 3.0  
> **Last updated:** 2026-08-17 14:48 (Asia/Jerusalem)  
> **Latest documented kernel:** **v0.3.0**  
> **Latest documented codename:** **Silicon Sovereign**  
> **System class:** Rust-first, `#![no_std]`, x86_64 bare-metal AI unikernel / research operating system  
> **Primary real-hardware target:** Intel Core i3-10110U / Comet Lake GT2 Intel UHD 620 (PCI 8086:9B41) / Intel AX201 CNVi / xHCI / NVMe  
> **Current inference milestone:** LLaMA-3.2-1B-Instruct, Q4_K_M / Q6_K, bare-metal Gen9 GPGPU + AVX2 multi-core AMP, **>3.41 tokens/s documented end-to-end**  
> **Public showcase:** https://github.com/danielforface/AetherOS-Showcase  
> **Documentation policy:** Newer August 2026 evidence supersedes older April/June benchmark values where the two disagree.

---

## 0. Purpose and Source Precedence

This document is the consolidated AetherOS reference intended to preserve **all material architecture detail** while making the **latest documented state** unambiguous.

It is built from three evidence layers:

1. **August 2026 architecture/identity update** — the newest attached technical source. This is authoritative for current kernel identity, Gen9 compute architecture, performance numbers, proof matrix, and the ROUND18EL→ROUND18EW performance lineage.
2. **April 2026 complete identity reference** — the exhaustive 43-section subsystem reference. It remains the richest source for boot, memory, CPU/SMP, interrupts, scheduler, syscall ABI, HAL, filesystems, USB, NVMe, WiFi, networking, DMA, IOMMU, thermal management, graphics/UI, applications, GGUF, transformer internals, quantization, AMP, telemetry, runtime modes, module inventory, and register maps. Where this older reference conflicts with the August source, **the August source wins**.
3. **Public GitHub showcase** — `danielforface/AetherOS-Showcase`, a public architectural proof-of-work repository. It is intentionally not the current private/core engine source and, as of this update, its latest push predates the August performance work.

### 0.1 Canonical supersession rules

- **Kernel identity:** `v0.3.0 / Silicon Sovereign` supersedes `v0.2.1 / Infinite Horizon`.
- **Current performance:** the August ROUND18EL→EW measurements supersede the April/June `~78.36B cycles/token` baseline when describing present performance.
- **GPU status:** the later multi-walker Q4_K production/qualification evidence supersedes early-stage descriptions that only demonstrated basic `GPGPU_WALKER`/magic-sync execution.
- **AMP status:** the later layout uses Core 1 as inference master and Cores 2–3 as neural workers, while Core 0 remains system/UI orchestration.
- **Public repository:** still useful as the official public showcase, but it should be read as an earlier snapshot unless updated to mirror this document.

---

## 1. Canonical Current-State Snapshot — August 17, 2026

### 1.1 Identity

| Field | Current documented state |
|---|---|
| Project | **AetherOS** |
| Kernel | **v0.3.0** |
| Codename | **Silicon Sovereign** |
| Architecture | x86_64 bare metal, Rust `#![no_std]`, single compiled kernel/unikernel image |
| Runtime model | Ring-0-first, direct hardware programming, no Linux/libc dependency in the default inference path |
| Primary goal | Deterministic, observable, zero/low-copy on-device LLM inference with direct CPU + Intel Gen9 iGPU control |
| Primary silicon | Intel Core i3-10110U + UHD 620 / Comet Lake GT2 |
| Model milestone | LLaMA-3.2-1B-Instruct, 1.23B params, Q4_K_M / Q6_K |
| Storage path | Raw USB/xHCI SCSI + FAT/GGUF ingestion; NVMe stack also present |
| Public showcase | `https://github.com/danielforface/AetherOS-Showcase` |

### 1.2 Current documented performance

| Milestone | Architectural focus | Decode / 128 tokens | Per-token forward | Effective bandwidth | E2E generation |
|---|---|---:|---:|---:|---:|
| v1.2 April baseline | Early hybrid dispatch | ~4,700 s | 78.36B cycles | ~0.02 GB/s | ~0.027 TPS |
| ROUND18EL | Single-walker factored | 54.40 s | 827.55M cycles | 1.70 GB/s | 2.35 TPS |
| ROUND18EM | FFN Down 2OW, K=8192 | 47.07 s | 719.17M cycles | 2.05 GB/s | 2.72 TPS |
| ROUND18EO | Zero-flush GGTT caching | 37.52 s | 570.59M cycles | 3.50 GB/s | 3.41 TPS |
| **ROUND18EW — latest documented** | **Zero-spill AVX2 + 2OW QKV** | **39.21 s** | **612.70M cycles** | **3.52 GB/s** | **3.41 TPS E2E verified** |

The August source additionally reports **~218 ms/token prefill** as a headline milestone and measured prompt-prefill paths of **2.70 s for 12 tokens** and **10.47 s for 57 tokens** after LM-head bypassing on intermediate prompt tokens.

### 1.3 Current decode cost distribution

Approximate documented cost per decode token: **612.7M cycles (~306 ms/token in the source's cycle conversion)**.

| Component | Cost | Share |
|---|---:|---:|
| GPU FFN Gate + Up dual-walker | 171.3M cycles | 27.9% |
| CPU LM Head AVX2 multi-core | 165.7M cycles | 27.0% |
| CPU FFN Down AVX2 multi-core | 164.1M cycles | 26.8% |
| GPU attention projections (QKV + output 2OW) | 102.4M cycles | 16.7% |
| Norm / RoPE / Softmax / sampling / overhead | 9.2M cycles | 1.6% |

### 1.4 Current GPU compute architecture

AetherOS directly programs the Intel Gen9 Render Command Streamer and emits GPGPU command streams without Linux, Mesa, OpenCL, Level Zero, CUDA, or a vendor user-mode runtime in the execution path.

Canonical dispatch sequence:

```text
PIPELINE_SELECT
    → STATE_BASE_ADDRESS
    → MEDIA_VFE_STATE
    → MEDIA_INTERFACE_DESCRIPTOR_LOAD
    → GPGPU_WALKER
    → MEDIA_STATE_FLUSH
    → PIPE_CONTROL / fence write
```

Current documented optimized kernels include:

| Role | Dimensions | Kernel strategy | Latency / dispatch | Result |
|---|---|---|---:|---|
| QKV projection | 2048×2048 / 512×2048 | `QKV_TRIPLE_WALKER` | 2.67M cycles/layer | 3.08× vs baseline, bit-exact |
| FFN Gate + Up | 8192×2048 | dual walker with shared input sum | 10.71M cycles/pair | 2.28× vs single-core path, bit-exact |
| FFN Down | 2048×8192 | `2OW_REGION_MULADD_W32`, K=8192 | 9.05M cycles/layer | 2.34×, bit-exact |
| Attention output | 2048×2048 | 2OW packed single-tile | 2.40M cycles/layer | 2.27× vs factored |

The Q4_K 2OW engine uses an AOSOA32-style packed layout and a documented **38-GRF register budget** to avoid spills. Dynamic K handling covers at least K=2048 and K=8192.

### 1.5 GGTT residency and zero-flush policy

The current document locks the GGTT residency threshold at **260,000 pages (~1.01 GiB)**. The model's working tensor set is described as **259 tensors** covering original weights, packed tiles, activations, and KV-cache pages, with **zero pressure flushes during active decode** in the documented qualification run.

### 1.6 CPU SIMD / neural pool

- **Core 0:** BSP, UI/compositor, I/O orchestration; F10 Turbo can pause UI rendering during generation.
- **Core 1:** inference master — graph traversal, tokenizer, embedding and orchestration.
- **Cores 2–3:** neural worker pool, AVX2 kernels, lock-free mailbox dispatch.
- **Q6_K dual-row AVX2:** 8 YMM accumulators (`ymm0..ymm7`) plus remaining YMM registers for masks/scales/input/scratch; designed for zero stack spilling.
- **LM Head:** full `128256 × 2048` projection documented at roughly **164M cycles** across workers.

### 1.7 Transformer runtime

Current LLaMA-3.2-1B configuration:

- 1.23B parameters
- `d_model = 2048`
- 16 transformer layers
- 32 attention heads
- 8 KV heads (GQA)
- FFN dimension 8192
- vocabulary 128,256
- RoPE theta 500,000
- pre-RMSNorm, epsilon `1e-5`
- SwiGLU feed-forward nonlinearity
- prompt prefill path bypasses final RMSNorm + LM Head for tokens `0..N-2`, computing the large vocabulary projection only for the last prompt token.

### 1.8 Hardware-verified proof matrix — current source

| Subsystem / feature | Evidence | Current classification |
|---|---|---|
| Limine boot + memory map | Higher-half boot, heap, tensor zone | HW-VERIFIED |
| xHCI USB mass storage | SanDisk device, SCSI BOT active | HW-VERIFIED |
| GGUF V3 ingestion | 807.69 MB model, CRC32 `0xFBCEC507` | HW-VERIFIED |
| Intel Gen9 iGPU bare metal | RCS ring / ELSP / device 8086:9B41 | HW-VERIFIED |
| 2OW packed SIMD8 Q4_K | K=2048 and K=8192, 38-GRF design | HW-VERIFIED |
| QKV triple walker | `q_exact=1, k_exact=1, v_exact=1` | HW-VERIFIED |
| FFN Gate+Up dual walker | `gate_exact=1, up_exact=1` | HW-VERIFIED |
| FFN Down 2OW | 2048×8192 bit-exact parity | HW-VERIFIED |
| GGTT zero-flush residency | 260,000 pages, no pressure flushes during decode | HW-VERIFIED |
| CPU Q6_K AVX2 dual-row | 10,052 dispatches, no spills, bit-exact parity | HW-VERIFIED |
| Prefill LM-head bypass | documented 43.4–54.5% latency reductions in tested prompts | HW-VERIFIED |
| End-to-end chat | multi-turn 128-token generation at 3.41 TPS | HW-VERIFIED |

### 1.9 Important development-lineage milestones

These milestones are retained because they explain how the current kernel architecture emerged:

- **ROUND18BX:** investigation isolated a cooperative-Q4 SLM reconstruction register-footprint bug: a reconstruction path spilling from `r109` into `r110` overwrote a live ROTATE4 accumulator. The working hypothesis shifted away from SLM/barrier/fence/SFID/latency/scoreboard causes.
- **ROUND18BY:** repaired the reconstruction write footprint and was subsequently reported successful.
- **ROUND18DV:** multi-column Q4 weight-reuse experiment tested `B=1/2/4/8` with seven repetitions and bit-exact comparison against separate B=1 runs. The B=8 candidate was reported at **7.768× acceleration** while remaining shadow-only (`production_publish=0`). Kernel SHA256 for that deployed round was `432487419A3E2C96ED9D06505E62D5472BB3DAD1EFCD03AE6A4C36EF127770B2`.
- **ROUND18EL→18EW:** later architecture moved from single-walker/factored execution into 2OW, zero-flush GGTT residency, multi-walker projection fusion, and zero-spill AVX2 paths; these are the latest performance figures contained in the attached August source.

---

## 2. Public GitHub Showcase — Current Repository Snapshot

**Repository:** https://github.com/danielforface/AetherOS-Showcase  
**Visibility:** Public  
**Default branch:** `main`  
**Repository description:** `Bare-Metal AI Operating System & Kernel (Architectural Showcase)`  
**Latest observed push:** **2026-06-07**  
**Latest observed commit:** `d88285d41a8db87d25d13b297846e7e1cfa4c549` — *Fix formatting in user interface section of README*  

### 2.1 Public repository purpose

The public README explicitly states that the **core engine / kernel and associated verification/compiler backend work are maintained outside the public showcase**, while the public repository serves as architecture documentation, hardware-verification evidence, and proof-of-work material.

### 2.2 Public tree

```text
AetherOS-Showcase/
├── README.md
└── docs/
    ├── 01-hardware-and-boot.md
    ├── 02-drivers-and-io.md
    ├── 03-ai-inference-engine.md
    ├── 04-graphics-and-ui.md
    └── 05-proof-matrix-and-benchmarks.md
```

### 2.3 Public-vs-current performance note

The public `05-proof-matrix-and-benchmarks.md` still describes the earlier end-to-end proof at about **78.36B cycles/token**, 96 GPU dispatches/token, and the basic Gen9 magic-sync execution proof. That public metric is a **historical baseline**, not the latest August architecture state summarized above.

For a public-facing refresh, the showcase should eventually be updated to:

- change the headline identity from **Infinite Horizon / v0.2.1** to the desired public wording for **Silicon Sovereign / v0.3.0**;
- add the ROUND18EL→EW performance progression;
- publish the current 2OW / multi-walker / GGTT-residency architecture at whatever detail level is safe for IP;
- clearly distinguish **production-qualified**, **shadow-qualified**, and **laboratory-only** results;
- replace stale 78.36B-cycles/token “current performance” language with the later verified benchmark matrix.

---

## 3. Current August 2026 Architecture Document — Clean Consolidated Copy

The following section preserves the complete technical content of the latest attached August 2026 architecture source, with only formatting cleanup, removal of non-resolving source-local citation placeholders, and correction of generated Table-of-Contents links. Its technical claims are otherwise retained.

## Table of Contents

1. Philosophy & Design Principles

2. High-Level Architecture

3. Boot, Initialization & Memory Layout

4. Hardware Drivers & Subsystems (PCI, xHCI, NVMe, WiFi)

5. Intel Gen9 GPGPU Compute Engine

6. Neural Compute Pool & CPU SIMD Engine

7. Transformer Runtime & Zero-Copy Execution

8. Graphics, Compositor & UI Subsystems

9. Proof Matrix — Hardware Verification Status

10. Performance Benchmarks & Evolution

11. Register Maps & Low-Level Appendix

## 1. Philosophy & Design Principles

**AetherOS** is a RAM-native, Rust-first bare-metal Unikernel engineered from first principles for deterministic AI inference. It rejects the modern computing paradigm of multi-gigabyte OS images, user/kernel space translation overheads, dynamic driver runtime stacks, and deep framework abstractions (Linux + CUDA/ROCm + PyTorch + Python).  

```
┌──────────────────────────────────────────────────────────────────┐
│                   Standard AI Stack (Bloatware)                  │
│  Python ──> PyTorch ──> CUDA/Driver ──> Linux Kernel ──> Silicon │
│  [Latency: Multi-Microsecond Trap Gates & Massive DRAM Copying]   │
├──────────────────────────────────────────────────────────────────┤
│                  AetherOS Bare-Metal Unikernel                   │
│       LLM Graph ──> Native Assembly ──> Silicon Ring Buffer      │
│     [Latency: Direct Clock-Cycle Determinism & Zero Copies]      │
└──────────────────────────────────────────────────────────────────┘

```

### Core Tenets

- **Zero-Abstraction Execution:** The kernel directly programs PCIe configurations, GPGPU Command Streamers, and memory page translation tables without intermediate libraries or host operating systems.  

- **Physical Ring-0 Omnipresence:** All compute paths, model weights, and device MMIO structures reside in a flat 64-bit address space, eliminating TLB invalidations, context switches, and Ring-3 system call penalties.  

- **Deterministic Resource Budgeting:** Every buffer, queue, and scratchpad is statically allocated or bound to dedicated physical memory zones (e.g., `ZONE_TENSOR`), guaranteeing zero memory spilling during forward passes.  

- **Bit-Exact Correctness Verification:** Every optimized kernel is verified against CPU floating-point references on real silicon via qualification gates (`exact=1, mismatch_count=0`) before promotion to production execution.  

## 2. High-Level Architecture

AetherOS integrates the operating system, device drivers, and AI inference runtime into a single compiled binary (`x86_64-unknown-none`):

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    AETHEROS SYSTEM COMPOSITION                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  GRAPHICS & COMPOSITOR                                                      │
│  ┌─────────────────────────┐  ┌─────────────────────────┐                   │
│  │ Double-Buffered Display │  │ Dirty-Rect Compositor   │ (60 FPS Native)   │
│  │ (1920x1080 32bpp BGR)   │  │ (Obsidian / Atticus)    │                   │
│  └─────────────────────────┘  └─────────────────────────┘                   │
├─────────────────────────────────────────────────────────────────────────────┤
│  ASYMMETRIC MULTIPROCESSING (AMP) & NEURAL COMPUTE POOL                     │
│  ┌───────────────────────┐  ┌─────────────────────────────────────────────┐ │
│  │ Core 0 (BSP):         │  │ Core 1: Inference Master (Graph / Tokenizer)│ │
│  │ Compositor, UI, I/O   │  ├─────────────────────────────────────────────┤ │
│  │ (F10 Turbo Freeze)    │  │ Cores 2 & 3: Neural Worker Pool (AVX2 Q6_K) │ │
│  └───────────────────────┘  └─────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────────┤
│  HYBRID INFERENCE ROUTER & TENSOR FABRIC                                    │
│  ┌──────────────────────────────────────────┬─────────────────────────────┐ │
│  │ Intel Gen9 RCS GPGPU Engine:             │ CPU SIMD Engine:            │ │
│  │ • 2OW Packed SIMD8 (Q4_K)                │ • Dual-Row AVX2 FMA (Q6_K)  │ │
│  │ • QKV Triple-Walker (2.67M cyc/layer)    │ • Fused Bit-Unpack Pipeline │ │
│  │ • FFN Gate+Up Dual-Walker (10.7M cyc/pr) │ • Lock-Free Mailbox IPC     │ │
│  │ • FFN Down 2OW ($K=8192$, 9.05M cyc/lyr) │ • Multi-Core Chunking       │ │
│  └──────────────────────────────────────────┴─────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────────────────┤
│  ZERO-COPY STORAGE & MEMORY MANAGEMENT                                      │
│  ┌───────────────────────┐  ┌─────────────────────────┐  ┌────────────────┐ │
│  │ Physical Frame Alloc  │  │ Zero-Flush GGTT Cache   │  │ xHCI USB 3.0 / │ │
│  │ (4KB Bitmap / Heap)   │  │ (260K Pages / 1.01 GB)   │  │ NVMe Driver    │ │
│  └───────────────────────┘  └─────────────────────────┘  └────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘

```

## 3. Boot, Initialization & Memory Layout

### Boot Flow & Entry Sequence

AetherOS initializes via the **Limine v8.x protocol**, validating hardware capabilities before taking control of the machine:  

1. **`_start`** **Entry Point:** Configures control registers (`CR0.EM=0, CR0.TS=0, CR0.MP=1`, `CR4.OSFXSR=1, CR4.OSXMMEXCPT=1`), aligns the stack to 16 bytes, and loads `MXCSR = 0x1F80` (masking all SIMD exceptions).  

2. **Phase 0–2 (Core Bringup):** Probes CPUID features (SSE, AVX, AVX2, FMA3, RDRAND), sets up GDT/TSS, loads the IDT, and activates Local APIC and I/O APIC.  

3. **SMP Sequential Wakeup:** Application Processors (APs) are woken sequentially through the Limine SMP protocol, establishing per-core GDT/TSS allocations and entering their assigned operational loops.  

4. **Phase 3–4 (Memory & Storage):** Initializes Physical Memory Bitmap allocator, allocates the higher-half heap, initializes the 64MB DMA Bump Allocator (`0x18000000–0x1C000000`), mounts NVMe and xHCI USB drives, and configures the double-buffer surface.  

5. **Phase 7 (AI Fabric & Engine):** Binds the `ZONE_TENSOR` memory budget (7,348 MB available), initializes the GPGPU GGD/PPGTT tables, isolates Core 1 for the Inference Master, and hands execution to the compositor.  

### Physical & Virtual Memory Layout

```
Physical Address Space:
0x0000_0000 ────────┬─ Low Memory / BIOS / Real Mode Stacks
0x0010_0000 ────────┼─ Kernel Image (.text, .rodata, .data, .bss)
0x1800_0000 ────────┼─ DMA Bump Allocator (64 MB) [WiFi / NVMe / xHCI]
0x1C00_0000 ────────┼─ NVMe DMA Region & Transient Scratchpads
0x2000_0000 ────────┼─ ZONE_TENSOR (7,348 MB) — GGUF Weights & Active Tensors
0xB000_0000 ────────┼─ Intel iGPU BAR0 MMIO (16 MB)
0xB130_0000 ────────┼─ xHCI USB BAR0 MMIO (64 KB)
0xB131_8000 ────────┼─ Intel AX201 WiFi BAR0 MMIO (64 KB)
0xFEE0_0000 ────────┼─ Local APIC Registers
0xFEC0_0000 ────────┴─ I/O APIC Registers

Virtual Address Space:
0x0000_5555_0000_0000 ── Dynamic MMIO Mappings (GPU, xHCI, WiFi)
0x0000_4444_0000_0000 ── Kernel Heap Space (256 MB – 2 GB, KASLR-slid)
0xFFFF_8000_2000_0000 ── Model Weight Direct Memory-Mapped Base (HHDM)
0xFFFF_CA00_0000_0000 ── Demand-Paged Virtual KV-Cache (128 MB window)
0xFFFF_FFFF_8000_0000 ── Higher-Half Kernel Code & Static Data

```

## 4. Hardware Drivers & Subsystems

### PCI & NEXUS Device Manager

The NEXUS device manager scans all buses (0–255), matches PCI class/subclass/vendor IDs, and applies the **Universal Handshake** (`Memory Space + Bus Master + INTx Disable`):

- **00:00.0 (8086:9b71):** Host Bridge  

- **00:02.0 (8086:9b41):** Intel UHD 620 Gen9 GT2 Graphics (BAR0: 16MB MMIO, BAR2: 256MB Aperture)  

- **00:14.0 (8086:02ed):** Intel Comet Lake xHCI USB 3.0 Controller  

- **00:14.3 (8086:02f0):** Intel Wi-Fi 6 AX201 CNVi Companion Module  

- **07:00.0 (1e0f:0001):** Toshiba KIOXIA KBG40ZNT256G NVMe Controller  

### xHCI USB 3.0 & Mass Storage Pipeline

```
[Port Detect / Polling] ──> [Cold Reset (7ms, PLS=U0)] ──> [Enable Slot & Address Device]
                                                                   │
[FAT32 Adaptive Streamer] <── [SCSI READ(10) / Bulk-Only] <───────┘

```

- **DMA Coherency Protocol:** Hardware-verified via `[SILICON-FIST]`, allocating 65 scratchpad buffers in low memory and enforcing explicit `mfence` & `clflush` sequences before doorbell rings.  

- **High-Throughput Storage Ingestion:** Achieves \~384–512 KB adaptive chunk streaming directly from physical flash drives, reading 807.69 MB GGUF models in seconds with 100% CRC32 integrity verification (`0xFBCEC507`).  

## 5. Intel Gen9 GPGPU Compute Engine

AetherOS implements a **bare-metal Intel Gen9 Render Command Streamer (RCS) driver**, executing raw GPGPU Walker compute dispatches directly from ring buffers without user-mode runtimes.  

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    INTEL GEN9 GPGPU EXECUTION PIPELINE                      │
├─────────────────────────────────────────────────────────────────────────────┤
│ 1. PIPELINE_SELECT          ──> Set Pipeline to GPGPU Mode                  │
│ 2. STATE_BASE_ADDRESS       ──> Set General State Base & Dynamic Buffer Base│
│ 3. MEDIA_VFE_STATE          ──> Configure 168 Threads, URB & Scratch Space  │
│ 4. MEDIA_INTERFACE_DESC_LOAD──> Bind Kernel Offsets, SLM Size, SIMD Mode    │
│ 5. GPGPU_WALKER             ──> Dispatch 3D Workgroup Grid across EUs       │
│ 6. MEDIA_STATE_FLUSH        ──> Flush Internal Sampler & Media Pipelines    │
│ 7. PIPE_CONTROL             ──> Memory Barrier, Cache Flush, Fence Write    │
└─────────────────────────────────────────────────────────────────────────────┘

```

### 2OW Packed SIMD8 Assembly Engine (`ED_2OW_REGION_MULADD_W32`)

The primary mathematical kernel for quantized $Q4\\\_K$ tensor operations uses continuous 2-Octoword (32 bytes) memory packing:

- **Weight Layout (AOSOA32):** Interleaves scales, offsets, and 4-bit nibbles across 32-row tiles to allow continuous 256-bit SIMD8 loads via `send` instructions.

- **GRF Register Allocation Budget:** Restricts thread state to **38 General Register Files (GRFs)** out of 128 available registers, guaranteeing **zero register spilling to scratch RAM**.

- **Dynamic K-Dimension Scaling:** Generalizes across $K=2048$ (2,304 OWords/tile) and $K=8192$ (9,216 OWords/tile) using legal Gen9 shift operations (`shr_ud_imm`, `shl_ud_imm`, `add_ud_imm`) without unsupported 32-bit hardware multiplications.

### Multi-Walker Acceleration Matrix

| **Kernel Role**      | **Dimensions**                    | **Architecture**                            | **Latency / Dispatch**     | **Hardware Acceleration**     |                                     |
| -------------------- | --------------------------------- | ------------------------------------------- | -------------------------- | ----------------------------- | ----------------------------------- |
| **QKV Projection**   | $2048\times2048$, $512\times2048$ | `QKV_TRIPLE_WALKER` (Fused 3-Way)  <br>     | **2.67M cycles/layer**<br> | <br>                          | **3.08x Speedup** vs Baseline  <br> |
| **FFN Gate + Up**    | $8192\times2048$                  | `DUAL_WALKER_FLUSH` (Shared $xsum$)  <br>   | **10.71M cycles/pair**<br> | <br>                          | **2.28x Speedup** vs Single-Core    |
| **FFN Down**         | $2048\times8192$                  | `2OW_REGION_MULADD_W32` ($K=8192$)  <br>    | **9.05M cycles/layer**     | **2.34x Speedup** (Bit-Exact) |                                     |
| **Attention Output** | $2048\times2048$                  | `2OW_REGION_MULADD_W32` (Single-Tile)  <br> | **2.40M cycles/layer**<br> | <br>                          | **2.27x Speedup** vs Factored  <br> |

### Zero-Flush GGTT Residency Management

To prevent TLB shootdowns and MMIO thrashing during forward passes, the Global Graphics Translation Table (GGTT) threshold is locked to **260,000 pages (\~1.01 GB)**. All 259 model tensors (original weights, packed tiles, activations, and KV cache pages) remain **100% resident in VRAM/GGTT**, yielding **zero dynamic flushes** during active generation.  

## 6. Neural Compute Pool & CPU SIMD Engine

### Asymmetric Multiprocessing (AMP) Infrastructure

- **Core 0 (BSP):** Dedicated to system orchestration, PS/2 interrupts, and the 60 FPS compositor loop.  

- **Core 1 (Inference Master):** Dedicated execution engine for graph traversal, BPE tokenization, and embedding lookups.  

- **Cores 2 & 3 (Neural Compute Pool):** Isolated worker cores executing parallel AVX2 vector routines via high-speed lock-free mailboxes.  

- **F10 Turbo Mode:** Temporarily pauses Core 0 UI rendering during token generation, directing all system power and memory controller bandwidth to the compute cores.  

```
[Core 1: Inference Master]
     │
     ├── Task Generation (Rows 0..N/2 / Rows N/2..N)
     │
     ├──> [Mailbox 0] ──> [Core 2: AVX2 Dual-Row Kernel] ──> [Atomic Complete]
     │
     └──> [Mailbox 1] ──> [Core 3: AVX2 Dual-Row Kernel] ──> [Atomic Complete]

```

### Zero-Spill Dual-Row Q6_K AVX2 Engine (`vec_dot_q6_k_f32_avx2_2x`)

For 6-bit quantized operations (LM Head and CPU Fallback paths), AetherOS implements a hand-tuned AVX2 kernel:

- **8 YMM Accumulator Architecture:** Allocates 8 vector registers for dual-row accumulation (`ymm0..ymm7`), reserving the remaining 8 registers (`ymm8..ymm15`) for masks, scales, biases, and input vectors. This ensures **100% in-register computation with zero stack spilling**.

- **Streamlined Bit-Unpacking (****`q6_extract_qh!`****):** Combines 4-instruction double shift-mask sequences into single direct-shift extractions, eliminating 512 SIMD instructions per 2-row block (\~32.8 million instructions per LM Head forward pass).

- **Throughput:** Computes the full $128256 \times 2048$ LM Head in **\~164M cycles** across worker cores.  

## 7. Transformer Runtime & Zero-Copy Execution

### Engine Specifications (LLaMA-3.2-1B Architecture)

- **Parameters:** 1.23 Billion ($d\_{model}=2048$, $n\_{layers}=16$, $n\_{heads}=32$, $n\_{kv\\\_heads}=8$, $d\_{ffn}=8192$).  

- **Vocabulary:** 128,256 tokens (TikToken BPE format with UTF-8 byte fallbacks).  

- **Attention Mechanism:** Grouped-Query Attention (GQA) with Rotary Position Embeddings ($\theta = 500,000$).  

- **Non-Linearity:** SwiGLU ($x \cdot \text{SiLU}(\text{Gate}) \cdot \text{Up}$) with pre-layer RMSNorm ($\epsilon = 10^{-5}$).  

### Parallel Prefill & LM-Head Bypassing

In transformer prefill passes over $N$ prompt tokens, intermediate tokens ($0 \dots N-2$) only require KV-Cache population. AetherOS implements `forward_prompt_token`, which completely bypasses the final RMSNorm and 128K-dimensional LM Head projection until token $N-1$:

$$\text{Prefill Time Savings} = (N - 1) \times 164.0\text{ M cycles}$$

- **Short Prompts (12 Tokens):** Prefill completes in **2.70 seconds** (5.40 Gcycles, 43.4% faster).  

- **Long Prompts (57 Tokens):** Prefill completes in **10.47 seconds** (20.95 Gcycles, 54.5% faster, saving >4.6 seconds of compute).

## 8. Graphics, Compositor & UI Subsystems

- **Native Resolution:** 1920×1080 @ 32bpp BGR (Pitch = 7680 bytes).  

- **Compositor Design (Absolute Zero):** Event-driven dirty-rectangle rendering running at 60 FPS, completely decoupling display rendering from compute-core operations.  

- **Obsidian Design Language:** High-contrast, dark-mode terminal aesthetics optimized for system telemetry, line-charted rolling histories, and memory heatmaps.  

- **Global Control Registry:** 192-slot prioritized input table (System $\to$ Global $\to$ Modal $\to$ App $\to$ Default) providing hardware monitoring hotkeys (F1 Debug, F3 Hardware Lab, F4 Integrity Monitor, F10 Turbo Boost, F11 Silicon Lab).  

## 9. Proof Matrix — Hardware Verification Status

The following verification matrix represents the exact status verified via bare-metal serial logs on real hardware:

| **Subsystem / Feature**        | **Real-Hardware Evidence**                                         | **Verification Level**             |                            |      |
| ------------------------------ | ------------------------------------------------------------------ | ---------------------------------- | -------------------------- | ---- |
| **Limine Boot & Memory Map**   | Higher-half jump, 509MB heap, 7348MB Tensor Zone  <br>             | **HW-VERIFIED (100%)**<br>         | <br>                       |      |
| **xHCI USB 3.0 Mass Storage**  | SanDisk Cruzer Blade 29.3GB mounted, SCSI BOT active  <br>         | **HW-VERIFIED (100%)**<br>         | <br>                       |      |
| **GGUF V3 Ingestion**          | 807.69 MB streamed, CRC32 `0xFBCEC507` verified  <br>              | **HW-VERIFIED (100%)**<br>         | <br>                       |      |
| **Intel Gen9 iGPU Bare-Metal** | Ring Buffer active, ELSP dispatch, 0x9B41 detected  <br>           | **HW-VERIFIED (100%)**<br>         | <br>                       |      |
| **2OW Packed SIMD8 Kernel**    | $K=2048$ & $K=8192$ dynamic assemblies, 38 GRFs  <br>              | **HW-VERIFIED (100%)**<br>         | <br>                       |      |
| **QKV Triple-Walker**          | 2.67M cycles/layer, `q_exact=1, k_exact=1, v_exact=1`<br>          | <br>                               | **HW-VERIFIED (100%)**<br> | <br> |
| **FFN Gate+Up Dual-Walker**    | 10.71M cycles/pair, `gate_exact=1, up_exact=1`<br>                 | <br>                               | **HW-VERIFIED (100%)**<br> | <br> |
| **FFN Down 2OW Packed**        | 9.05M cycles/layer, $2048\times8192$, bit-exact parity             | **HW-VERIFIED (100%)**             |                            |      |
| **Zero-Flush GGTT Cache**      | 260,000 pages locked, 0 pressure flushes during decode  <br>       | **HW-VERIFIED (100%)**<br>         | <br>                       |      |
| **CPU Q6_K AVX2 Dual-Row**    | 10,052 dispatches, 0 spills, bit-exact parity  <br>                | **HW-VERIFIED (100%)**<br>         | <br>                       |      |
| **Parallel Prefill Bypass**    | Token-by-token LM Head bypass, 54.5% latency reduction | **HW-VERIFIED (100%)** |                            |      |
| **End-to-End Chat Generation** | Multi-turn 128-token coherent generation (3.41 TPS)  <br>          | **HW-VERIFIED (100%)**<br>         | <br>                       |      |

## 10. Performance Benchmarks & Evolution

### Generational Progress Matrix (April 2026 $\to$ August 2026)

| **Milestone / Round**          | **Architectural Focus**         | **Decode Latency (128 Tokens)** | **Per-Token Forward Pass**  | **Effective Bandwidth**    | **Generation Rate (TPS)** |               |                                 |      |
| ------------------------------ | ------------------------------- | ------------------------------- | --------------------------- | -------------------------- | ------------------------- | ------------- | ------------------------------- | ---- |
| **v1.2 Baseline (April 2026)** | Early Hybrid Dispatch  <br>     | \~4,700 Seconds  <br>           | 78,360,000,000 Cycles  <br> | 0.02 GB/s                  | 0.027 TPS  <br>           |               |                                 |      |
| **ROUND18EL (Early)**          | Single-Walker Factored  <br>    | 54.40 Seconds  <br>             | 827,550,000 Cycles  <br>    | 1.70 GB/s                  | 2.35 TPS  <br>            |               |                                 |      |
| **ROUND18EM**                  | FFN Down 2OW ($K=8192$)         | 47.07 Seconds                   | 719,170,000 Cycles          | 2.05 GB/s                  | 2.72 TPS                  |               |                                 |      |
| **ROUND18EO**                  | Zero-Flush GGTT Caching  <br>   | 37.52 Seconds  <br>             | 570,590,000 Cycles  <br>    | 3.50 GB/s  <br>            | 3.41 TPS  <br>            |               |                                 |      |
| **ROUND18EW (Current)**        | Zero-Spill AVX2 + 2OW QKV  <br> | **39.21 Seconds**<br>           | <br>                        | **612,700,000 Cycles**<br> | <br>                      | **3.52 GB/s** | **3.41 TPS (E2E Verified)**<br> | <br> |

### Breakdown of Current Compute Distribution (Decode Forward Pass)

```
Total Per-Token Decode Cost: ~612.7 Million Cycles (~306 ms / token)

┌─────────────────────────────────────────────────────────────────────────────┐
│ 1. GPU FFN Gate + Up ($8192\times2048$ Dual-Walker): 171.3M Cycles (27.9%)  │
├─────────────────────────────────────────────────────────────────────────────┤
│ 2. CPU LM Head ($128256\times2048$ AVX2 Multi-Core): 165.7M Cycles (27.0%)  │
├─────────────────────────────────────────────────────────────────────────────┤
│ 3. CPU FFN Down ($2048\times8192$ AVX2 Multi-Core): 164.1M Cycles (26.8%)   │
├─────────────────────────────────────────────────────────────────────────────┤
│ 4. GPU Attention Projections (QKV + Output 2OW):     102.4M Cycles (16.7%)  │
├─────────────────────────────────────────────────────────────────────────────┤
│ 5. Norm, RoPE, Softmax, Sampling & Overheads:          9.2M Cycles ( 1.6%)  │
└─────────────────────────────────────────────────────────────────────────────┘

```

## 11. Register Maps & Low-Level Appendix

### Intel Gen9 GPGPU Ring Control Registers

```
0x02030  RCS_RING_TAIL      — Ring buffer write offset
0x02034  RCS_RING_HEAD      — Ring buffer execution offset
0x02038  RCS_RING_START     — Physical base of 16KB command ring
0x0203C  RCS_RING_CTL       — Ring enable & size configuration (0x00003001)
0x0A188  FORCEWAKE_MT       — Multi-threaded domain force-wake request
0x0D0D0  FORCEWAKE_ACK_MT   — Force-wake acknowledgement register
0x800000 GGTT_PTE_BASE      — Global Graphics Translation Table PTE aperture

```

### AVX2 Q6_K 8-Accumulator Register Mapping

```
YMM0..YMM3 : Row 0 Partial Dot-Product Accumulators (f32x8)
YMM4..YMM7 : Row 1 Partial Dot-Product Accumulators (f32x8)
YMM8       : Cached Input Activation Vector x[k..k+32]
YMM9       : Low 4-bit Extraction Mask (0x0F0F0F0F)
YMM10      : High 2-bit Shift Mask (0x30303030)
YMM11      : Quantized Scale Multipliers (vsc0, vsc1)
YMM12..YMM15: Scratch Registers (Unpacked Nibbles, Temp Products)

```

*This document stands as the definitive, physically verified architectural blueprint of* ***AetherOS v0.3.0 "Silicon Sovereign"****. Every latency figure, memory alignment, and opcode sequence documented herein reflects exact silicon telemetry captured on bare-metal hardware.*

---

# Part II — Expanded 43-Section System Reference (April 2026 Baseline, Retained for Completeness)

> **Source identity:** AetherOS Complete System Identity Document v1.2 — April 2026, kernel v0.2.1 “Infinite Horizon”.  
> **Why it is included:** The August source is newer but intentionally much shorter. This older reference contains the exhaustive subsystem inventory and interfaces that are not repeated in the August document.  
> **How to read it:** Treat architecture/interface details as retained reference unless superseded by Part I. Treat its benchmark/readiness claims as historical whenever Part I provides a later measurement or status.

**Source SHA256:** `0DC36CF10F447FF3AD12963F4D861C14A54FDCE7A7967BFA29EDB3C5893797C6`

## Table of Contents

1. [Philosophy & Vision](#1-philosophy--vision)
2. [Architecture Overview](#2-architecture-overview)
3. [Build System & Toolchain](#3-build-system--toolchain)
4. [Boot Sequence](#4-boot-sequence)
5. [Memory Architecture](#5-memory-architecture)
6. [CPU Initialization & SMP](#6-cpu-initialization--smp)
7. [Interrupt Architecture](#7-interrupt-architecture)
8. [Scheduler & Process Model](#8-scheduler--process-model)
9. [Syscall ABI](#9-syscall-abi)
10. [Security & Determinism](#10-security--determinism)
11. [Hardware Abstraction Layer](#11-hardware-abstraction-layer)
12. [PCI/PCIe Subsystem](#12-pcipcie-subsystem)
13. [Device Manager (NEXUS)](#13-device-manager-nexus)
14. [Storage Stack](#14-storage-stack)
15. [Filesystem Layer](#15-filesystem-layer)
16. [USB Stack](#16-usb-stack)
17. [NVMe Driver](#17-nvme-driver)
18. [GPU Compute](#18-gpu-compute)
19. [WiFi Driver (iwlwifi)](#19-wifi-driver-iwlwifi)
20. [Network Stack](#20-network-stack)
21. [DMA Subsystem](#21-dma-subsystem)
22. [IOMMU](#22-iommu)
23. [Thermal & Power Management](#23-thermal--power-management)
24. [Graphics Pipeline](#24-graphics-pipeline)
25. [Design System (Dual Theme)](#25-design-system-dual-theme)
26. [Compositor](#26-compositor)
27. [Input System & Global Control Keys](#27-input-system--global-control-keys)
28. [Application Framework](#28-application-framework)
29. [All Applications Reference](#29-all-applications-reference)
30. [ML / AI Inference Pipeline](#30-ml--ai-inference-pipeline)
31. [GGUF Model Format Support](#31-gguf-model-format-support)
32. [Transformer Architecture](#32-transformer-architecture)
33. [Quantization Engine](#33-quantization-engine)
34. [Asymmetric Multiprocessing (AMP)](#34-asymmetric-multiprocessing-amp)
35. [Inference Gateway (MaaS)](#35-inference-gateway-maas)
36. [Debug & Telemetry](#36-debug--telemetry)
37. [Async Runtime](#37-async-runtime)
38. [Hardware Configuration Reference](#38-hardware-configuration-reference)
39. [Module Inventory](#39-module-inventory)
40. [Runtime Modes](#40-runtime-modes)
41. [Development Log & Improvements](#41-development-log--improvements)
42. [**Proof Matrix — What Is Real**](#42-proof-matrix--what-is-real)
43. [**Benchmarks & Performance**](#43-benchmarks--performance)

---

## 1. Philosophy & Vision

**AetherOS** is a RAM-native, Rust-first experimental x86_64 operating system designed from scratch with three core principles:

- **Fast Iteration** — direct-boot bare-metal development cycle, no legacy compatibility burden
- **Determinism** — reproducible execution for benchmarking and AI inference verification
- **Observability** — every subsystem exposes atomic telemetry readable from any context

### Non-Goals

AetherOS intentionally does NOT pursue:

- Broad hardware support (targets specific Intel laptop/desktop reference hardware)
- ABI stability (internal interfaces change freely between versions)
- POSIX compatibility (custom syscall ABI designed for AI workloads)
- Multi-user / access control (single-operator research OS)

### Identity

AetherOS is not a general-purpose OS. It is an **AI-native research operating system** where the kernel itself understands tensors, quantized model formats, and GPU compute dispatch. The entire stack — from boot to inference — is a single Rust binary with zero runtime dependencies.

---

## 2. Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER INTERFACE                           │
│  ┌──────────┐ ┌─────────┐ ┌──────────┐ ┌──────────┐             │
│  │ Desktop  │ │ Neural  │ │ Pipeline │ │ Settings │  ...        │
│  │ (Obsidi) │ │ Dashboard││ (AI Chat)│ │          │             │
│  └────┬─────┘ └────┬────┘ └────┬─────┘ └────┬─────┘             │
│       └────────────┴───────────┴────────────┘                   │
│                        │                                        │
│              ┌─────────┴──────────┐                             │
│              │    COMPOSITOR      │  Double-buffered,           │
│              │  (Global Keys +    │  render-on-demand,          │
│              │   15 Modes)        │  60 FPS target              │
│              └─────────┬──────────┘                             │
├────────────────────────┼────────────────────────────────────────┤
│                   KERNEL SERVICES                               │
│  ┌─────────┐ ┌────────┐ ┌──────────┐ ┌───────┐ ┌──────────┐     │
│  │Scheduler│ │Process │ │ Syscall  │ │  VFS  │ │ Security │     │
│  │(per-CPU)│ │(16 max)│ │(28 calls)│ │       │ │(SSP/KASL)│     │
│  └─────────┘ └────────┘ └──────────┘ └───────┘ └──────────┘     │
├─────────────────────────────────────────────────────────────────┤
│                    AI / ML RUNTIME                              │
│  ┌──────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ ┌──────────┐     │
│  │ GGUF │ │Transformer││ BPE      │ │  GEMM  │ │  AMP     │     │
│  │Parser│ │(LLaMA/Qw)│ │Tokenizer │ │AVX2+FMA│ │Core0↔C1  │     │
│  └──────┘ └──────────┘ └──────────┘ └────────┘ └──────────┘     │
├─────────────────────────────────────────────────────────────────┤
│                  HARDWARE ABSTRACTION                           │
│  ┌─────┐ ┌──────┐ ┌──────┐ ┌───────┐ ┌──────┐ ┌──────────┐      │
│  │ PCI │ │ USB  │ │ NVMe │ │  GPU  │ │ WiFi │ │  DMA     │      │
│  │     │ │xHCI  │ │Polled│ │Intel  │ │AX201 │ │64MB Bump │      │
│  │     │ │EHCI  │ │      │ │Gen9+  │ │CNVi  │ │          │      │
│  └─────┘ └──────┘ └──────┘ └───────┘ └──────┘ └──────────┘      │
├─────────────────────────────────────────────────────────────────┤
│                      x86_64 HARDWARE                            │
│  Local APIC · I/O APIC · PIC · PIT · RTC · UART · ACPI          │
│  CR0/CR4/XCR0 · GDT/TSS · IDT · SYSCALL/SYSRET · MSRs           │
└─────────────────────────────────────────────────────────────────┘
```

**Key Numbers:**
- ~225 source files across 60+ modules
- Single `#![no_std]` binary — zero runtime linking
- Ring 0 only (no Ring 3 user-mode in default boot path)
- Up to 8 CPUs (SMP with per-AP GDT/TSS)
- 4 KB page granularity, higher-half kernel at `0xFFFFFFFF80000000`

---

## 3. Build System & Toolchain

### Toolchain

| Component | Version | Purpose |
|-----------|---------|---------|
| Rust | nightly | Required for `abi_x86_interrupt`, `alloc_error_handler` |
| Target | `x86_64-unknown-none` | Bare-metal, no OS, no libc |
| Components | rustfmt, clippy, llvm-tools-preview | Code quality + binary introspection |

### Dependencies

| Crate | Version | Purpose |
|-------|---------|---------|
| `limine` | 0.5 | Boot protocol (Limine v8.x) |
| `x86_64` | 0.15.2 | CPU structures (GDT, IDT, paging, CR/MSR access) |
| `uart_16550` | 0.3.2 | Serial I/O driver |
| `spin` | 0.9.8 | Spinlock primitives |
| `linked_list_allocator` | 0.10.5 | Kernel heap allocator |
| `smoltcp` | 0.11 | TCP/IP stack (alloc, IPv4, UDP, TCP, DHCP) |
| `libm` | 0.2 | Software math (sqrtf, expf, sinf, cosf for ML) |

### Build Pipeline

```
build.py → cargo build --release -p kernel
                         ↓
              target/x86_64-unknown-none/release/kernel (ELF64)
                         ↓
              build_uefi_image.py → aetheros.img (FAT32 ESP + Limine)
                         ↓
              QEMU or real hardware via USB
```

**`build.rs`** generates two bootable disk images:
- `uefi.img` — UEFI boot via `bootloader::UefiBoot`
- `bios.img` — Legacy BIOS via `bootloader::BiosBoot`

**RUSTFLAGS:** `-Awarnings -C target-feature=-soft-float,+sse,+sse2`

### Workspace Structure

```
aetheros/
├── kernel/           # no_std bare-metal kernel (the OS)
│   ├── src/          # ~225 source files
│   ├── Cargo.toml    # Kernel crate with 17 feature flags
│   └── linker.ld     # Custom ELF64 linker script
├── aetheros_parsers/ # Host-side parsing utilities
├── src/              # Host runner binary (QEMU launcher)
├── limine/           # Limine bootloader binaries
├── limine.conf       # Bootloader configuration
├── scripts/          # Build & release automation
├── docs/             # Architecture documentation
├── meta/             # Build metrics, gates
└── tools/            # Development utilities
```

### Feature Flags

| Flag | Purpose |
|------|---------|
| `ring3-smoke` | Ring 3 user-mode smoke test |
| `user-init` | User-space init process |
| `nvme-demo` | NVMe demonstration |
| `virtio-net` | VirtIO network driver |
| `usb-hid` | USB HID input |
| `usb-storage` | USB Mass Storage for AI models |
| `smp` | SMP scaffolding |
| `entropy-rdrand` | RDRAND entropy source |
| `force-pic` | Force legacy 8259 PIC |
| `bench-mode` | Headless deterministic benchmark |
| `appliance-mode` | Headless inference service |
| `cloud-unikernel` | AI MicroVM unikernel mode |
| `ci-exit` | Auto-exit after N ticks (CI) |
| `installer-mode` | Installer mode |
| `metrics` | Performance metrics collection |
| `mem-poison` | Memory poisoning for debug |
| `disk-demo` | Disk I/O demo |

---

## 4. Boot Sequence

### Bootloader

AetherOS uses **Limine v8.x** as its bootloader:

```
# limine.conf
timeout: 3
serial: yes
verbose: yes

/AetherOS
    protocol: limine
    kernel_path: boot():/boot/kernel
```

Limine provides: framebuffer, memory map, HHDM (Higher Half Direct Map), RSDP (ACPI), kernel address, SMP wakeup.

### Linker Script

```
OUTPUT_FORMAT(elf64-x86-64)
ENTRY(_start)
KERNEL_OFFSET = 0xffffffff80000000;   /* Higher half */

Sections:
  .text     → PT_LOAD r-x (code)
  .rodata   → PT_LOAD r-- (constants, Limine requests)
  .data     → PT_LOAD rw- (initialized data + BSS)
```

All sections 4KB-aligned. `.eh_frame`, `.note`, `.comment` discarded.

### Entry Point (`_start`)

Naked assembly function — 5 steps before any Rust code:

1. **Stack alignment:** `and rsp, -16` (16-byte ABI boundary)
2. **CR0 setup:** Clear EM (bit 2), clear TS (bit 3), set MP (bit 1) — enable FPU/SSE hardware
3. **CR4 setup:** Set OSFXSR (bit 9), OSXMMEXCPT (bit 10) — enable SSE instructions
4. **MXCSR:** Load `0x1F80` — mask all SIMD FP exceptions, round-to-nearest
5. **Enter Rust:** `sub rsp, 8; jmp _start_rust` — correct ABI RSP%16==8

### `_start_rust()` → `kernel_main()`

```
serial::init()                    // UART COM1 @ 0x3F8
debug::crash_log::enable()        // Flight recorder for all output
verify Limine boot                // BASE_REVISION check
build BootInfo from Limine        // Memory map, framebuffer, RSDP, HHDM
kernel_main(boot_info)            // Main initialization
```

### `kernel_main()` — Complete Phase Sequence

| Phase | Step | Function | Purpose |
|-------|------|----------|---------|
| **0** | Framebuffer init | `gfx::framebuffer::init()` | Map display memory |
| | Boot console | `gfx::boot_console::clear()` | Black screen ready |
| | Banner | — | "AetherOS Kernel v0.2.1 - INFINITE HORIZON" |
| **1** | HW detection | — | Log framebuffer dimensions |
| **2** | Security | `security::init()` | SSP canary, KASLR slide, RDRAND probe |
| | Runtime mode | `runtime::init()` | INTERACTIVE / BENCHMARK / SERVICE |
| | CPU features | `cpu_init::init()` | CPUID, SSE, AVX, AVX2, FMA, XSAVE, MXCSR |
| | GDT | `gdt::init()` | Kernel CS/DS, User CS/DS, TSS, IST stacks |
| | IDT | `interrupts::init_idt()` | Exception handlers, IRQ vectors, MSI table |
| | Syscall gate | `syscall_gate::init()` | SYSCALL/SYSRET MSRs, per-CPU local storage |
| **3** | Memory | `memory::init()` | PMM bitmap, heap (256MB–2GB), page tables |
| | DMA | `dma::init_default()` | 64MB bump allocator @ 384MB |
| | Logger | `debug::logger::init()` | In-memory kernel log ring |
| **4** | Double buffer | `gfx::double_buffer::init()` | Back-buffer allocation |
| | Compositor | `gfx::compositor::init()` | Global keys, console, UI system |
| **5** | Interrupts | `intc::init()` | Auto-detect PIC vs APIC, remap IRQs |
| | SMP | `smp::init()` | Wake application processors (up to 7 APs) |
| | Input | `intc::unmask(1,12)` | Keyboard IRQ1, Mouse IRQ12 |
| | Timer | `pit::init(100)` | 100 Hz system tick |
| | Scheduler | `scheduler::init()` | Per-CPU task queues |
| **6** | PCI | `hal::pci::enumerate()` | Scan all buses/devices/functions |
| | Device Manager | `hal::manager::init()` | Class-code matching + Universal Handshake |
| | Drivers | `hal::manager::init_drivers()` | xHCI → EHCI → WiFi injection |
| | Storage | `hal::storage::detect_controllers()` | NVMe, USB, IDE detection |
| | Filesystem | `fs::mount_boot_media()`, `vfs::auto_mount()` | FAT32, partition tables |
| | IOMMU | `setup_iommu_compute_domain()` | DMA isolation |
| **7** | AI Fabric | `ai::fabric::init()` | AI subsystem framework |
| | Model Manager | `model_manager::init()` | 8-slot model lifecycle |
| | GPU | `gpu::core::discover_compute_devices()` | PCIe GPU scan |
| | Intel iGPU | `gpu::intel::probe()` | Gen9/11/12 RCS ring setup |
| | ML Router | `ml::router::init()` | CPU ↔ GPU transparent dispatch |
| | VKO | `memory::vko_mapper::init()` | Demand-paged model tiles |
| | QoS | `ai::qos::init()` | Inference scheduling policy |
| | Network | WiFi, VirtIO, nano stack, iRPC | Full network init |
| | Inference GW | `inference_gateway::init()` | TCP:8080 MaaS endpoint |
| | AMP | `amp::init()` | Core 1 isolation for inference |
| **8** | **Enable IRQs** | `interrupts::enable()` | System goes live |
| | **Run compositor** | `gfx::compositor::run()` | **Main loop — never returns** |

---

## 5. Memory Architecture

### Physical Memory Layout

```
0x0000_0000 ─┬─ Low memory (legacy ISA DMA, BIOS)
              │
0x0010_0000 ─┼─ Kernel image (.text, .rodata, .data, .bss)
              │
0x1800_0000 ─┼─ DMA Bump Allocator (64 MB)    ← VirtIO, NVMe, GPU, WiFi
0x1C00_0000 ─┤
              │
0x2000_0000 ─┼─ NVMe DMA region
              │
  variable   ─┼─ Kernel Heap (256 MB – 2 GB, KASLR-slid)
              │  Virtual base: 0x4444_4444_0000 + slide
              │
0x2000_0000+ ─┼─ Tensor Zone (≥512 MB for model weights)
              │
0xB131_8000 ─┼─ WiFi BAR0 MMIO (64 KB) [example hardware]
              │
0xFEC0_0000 ─┼─ I/O APIC registers
0xFEE0_0000 ─┼─ Local APIC registers
```

### Virtual Memory Map

| Region | Virtual Address | Purpose |
|--------|----------------|---------|
| Higher Half Kernel | `0xFFFFFFFF80000000` | Kernel code + rodata + data |
| HHDM | `0x10000000000` (16 TB) | Limine's Higher Half Direct Map |
| Kernel Heap | `0x4444_4444_0000 + KASLR` | Dynamic allocations |
| MMIO Mappings | Various | PCI BAR, APIC, GPU registers |

### Heap Allocator

- **Algorithm:** Linked-list allocator (`linked_list_allocator`)
- **Dynamic sizing:** `heap_size = clamp(total_ram / 4, 256MB, 2GB)`
- **KASLR-lite:** Random page slide via `security::heap_slide_pages()`
- **OOM handler:** Custom `#[alloc_error_handler]` — prints diagnostic and halts

### Physical Memory Manager (PMM)

- **Bitmap allocator:** 1 bit per 4 KiB frame
- **Bit=1** → allocated/reserved, **Bit=0** → free
- Built from Limine memory map at boot
- Non-usable regions (ACPI, MMIO, bad memory) pre-marked

### Tensor Buffer System

Zero-copy path from NVMe → DMA → tensor zone:

```
NVMe SSD → DMA Buffer (4KB aligned, PRP) → GGUF Parser → Tensor Buffer (64B aligned)
                                                              ↓
                                                     GPU VRAM (if available)
```

- Reference counted (`AtomicU32`)
- States: `Uninitialized → Valid → Reading/Writing → Evicted`
- SIMD alignment: 64-byte minimum (AVX2 cache line)

### VKO (Virtual Key-value Object) Demand Paging

For large models that exceed physical RAM:

- 8+ GiB virtual space promised
- Physical frames allocated lazily via page fault handler
- `#PF` → `vko_mapper::handle_vko_fault()` → allocate frame → resume
- KV-cache pages similarly demand-faulted via `kv_demand::handle_kv_fault()`
- Prefetch engine (`vko_prefetch`) streams next tiles while computing current
- Evictor (`vko_evictor`) reclaims cold pages under memory pressure

---

## 6. CPU Initialization & SMP

### Per-Core Initialization Sequence

Every core (BSP + APs) executes:

1. **CR0:** Clear EM (no FPU emulation), Clear TS (no task-switch trap), Set MP (monitor FPU)
2. **CR4:** Set OSFXSR + OSXMMEXCPT (SSE support); conditionally set OSXSAVE (if XSAVE available)
3. **XCR0 (if XSAVE):** Enable x87 (bit 0) + SSE (bit 1) + AVX (bit 2) via `xsetbv`
4. **MXCSR:** Load `0x1F80 | FTZ | DAZ` = Fast math mode for ML (flush-to-zero, denormals-are-zero)

### CPUID Feature Detection

| Feature | Detection | Purpose |
|---------|-----------|---------|
| SSE/SSE2 | Leaf 1, EDX bits 25-26 | Baseline SIMD (always present on x86_64) |
| AVX | Leaf 1, ECX bit 28 | 256-bit SIMD |
| FMA3 | Leaf 1, ECX bit 12 | Fused multiply-add (critical for matmul) |
| XSAVE | Leaf 1, ECX bit 26 | Extended state save/restore |
| AVX2 | Leaf 7, EBX bit 5 | 256-bit integer SIMD |
| RDRAND | Leaf 1, ECX bit 30 | Hardware RNG |

**SIMD Tiers:**
- `"AVX2+FMA3 (256-bit)"` — optimal for ML inference
- `"AVX (256-bit)"` — good performance
- `"SSE2 (128-bit)"` — baseline
- `"Scalar (no SIMD)"` — fallback

### GDT Layout

```
Entry 0: Null descriptor
Entry 1: Kernel Code (0x08) — Ring 0, 64-bit, execute-read
Entry 2: Kernel Data (0x10) — Ring 0, read-write
Entry 3: User Data   (0x1B) — Ring 3, read-write
Entry 4: User Code   (0x23) — Ring 3, 64-bit, execute-read
Entry 5: TSS         — Task State Segment
```

**TSS stacks:**
- `privilege_stack_table[0]` → 32 KiB Ring-0 stack
- `interrupt_stack_table[0]` → 20 KiB double-fault stack (IST0)

### SMP — Symmetric Multiprocessing

- Maximum 8 CPUs (`MAX_CPUS = 8`)
- BSP wakes APs **sequentially** via Limine SMP protocol
- Each AP receives unique `cpu_index` in Limine's `extra` field
- AP trampoline (naked assembly) → `ap_rust_entry()`:
  1. `cpu_init::init()` — full SIMD/FPU
  2. `gdt::init_ap()` — heap-allocated per-AP GDT + TSS (Box::leak)
  3. `interrupts::init_idt()` — load shared IDT
  4. `apic::init_cpu_local()` — calibrate local APIC timer
  5. Enable interrupts
  6. `scheduler::run_ap()` — enter scheduler (never returns)
- Online tracking: `CPU_ONLINE_MASK: AtomicU64` (bit per LAPIC ID)
- Sequential wake prevents race conditions on heap allocations

---

## 7. Interrupt Architecture

### IDT Vector Map

| Vector | Source | Handler |
|--------|--------|---------|
| 0 | #DE | `divide_error` |
| 4 | #OF | `overflow` |
| 3 | #BP | `breakpoint` |
| 6 | #UD | `invalid_opcode` |
| 8 | #DF | `double_fault` (IST0, 20KB dedicated stack) |
| 13 | #GP | `general_protection_fault` |
| 14 | #PF | `page_fault` (VKO + KV demand-page fast path) |
| `IRQ_BASE + 0` | Timer | `timer_handler` (100 Hz, scheduler tick) |
| `IRQ_BASE + 1` | Keyboard | `keyboard_handler` (PS/2 IRQ1) |
| `IRQ_BASE + 12` | Mouse | `mouse_handler` (PS/2 IRQ12) |
| `0x40–0x4F` | MSI/MSI-X | 16-slot dynamic registration |
| `0x80` | Syscall | `syscall_handler` (INT 0x80 legacy path) |

### Interrupt Controller Auto-Detection

`intc::init()` probes for APIC:

- **APIC available:** Remap I/O APIC (MADT ISOs respected), calibrate LAPIC timer, mask PIC
- **APIC unavailable / `force-pic`:** Use 8259 PIC, remap to vectors `0x20–0x2F`

### MSI/MSI-X System

- 16-slot registration table (`MSI_HANDLERS: [AtomicUsize; 16]`)
- `register_msi_handler()` → CAS into first free slot → returns vector
- Batch allocation with atomic rollback on failure
- Per-entry masking for MSI-X

### Page Fault Handler — AI Fast Path

```rust
fn page_fault_handler(frame) {
    let addr = Cr2::read();
    
    // 1. VKO tile fault → demand-page model weight tile
    if memory::vko_mapper::handle_vko_fault(addr) { return; }
    
    // 2. KV cache fault → demand-page KV cache page
    if memory::kv_demand::handle_kv_fault(addr) { return; }
    
    // 3. User-mode fault → signal delivery → process exit
    // 4. Kernel fault → panic
}
```

### Timer Handler

- Respects `runtime::irq_allowed(0)` gating
- In BENCHMARK mode: tracks noise budget (IRQ cost)
- Calls `scheduler::on_timer_tick()` for preemption
- Checks VKO I/O queue for pending demand-fault wake-ups

---

## 8. Scheduler & Process Model

### Scheduler Design

- **Per-CPU schedulers:** `SCHEDS: [Mutex<Scheduler>; 8]` — one per core
- **Algorithm:** Cooperative with preemptive fallback via timer tick
- **Max tasks per CPU:** 8 (`MAX_TASKS = 8`)

### Task Structure

```rust
pub struct Task {
    pub id: u32,
    pub priority: u8,           // Lower = higher priority
    pub state: TaskState,       // Ready, Running, Sleeping, Blocked, Exited
    pub counter: u64,           // Scheduling quantum
    pub wake_tick: u64,         // Sleep until this tick
    pub cancel_requested: bool,
    pub step: fn(&mut Task),    // Task body function pointer
    pub cpu_affinity: Option<u8>,     // Pin to specific core
    pub priority_ceiling: u8,         // Priority ceiling protocol
    pub data_plane: bool,             // No preemption, no IRQ
    pub address_space: Option<AddressSpace>,
    pub acc: TaskAccounting,          // run_slices, syscalls, yields, etc.
}
```

### Process Model

- **Max processes:** 16 (`MAX_PROCS = 16`)
- **File descriptors:** 16 per process
- **Capabilities:** `DEBUG | CONSOLE_WRITE | NET | EXEC | CLOUD` (default user)
- **State machine:** `New → Ready → Running → Sleeping/Blocked → Exited`

---

## 9. Syscall ABI

### SYSCALL/SYSRET Gate

```
MSR Configuration:
  IA32_EFER   (0xC000_0080) — SCE bit enabled
  IA32_STAR   (0xC000_0081) — Kernel CS=0x08, User CS base
  IA32_LSTAR  (0xC000_0082) — syscall_entry address
  IA32_FMASK  (0xC000_0084) — Clear IF on entry
```

**Calling Convention:**
- Syscall number in `RAX`
- Arguments in `RDI, RSI, RDX, R10, R8, R9`
- Return value in `RAX`

### Syscall Table

| Number | Name | Purpose |
|--------|------|---------|
| 0 | `Yield` | Cooperative yield |
| 1 | `Debug` | Debug print (requires DEBUG capability) |
| 2 | `TestDone` | CI test completion signal |
| 3 | `Write` | Write to file descriptor |
| 4 | `GetBuildId` | Return build identifier |
| 5 | `CloudRpc` | Cloud RPC call |
| 6 | `UdpSend` | Send UDP packet |
| 7 | `UdpRecv` | Receive UDP packet |
| 8 | `GetPid` | Get process ID |
| 9 | `Exit` | Terminate process |
| 10 | `Exec` | Execute program |
| 11 | `Wait` | Wait for child |
| 12 | `WaitPid` | Wait for specific child |
| 13 | `Fork` | Fork process |
| 14 | `Open` | Open file |
| 15 | `Close` | Close file descriptor |
| 16 | `Read` | Read from file descriptor |
| 17 | `GetPpid` | Get parent PID |
| 18 | `Kill` | Send signal |
| 19 | `Getuid` | Get user ID |
| 20 | `Getgid` | Get group ID |
| 21 | `Sigaction` | Signal handler registration |
| 22 | `Sigprocmask` | Signal mask control |
| 23 | `Getpgid` | Get process group |
| 24 | `Setpgid` | Set process group |
| 25 | `Prctl` | Process control |
| **100** | **`TensorLoad`** | **Load tensor from disk to DMA buffer** |
| **101** | **`TensorFree`** | **Release tensor buffer** |
| **102** | **`TensorStatus`** | **Query tensor state** |
| **161** | **`ExecuteInference`** | **Native AI inference dispatch** |

Syscalls 100-102 and 161 are the "AetherOS Special" — native AI operations as first-class system calls.

---

## 10. Security & Determinism

### Stack Smashing Protection (SSP)

- Compile-time canary injection
- Stack overflow detection at function return

### KASLR-Lite

- `HEAP_SLIDE_PAGES: AtomicU64` — random page offset for heap base
- Entropy from RDRAND (if available) or TSC + build ID mixing
- Prevents fixed-address exploits against kernel heap

### Entropy

```rust
BUILD_ID_SEED = u64::from_le_bytes(*b"AETHER01");
fn mix64(x: u64) -> u64    // Stafford Mix13 / SplitMix64 finalizer
fn rdtsc() -> u64           // Always available on x86_64
fn probe_rdrand() -> bool   // CPUID leaf 1, ECX bit 30
```

### Determinism Enforcement

For reproducible benchmark/inference:

1. **Page pre-touching** — walk all memory at boot to populate page tables
2. **Slab warmup** — prime allocator with alloc/free cycles
3. **Memory residency tracking** — HOT/WARM/COLD/PINNED states
4. **Fragmentation monitoring** — `frag_index = 1 - (largest_free / total_free)`, warn > 0.3

**Residency States:**
| State | Description |
|-------|-------------|
| HOT | In L1/L2 cache (accessed < 1ms ago) |
| WARM | In L3 or main memory |
| COLD | Potentially paged out |
| PINNED | Guaranteed resident (driver-pinned) |

In benchmark mode: tensor buffers → PINNED, pack buffers → HOT, result buffers → WARM.

---

## 11. Hardware Abstraction Layer

### HAL Module Tree

```
hal/
├── mod.rs      — Top-level exports
├── pci.rs      — PCI/PCIe config space, BAR, MSI/MSI-X
├── storage.rs  — Block device abstraction, controller detection
├── usb.rs      — USB subsystem wrapper (xHCI feature-gated)
└── manager.rs  — NEXUS device management, driver injection
```

### Supported Hardware Matrix

| Subsystem | Hardware | Implementation Status |
|-----------|----------|----------------------|
| PCI/PCIe | Legacy I/O (0xCF8/CFC) + ECAM | Fully implemented |
| MSI/MSI-X | Programming + per-entry mask | Fully implemented |
| Local APIC | Timer calibration, EOI, IPI | Fully implemented |
| I/O APIC | IRQ routing, ISA remapping | Fully implemented |
| 8259 PIC | ICW1-4, IRQ remapping to 0x20 | Fully implemented |
| 8253/54 PIT | Channel 0, Mode 3 (100 Hz) | Fully implemented |
| MC146818 RTC | CMOS registers, date/time | Fully implemented |
| UART 16550 | COM1 @ 0x3F8 | Fully implemented |
| ACPI | RSDP v1/v2, RSDT/XSDT, MADT | Fully implemented |
| xHCI USB 3.0 | DMA rings, port management | Fully implemented |
| EHCI USB 2.0 | Basic controller support | Fully implemented |
| USB Mass Storage | Bulk-Only Transport, SCSI, FAT32 | Fully implemented |
| NVMe | Polled driver, zero-copy DMA | Fully implemented |
| Intel iGPU | Gen9/11/12 RCS, GPGPU_WALKER | Fully implemented |
| NVIDIA GPU | GSP firmware scaffolding | Framework only |
| VirtIO-GPU | virgl 3D + TGSI compute | Implemented |
| Intel WiFi | AX200/AX201 CNVi, Gen2 TX/RX queues | In progress |
| DMA | 64MB bump allocator | Fully implemented |
| Intel VT-d | Register definitions, domain setup | Framework |
| ACPI EC Battery | Intel EC (0x62/0x66), SBS | Fully implemented |
| Thermal | MSR-based PID governor | Fully implemented |

---

## 12. PCI/PCIe Subsystem

### Configuration Space Access

Two parallel implementations:

| Method | Module | Usage |
|--------|--------|-------|
| Legacy I/O | `hal/pci.rs` | Primary — ports 0xCF8/0xCFC |
| ECAM MMIO | `pcie/` | Secondary — `base + (bus<<20) + (dev<<15) + (func<<12) + offset` |

### Enumeration

- Scans buses 0–255, devices 0–31, functions 0–7
- Detects multi-function devices via header_type bit 7
- BFS bridge traversal for hierarchical topologies
- Populates `Vec<PciDevice>` with vendor_id, device_id, class codes

### BAR Management

```rust
probe_bar(bus, dev, func, bar_index)
// 1. Save current BAR value
// 2. Write 0xFFFFFFFF
// 3. Read back → size mask
// 4. Restore original value
// Returns: (base_address, size, is_io_bar)
```

Validates: non-zero, 4KB-aligned MMIO, no address overflow.

### MSI/MSI-X Programming

```rust
// MSI: cap_id = 0x05
enable_msi(bus, dev, func, vector, dest_apic_id)
// Address: 0xFEE00000 | (apic_id << 12)
// Data: vector | fixed delivery | edge-triggered

// MSI-X: cap_id = 0x11, MMIO table in BAR
enable_msix(bus, dev, func, vector, dest_apic_id)
program_msix_entry(bus, dev, func, entry, vector, apic_id, masked)
```

### Universal Handshake

Every non-bridge PCI device receives:
```rust
enable_device(bus, dev, func)
// Set: Memory Space + Bus Master + INTx Disable
```

---

## 13. Device Manager (NEXUS)

The NEXUS Industrial Device Manager provides centralized hardware lifecycle management.

### Driver Match Table

| PCI Class:Subclass:ProgIF | Driver | Description |
|----------------------------|--------|-------------|
| `0x0C:0x03:0x30` | `XhciUsb3` | xHCI USB 3.0 Host Controller |
| `0x0C:0x03:0x20` | `EhciUsb2` | EHCI USB 2.0 Host Controller |
| `0x0C:0x05:*` | `Smbus` | SMBus Controller |
| `0x01:0x08:0x02` | `Nvme` | NVMe SSD Controller |
| `0x01:0x06:*` | `Ahci` | AHCI/SATA Controller — **stub only** (`init placeholder`) |
| `0x02:0x00:*` | `VirtioNet` | Ethernet Controller — **BUG:** matches ALL Ethernet including Realtek RTL8168; only works for VirtIO NICs in QEMU; no native Realtek driver |
| `0x02:0x80:*` | `IntelWifi` | Intel WiFi (CNVi) |
| `0x03:0x00:*` | `VgaDisplay` | VGA/Display Controller |
| `0x04:0x03:*` | `IntelHda` | HD Audio Controller — detected + bus-mastered, **no codec driver** |
| `0x06:0x00:*` | `HostBridge` | Host Bridge |
| `0x06:0x01:*` | `IsaBridge` | ISA Bridge |
| `0x06:0x04:*` | `PciBridge` | PCI-to-PCI Bridge |

### Device Lifecycle

```
Discovered → Matched → Initializing → Running → [Failed | Removed]
```

### Driver Injection Order

1. xHCI USB 3.0 → `xhci::init_with_device()`
2. EHCI USB 2.0 → `ehci::init_with_device()`
3. Intel WiFi → `iwlwifi::init_with_device()`
4. USB Mass Storage scan → `scan_for_msc_devices()`

---

## 14. Storage Stack

### Block Device Trait

```rust
pub trait BlockDevice {
    fn block_size(&self) -> u32;
    fn read_blocks(&mut self, lba: u64, buf: &mut [u8]) -> StorageResult<()>;
    fn write_blocks(&mut self, lba: u64, buf: &[u8]) -> StorageResult<()>;
}
```

`read_at(offset_bytes, buf)` provides byte-granular access via 4096-byte scratch buffer.

### Async Block Device

```rust
pub trait AsyncBlockDevice {
    fn submit_read(&mut self, lba: u64, buf: &mut [u8]) -> StorageResult<IoToken>;
    fn poll(&mut self, token: IoToken) -> Poll<StorageResult<()>>;
}
```

`SyncIoBridge<B>` adapts synchronous devices to async interface.

### Boot Media Detection

Priority chain:
1. **NVMe** — GPT + MBR detection, FAT32 probe
2. **USB Mass Storage** — xHCI hardware enumeration
3. **Legacy IDE** — fallback for QEMU/older hardware
4. **Brute force** — scan first 2MB for filesystem signatures

---

## 15. Filesystem Layer

### VFS Architecture

```
VFS Mount Table
├── /disk0/  → FAT32 on NVMe partition
├── /usb0/   → FAT32 on USB Mass Storage
├── /nvme0/  → NVMe direct access
└── /ram/    → In-memory RamFS
```

### Supported Filesystems

| Format | Support Level |
|--------|--------------|
| FAT32 | Full read, LFN support, cluster chain caching |
| FAT16/FAT12 | Detection + basic read |
| RamFS | Built-in with /etc/os-release, /README.txt, /bin/init, /bin/sh |

### VFS Node Types

`File`, `Directory`, `Symlink`, `Device`, `Unknown`

### FAT32 Cluster Chain Cache

Eliminates O(n²) FAT table walks:
```rust
pub struct ClusterChainCache {
    entries: [u32; 256],     // 256 cached cluster numbers
    // 256 × 4KB/cluster = 1MB sequential read without re-walking
}
```

### Partition Table Support

- **MBR:** Standard partition entry parsing, boot signature validation
- **GPT:** Full header + entry parsing, GUID-based partition identification

---

## 16. USB Stack

### Module Tree

```
drivers/usb/
├── xhci.rs         — xHCI controller driver (DMA rings, TRBs)
├── ehci.rs         — EHCI USB 2.0 controller
├── msc.rs          — Mass Storage Class (Bulk-Only Transport)
├── scsi.rs         — SCSI Transparent Command Set
└── fat32_scanner.rs — GGUF model file scanner
```

### xHCI Controller

Full xHCI implementation:
- **Register sets:** Capability, Operational, Runtime, Doorbell
- **DMA structures:** Command Ring, Event Ring, Transfer Ring (all TRB-based)
- **TRB types:** Normal, Setup Stage, Data Stage, Status Stage, Link, Enable Slot, Address Device, Configure Endpoint, Transfer Event, Command Completion, Port Status Change
- **DMA-SHIELD coherency:** `clflush` + `mfence` before every doorbell ring

### USB Mass Storage Flow

```
xHCI Port Detect → Enable Slot → Address Device → Configure Endpoint
                                                          ↓
     SCSI READ(10) ← Bulk-Only Transport ← USB MSC class (0x08/0x06/0x50)
                                                          ↓
                                                   FAT32 Scanner
                                                          ↓
                                                   GGUF Model Files
```

Retry logic: Up to 3 attempts with 500ms delays (Intel Cannon Lake/AMD Renoir port training).

---

## 17. NVMe Driver

### Architecture

- **Polled mode** — no interrupt-driven completion, minimal latency
- **Zero-copy DMA** — PRP-aligned buffers pass directly to consumers
- **Queue pairs:** Admin SQ/CQ + N I/O SQ/CQs

### Key Interface

```rust
pub fn read_physical(nsid: u32, lba: u64, phys_addr: u64, sector_count: u32)
// Zero-copy: NVMe writes directly to specified physical address
// Primary interface for sys_tensor_load syscall
```

### Controller Capabilities

```rust
pub struct ControllerCapabilities {
    pub mqes: u16,     // Max Queue Entries Supported
    pub cqr: bool,     // Contiguous Queues Required
    pub ams: u8,       // Arbitration Mechanism Supported
    pub to: u8,        // Timeout (500ms units)
    pub dstrd: u8,     // Doorbell Stride
    pub mpsmin: u8,    // Min Memory Page Size (2^(12+mpsmin))
    pub mpsmax: u8,    // Max Memory Page Size
}
```

---

## 18. GPU Compute

### Intel iGPU Driver

Direct bare-metal GPGPU on Intel Gen9+ (Skylake through Tiger Lake).

### Supported Devices

| Device ID | GPU | Generation |
|-----------|-----|------------|
| `0x9B41` | Comet Lake GT2 | Gen9 |
| `0x9BC4` | UHD 630 | Gen9 |
| `0x9B21` | UHD 620 | Gen9 |
| `0x8A52` | Iris Plus G7 | Gen11 |
| `0x9A49` | Iris Xe | Gen12 |

### GPGPU Dispatch Pipeline

7-step command sequence via Render Command Streamer (RCS) ring:

```
1. PIPELINE_SELECT → GPGPU mode
2. STATE_BASE_ADDRESS → set heap bases
3. MEDIA_VFE_STATE → configure EU threads, URB, scratch
4. MEDIA_CURBE_LOAD → constant data (kernel arguments)
5. MEDIA_INTERFACE_DESCRIPTOR_LOAD → bind kernel + SLM + thread count
6. GPGPU_WALKER → dispatch compute thread groups (X × Y × Z)
7. PIPE_CONTROL → flush + write completion fence
```

### GGTT (Global Graphics Translation Table)

- PTE base at BAR0 + `0x800000`
- 4KB page granularity
- Maps physical → GPU-visible addresses
- TLB invalidation via `GFX_FLSH_CNTL_GEN6`

### Force Wake

GPU power states require explicit wake before register access:
```rust
FORCEWAKE_MT = 0x0A188
FORCEWAKE_ACK_MT = 0x0D0D0  // Gen9
FORCEWAKE_ACK_GT = 0x130044 // Gen11+
```

---

## 19. WiFi Driver (iwlwifi)

### Target Hardware

Intel Wi-Fi 6 AX201 (CNVi) — PCI 8086:02F0

CNVi = Connectivity Integration — WiFi silicon integrated into the PCH, sharing MMIO via a companion PCI function.

### Supported Device IDs

| Device ID | Name |
|-----------|------|
| `0x2723` | Wi-Fi 6 AX200 |
| `0x2725` | Wi-Fi 6E AX210 |
| `0x2726` | Wi-Fi 6E AX211 |
| `0x02F0` | Wi-Fi 6 AX201 (CNVi) |
| `0x06F0` | Wi-Fi 6 AX201 (CNVi) |
| `0x34F0` | Wi-Fi 6 AX201 (CNVi) |
| `0xA0F0` | Wi-Fi 6 AX201 (CNVi) |
| `0x4DF0` | Wi-Fi 6 AX201 (CNVi) |
| `0x54F0` | Wi-Fi 6 AX201 (CNVi) |
| `0x7E40` | Wi-Fi 7 BE200 |
| `0x272B` | Wi-Fi 7 BE200 |

### CSR Register Map

| Register | Offset | Purpose |
|----------|--------|---------|
| `CSR_HW_IF_CONFIG_REG` | `0x000` | HW interface config |
| `CSR_INT` | `0x008` | Interrupt status |
| `CSR_INT_MASK` | `0x00C` | Interrupt mask |
| `CSR_FH_INT_STATUS` | `0x010` | FH interrupt status |
| `CSR_RESET` | `0x020` | Reset control |
| `CSR_GP_CNTRL` | `0x024` | GP control (clocks, power, RF-kill) |
| `CSR_HW_REV` | `0x028` | Hardware revision |
| `CSR_GIO_REG` | `0x03C` | GP I/O |
| `CSR_GP_DRIVER_REG` | `0x050` | GP driver register |
| `CSR_FW_ERROR` | `0x05C` | Firmware error status |
| `CSR_MAC_ADDR0_OTP` | `0x380` | MAC address (low 32) |
| `CSR_MAC_ADDR1_OTP` | `0x384` | MAC address (high 16) |

### GP_CNTRL Bit Definitions

| Bit | Name | Purpose |
|-----|------|---------|
| 0 | `MAC_CLOCK_READY` | Clock stabilized |
| 2 | `INIT_DONE` | Init sequence complete |
| 3 | `MAC_ACCESS_REQ` | Request MMIO access |
| 4 | `GOING_TO_SLEEP` | Power transition |
| 15 | `XTAL_ON` | Crystal oscillator |
| 27 | `HW_RF_KILL_SW` | RF-kill hardware switch |

### Firmware

- **File:** `iwlwifi-Qu-b0-hr-b0-77.ucode` (1,406,572 bytes)
- **Embedding:** Compile-time `include_bytes!()` via `build.rs`
- **Format:** Intel uCode with section headers (CPU1/CPU2/INIT/DATA/PAGING)
- **Upload:** DMA to device SRAM via FH (Firmware Handler) registers

### Bootstrap Sequence

```
Phase A: ensure_firmware_loaded()    → Parse uCode sections
         dma_load_firmware()         → DMA upload to device SRAM

Phase B: boot_firmware_and_wait_alive() → Start microcontroller
                                        → Wait for ALIVE notification

Phase C: nvm_init()                  → Read NVM (MAC address, calibration)

Phase D: init_cmd_queue()            → Set up Gen2 TX/RX command queues
```

### Gen2 TX/RX Command Queue

**TX Queue (Host → Firmware):**
- TFD ring: `CMD_QUEUE_SIZE=32` entries × 256 bytes
- Command buffer pool: 32 × 320 bytes
- Byte count table: 32 × 2 bytes
- Doorbell: `HBUS_TARG_WRPTR` (0x460)
- `send_host_cmd(cmd_id, group_id, payload)` — build HostCmdWide, fill TFD, ring doorbell

**RX Queue (Firmware → Host):**
- Free BD ring: `RX_QUEUE_SIZE=64` entries × 8 bytes
- Used BD ring: 64 entries
- Status writeback page
- Buffer pool: 64 × 4 KiB buffers
- RFH (Rx Frame Handler) registers for queue configuration

### Scan Operation

```rust
send_scan_command()
// Builds UMAC scan request:
//   cmd = 0x0C (SCAN_REQ_UMAC)
//   group = 0x01 (IWL_LONG_GROUP)
//   channels: 1, 6, 11 (2.4 GHz) + 36, 44 (5 GHz)
//   dwell: 110 TU (time units)
//   flags: passive scan

poll_scan_results()
// 1. Wait for command ACK (1s timeout)
// 2. Wait for scan complete notification (4s timeout)
// 3. Parse BSS entries from notification payload
```

---

## 20. Network Stack

### Dual Stack Architecture

| Stack | Library | Purpose |
|-------|---------|---------|
| smoltcp | `net/stack.rs` | Full TCP/UDP/DHCP (development/testing) |
| Nano Stack | `net/nano_stack.rs` | Zero-alloc minimal TCP for inference gateway |

### smoltcp Stack

- Loopback device (1500 MTU)
- UDP/TCP echo servers for testing
- DHCP client with lease state machine

### Nano Stack

Zero-dependency, zero-allocation:

```rust
pub struct NetworkConfig {
    pub mode: NetworkMode,         // Static or DHCP
    pub ip: [u8; 4],              // Default: 10.0.2.15 (QEMU)
    pub gateway: [u8; 4],         // Default: 10.0.2.2
    pub subnet: [u8; 4],          // Default: 255.255.255.0
}
```

Features: Ethernet frame parsing, ARP, IPv4, TCP (SYN/ACK/PSH), Port 8080 listener.

### WiFi Manager

```
State machine: NoAdapter → Disconnected → Scanning → Connecting → Connected
                                                          ↓
                                                       Failed
```

Debug log ring buffer. Simulation mode with demo networks when no hardware adapter present.

---

## 21. DMA Subsystem

### Bump Allocator

```
Base:  0x1800_0000 (384 MB)
Size:  64 MB (384–448 MB)
Align: 64 bytes minimum
```

Does NOT overlap tensor zone (≥512 MB) or NVMe region (0x20000000).

### DMA Buffer

```rust
pub struct DmaBuffer {
    pub phys_addr: PhysAddr,    // For hardware DMA descriptors
    pub virt_addr: VirtAddr,    // For CPU access
    pub size: usize,
    pub align: usize,
}
```

Used by: NVMe queues, PRP lists, GPU command buffers, WiFi TX/RX rings, VirtIO descriptors.

---

## 22. IOMMU

### Intel VT-d Register Map

| Register | Offset | Purpose |
|----------|--------|---------|
| VER | 0x00 | Version |
| CAP | 0x08 | Capability |
| ECAP | 0x10 | Extended Capability |
| GCMD | 0x18 | Global Command |
| GSTS | 0x1C | Global Status |
| RTADDR | 0x20 | Root Table Address |
| CCMD | 0x28 | Context Command |
| IOTLB | 0x108 | IOTLB Invalidation |

Enables DMA isolation for peer-to-peer transfers (NVMe ↔ GPU) and device memory protection.

---

## 23. Thermal & Power Management

### PID-Loop Thermal Governor

Reads CPU temperature via MSRs:

| MSR | Address | Purpose |
|-----|---------|---------|
| `IA32_THERM_STATUS` | `0x19C` | Core temperature readout |
| `MSR_TEMPERATURE_TARGET` | `0x1A2` | TjMax ceiling |
| `IA32_PERF_CTL` | `0x199` | P-state request |
| `IA32_PERF_STATUS` | `0x198` | Current P-state |
| `MSR_PKG_POWER_LIMIT` | `0x610` | PL1/PL2 power limits |
| `MSR_PKG_ENERGY_STATUS` | `0x611` | Energy counter |

### Control Algorithm

```
error(t) = T_target - T_current
P = Kp × error(t)
I = Ki × Σerror(τ)dτ           (clamped: prevents integral windup)
D = Kd × d(error)/dt
output = clamp(P + I + D, 0.0, 1.0)
```

| Output Range | Action |
|-------------|--------|
| < 0.3 | Reduce inference batch size (thermal throttle) |
| 0.3 – 0.7 | Maintain current load |
| > 0.7 | Increase batch size (use thermal headroom) |

### Battery Driver

ACPI Embedded Controller interface for laptop battery monitoring:

| EC Register | Offset | Data |
|-------------|--------|------|
| AC Status | 0x30 | AC adapter connected (bit 0) |
| Battery Status | 0x32 | Status flags |
| Discharge Rate | 0x34 | mW (16-bit) |
| Remaining | 0x36 | mWh (16-bit) |
| Voltage | 0x38 | mV (16-bit) |
| Full Charge | 0x3A | mWh (16-bit) |
| Design Cap | 0x3C | mWh (16-bit) |
| Temperature | 0x3E | 0.1K (16-bit) |

Snapshot cached for 2 seconds (TSC-based) to avoid excessive EC I/O.

---

## 24. Graphics Pipeline

### Rendering Architecture

```
                    ┌─────────────────┐
                    │   Compositor     │ ← Main loop (60 FPS)
                    │  render-on-demand│
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  Double Buffer   │ ← Heap-allocated back buffer
                    │  (dirty rects)   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │   Framebuffer    │ ← Limine-provided, linear MMIO
                    │  (front buffer)  │
                    └─────────────────┘
```

### Framebuffer

- Provided by Limine bootloader
- Linear memory-mapped pixel buffer
- Pixel format auto-detected: RGB or BGR (via red_shift analysis)
- `Color { r: u8, g: u8, b: u8 }` → `to_u32()` = `0x00RRGGBB`

### Double Buffer

- Heap-allocated back buffer (same dimensions as framebuffer)
- Dirty-rect tracking (max 256 rects)
- `present()` — copy dirty regions to front buffer
- `HeapStats` — tracks allocation pressure

### Fonts (Three Systems)

| Font | Size | Source | Usage |
|------|------|--------|-------|
| Mini Font | 3×5 | `font.rs` | Minimal display |
| Painter Font | 6×10 | `painter.rs` | Primary UI text (7px advance, 12px line height) |
| IBM VGA 8×16 | 8×16 | `text_engine.rs` | CP437 subset, 1x-5x scaling, boot console |

---

## 25. Design System (Dual Theme)

AetherOS maintains two coexisting design systems:

### Obsidian Theme (Dark — Active Desktop)

Deep navy backgrounds with neon accent colors. Used for all runtime UI.

#### Primary Backgrounds

| Token | Hex | RGB | Usage |
|-------|-----|-----|-------|
| `BG_PRIMARY` | `#0A0F1A` | (10,15,26) | Main background |
| `BG_SURFACE` | `#12171F` | (18,23,31) | Panels |
| `BG_ELEVATED` | `#1A1F2B` | (26,31,43) | Cards and modals |
| `BG_HOVER` | `#242A38` | (36,42,56) | Interactive hover |

#### Accent Colors

| Token | Hex | RGB | Usage |
|-------|-----|-----|-------|
| `ACCENT_CYAN` | `#00E5FF` | (0,229,255) | Primary accent |
| `ACCENT_BLUE` | `#0091EA` | (0,145,234) | Secondary accent |
| `ACCENT_GREEN` | `#00E676` | (0,230,118) | Success/active |
| `ACCENT_AMBER` | `#FFB300` | (255,179,0) | Warning |
| `ACCENT_CORAL` | `#FF5252` | (255,82,82) | Error/critical |
| `ACCENT_PURPLE` | `#BB86FC` | (187,134,252) | Analysis |

#### Text Colors

| Token | Hex | RGB | Usage |
|-------|-----|-----|-------|
| `TEXT_PRIMARY` | `#FFFFFF` | (255,255,255) | Pure white |
| `TEXT_SECONDARY` | `#E8E8E8` | (232,232,232) | Bone white |
| `TEXT_MUTED` | `#8892A0` | (136,146,160) | Tertiary |
| `TEXT_DIM` | `#5A6270` | (90,98,112) | Placeholders |

#### Status Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `STATUS_RUNNING` | `#00E676` | Running |
| `STATUS_PAUSED` | `#FFB300` | Paused |
| `STATUS_ERROR` | `#FF5252` | Error |
| `STATUS_IDLE` | `#5A6270` | Idle |

#### Heatmap Gradient (Tensor Visualization)

```
COLD ─── COOL ─── NEUTRAL ─── WARM ─── HOT
#0A2463  #1E5AA8   #3D8EE0   #FFB300  #FF5252
```

### Atticus Theme (Light — Analytical)

Neoclassical design for precision interfaces. "Rationalist Authority, Constructive Minimalism, Material Honesty."

#### Core Palette

| Token | Hex | RGB | Usage |
|-------|-----|-----|-------|
| `COLOR_BONE` | `#FAFAF8` | (250,250,248) | Primary background |
| `COLOR_CARBON` | `#2B2B2B` | (43,43,43) | Primary typography |
| `COLOR_NAVY` | `#0E2A48` | (14,42,72) | Single accent (point of focus ONLY) |
| `COLOR_HAIRLINE` | `#E5E5E3` | (229,229,227) | Subtle separators |
| `COLOR_ERROR` | `#8B3A3A` | (139,58,58) | Muted red |
| `COLOR_SUCCESS` | `#3A8B5E` | (58,139,94) | Muted green |

#### Design Rules

- **Corner radius:** Maximum 2px (anything more is "soft and unprofessional")
- **Shadows:** None. Depth via luminance shift only.
- **Animation:** `linear` easing, 200ms duration, instant-stepping
- **Spacing unit:** 8px base grid
- **No glassmorphism.** Objects STEP into existence.

#### Typography

| Style | Size | Tracking | Line Height |
|-------|------|----------|-------------|
| H1 | 18pt | +2px | 24px |
| H2 | 14pt | +1px | 20px |
| H3 | 12pt | 0 | 16px |
| Body | 11pt | 0 | 16px |
| Caption | 9pt | 0 | 12px |
| Monospace | 10pt | 0 | 14px |

#### Quad-Zone Layout

```
┌──────────────┬──────────────────────────────────────────┐
│              │          TOP HEADER (40px)                │
│              ├──────────────────────────────────────────┤
│   LEFT NAV   │                                          │
│   (200px)    │         CENTER CANVAS                    │
│              │         (1080 × 728)                      │
│              │                                          │
│              ├──────────────────────────────────────────┤
│              │          BOTTOM DOCK (32px)               │
└──────────────┴──────────────────────────────────────────┘
                    Total: 1280 × 800
```

---

## 26. Compositor

### Operation: ABSOLUTE ZERO (Render-on-Demand)

```rust
static NEEDS_REDRAW: AtomicBool;    // Set by any state change
fn schedule_redraw();                // Call on input, mode switch, timer
fn consume_redraw() -> bool;         // Atomic swap, clears flag
// Fallback: force redraw every 120 frames (~2s)
```

Terminal, HardwareLab, IntegrityMonitor, SiliconLab always redraw (live data).

### CompositorMode (15 Modes)

| Mode | Hotkey | Description |
|------|--------|-------------|
| `Welcome` | (boot) | Boot splash — Space/Enter to skip |
| `Desktop` | (default) | Main desktop with nav, dock, apps |
| `Settings` | S | 10-tab settings panel |
| `Demo` | — | Demo mode |
| `PaintTool` | — | Paint tool |
| `DrawingTool` | — | Drawing tool |
| `TextEditor` | — | Text editor |
| `Terminal` | T | Terminal/console |
| `CommandControl` | C | GGUF model loader & inference monitor |
| `Neural` | N | Neural telemetry dashboard |
| `ManageModels` | — | 3-panel neural pipeline dashboard |
| `HardwareLab` | F3 | PROJECT X-RAY: live USB/PCI debugging |
| `IntegrityMonitor` | F4 | SILICON-FIST: DMA pipeline verification |
| `Workstation` | F5-F9 | Multi-context workspace (Pipeline/Editor/Explorer/Monitor) |
| `SiliconLab` | F11 | GPU EU reverse engineering console |

### Main Loop (`run() -> !`)

```
loop {
    poll_input()                    // Keyboard + mouse events
    tick_blink_cursor()             // Cursor animation
    drain_amp_tokens()              // AI token IPC from Core 1
    tick_global_console()           // Debug overlay updates
    poll_pci_hotplug()              // Device change detection
    poll_battery()                  // EC snapshot refresh
    
    if should_redraw() {
        render_current_mode()       // Mode-specific rendering
        double_buffer.present()     // Copy to front buffer
    }
    
    draw_mouse_cursor()             // Always on top
    
    yield_if_target_fps()           // 60 FPS pacing
}
```

### Mouse Cursor

11×16 pixel classic pointer shape. Navy blue (`#003D7A`) with white outline. Drawn AFTER buffer present (always on top of all content).

---

## 27. Input System & Global Control Keys

### Input Pipeline

```
PS/2 IRQ1 → keyboard::on_scancode() → lockfree_queue + legacy ring
PS/2 IRQ12 → mouse::on_byte() → atomic position + buttons
                      ↓
events::poll_from_devices() → compositor handle_input()
                      ↓
global_keys::try_dispatch_system() → mode-specific handlers
```

### Keyboard Driver

- US PC/AT Set 1 scan codes
- Modifier tracking: Left/Right Shift, Left Ctrl, Left Alt, Caps Lock, Num Lock
- `is_upper = shift XOR caps_lock` (proper Shift+CapsLock behavior)
- Lock-free queue for compositor thread + legacy ring buffer for polling

### Mouse Driver

- Pure relative mode (standard 3-byte PS/2 packets)
- Y-axis inversion for screen coordinates
- Atomic button state for cross-thread access
- Speed multiplier: 2×
- Dynamic resolution via `set_resolution(w, h)`

### Global Control Keys Registry

Centralized keybinding system — every app registers its keys, the registry handles priority-based dispatch.

#### Priority Levels

| Priority | Level | Semantics |
|----------|-------|-----------|
| 0 | **System** | Always processed first (debug console) |
| 1 | **Global** | Mode-switch hotkeys (F3, F4, F11) |
| 2 | **Modal** | Active overlays (WiFi popup, prompt input) |
| 3 | **App** | Active application's own keys |
| 4 | **Default** | Fallback / unbound |

#### System Keys

| Key | Action |
|-----|--------|
| F1 | Toggle debug console overlay |
| F2 | Cycle debug console scale (1x-5x) |

#### Global Keys

| Key | Action |
|-----|--------|
| F3 | Toggle Hardware Lab (PROJECT X-RAY) |
| F4 | Toggle Integrity Monitor (SILICON-FIST) |
| F5-F9 | Switch Workstation views |
| F11 | Toggle Silicon Lab |

#### Registry API

```rust
pub fn init()                                           // Register all bindings
pub fn register(binding: KeyBinding)                    // Add single binding
pub fn lookup_scancode(sc, ctrl, alt, shift) → Option   // Best-match by priority
pub fn lookup_char(ch) → Option                         // Character-based lookup
pub fn try_dispatch_system(sc, mods) → bool             // Handle System/Global keys
pub fn bindings_for(app: AppId) → Vec                   // Help screen data
pub fn all_bindings() → Vec                             // Complete registry dump
pub fn scancode_name(sc) → &str                         // Human-readable key name
```

18 apps × ~60 bindings × 192 max slots.

---

## 28. Application Framework

### Application Architecture

Every application in AetherOS is:

- A **module** in `kernel/src/apps/` with a `render()` function
- Called directly by the compositor based on current `CompositorMode`
- Has access to the `Painter` API for rendering
- Uses atomic globals for state (no heap allocation in render path)
- Registers its keybindings with the Global Control Keys registry

### AppId Registry (18 Apps)

| AppId | Module | Purpose |
|-------|--------|---------|
| `System` | — | Global system keys |
| `DebugConsole` | `gfx/global_console` | F1 debug overlay |
| `Desktop` | `apps/desktop_obsidian` | Main shell |
| `Neural` | `apps/dashboard_obsidian` | AI telemetry dashboard |
| `CommandControl` | `apps/command_control` | GGUF model management |
| `ManageModels` | `apps/manage_models` | 3-panel neural pipeline |
| `Settings` | `apps/settings` | 10-tab settings |
| `Terminal` | `apps/terminal` | Terminal emulator |
| `HardwareLab` | `apps/hardware_lab` | USB/PCI debugging |
| `IntegrityMonitor` | `apps/integrity_monitor` | DMA verification |
| `SiliconLab` | `apps/silicon_lab` | GPU EU fuzzer |
| `Workstation` | — | Multi-context workspace |
| `WifiPopup` | `apps/wifi_popup` | WiFi management overlay |
| `PromptInput` | `prompt_input` | AI prompt bar |
| `Pipeline` | `apps/pipeline_view` | AI chat interface |
| `Explorer` | `apps/explorer_view` | File browser |
| `Editor` | `apps/editor_view` | Text editor |
| `Monitor` | `apps/system_monitor` | Hardware telemetry |

---

## 29. All Applications Reference

### Desktop (Obsidian)

Main shell with header, left navigation, bottom dock, and system menu.

**Layout:** Left panel (200px) + Top header (40px) + Bottom dock (48px) + Center canvas

**Navigation Modes:** Desktop(D), Explorer(F), Terminal(T), Editor(E), Pipeline(P), Settings(S), Neural(N), Command(C)

**Dock Items:** Files(F), Term(T), Edit(E), Set(S), Neural(N), Cmd(C)

**Clock:** RTC-driven real-time display in header.

### Neural Dashboard

Real-time AI telemetry with rolling history graphs.

**Data Sources:** `debug::telemetry`, `sim::stats()`, `ai::fabric`

**Metrics:** Throughput (tokens/sec), memory usage, latency, GFLOPS

**Visualization:** 128-sample rolling history with line graphs.

### Settings

10-tab comprehensive settings panel:

| Tab | Features |
|-----|----------|
| Network | DHCP/Static IP, gateway, DNS, connection test |
| Display | Console scale, theme selection |
| System | Hostname, debug level, boot mode |
| Time | Manual time/NTP configuration |
| Audio | Volume, mute toggle |
| Security | Serial output, secure boot status |
| Thermal | Governor, temperature limits |
| Storage | Cache, scan interval |
| AI Model | Max model slots, inference parameters |
| About | Version, memory, uptime |

### Command Control

GGUF model loader and inference monitor. Lists available models from USB storage, loads into AI engine, monitors inference progress.

### Pipeline View (AI Chat)

Interactive AI chat interface:

- **Input:** 256-char text buffer with cursor and blink
- **Message list:** Scrollable, 64 messages max
- **Sidebar:** Model navigation (220px), load/cancel controls
- **Streaming:** Real-time token display from AMP engine

### Hardware Lab (PROJECT X-RAY)

F3 — Live USB/PCI debugging console.

**3 Panels:** Port Matrix, PCI Dump, Command Log

**Commands:** R(refresh), D(PCI D0 revive), K(kick port), A(recovery all), M(mount force), P(power cycle)

### Silicon Lab (Silicon Oracle)

F11 — GPU EU Reverse Engineering Console. Autonomous genetic hardware fuzzer with two modes:

- **Breach Mode:** Fuzzes MEDIA_VFE_STATE, IDD, GPGPU_WALKER parameters. Victory = GPU HANG (EU woke up).
- **Payload Mode:** Uses proven pipeline to fuzz SEND instructions. Victory = `0xDEADBEEF` in sync page.

State: `Idle → Running → Paused → HangRecovery → Victory`

Genetic evolution: 64 seeds per generation, mutation rate adjustable via ←/→ keys.

### WiFi Popup

Modal overlay (440×540) for WiFi management:
- Network list with signal bars
- Password input for secured networks
- Debug log (6 visible lines)
- Controls: T(toggle), D(disconnect), F5(scan), S(server)

### Prompt Input

Global AI inference prompt bar:
- Zero-alloc hot path (static 256-byte buffer)
- Parameter adjustment: Temperature, Top-K, Top-P, Max Tokens
- Tab to activate, Enter to submit to `amp::submit_prompt()`

### Explorer

VFS-backed file/directory browser:
- FAT32 filesystem traversal
- Directory navigation with path display
- File size display

### Editor

Multi-buffer text editor:
- Named buffers with modified tracking
- Cursor positioning (x, y) with vertical scrolling
- Tab switching between open buffers

### System Monitor

Real-time hardware telemetry (all atomic reads, zero blocking):
- CPU: core count, online mask, AMP state
- Performance: tokens/sec, tokens generated
- Memory: heap total/used, tensor total/used
- GPU: availability, generation (Gen9/11/12)
- Model: loading state, progress, speed

---

## 30. ML / AI Inference Pipeline

### Architecture Overview

```
GGUF File (USB/NVMe) → Parser → Tensor Map → Transformer Model
                                                      ↓
User Prompt → BPE Tokenizer → Token IDs → Forward Pass → Logits
                                            ↓              ↓
                                      KV Cache      Sampling (Top-K/P)
                                            ↓              ↓
                                      Next Token ← Token ID → Detokenize
                                            ↓
                                      Output Text
```

### Core Data Types

```rust
pub struct Shape { dims: [usize; 4], ndim: usize }
pub struct Stride { strides: [usize; 4] }
pub struct Tensor<'a> { shape: Shape, stride: Stride, data: &'a mut [f32] }
```

### ML Module Tree

| Module | Purpose |
|--------|---------|
| `ops` | CPU matmul, add, relu, dot, scale (loop-unrolled) |
| `norm` | RMSNorm (LLaMA/Qwen) + LayerNorm (GPT/BERT) |
| `rope` | Rotary Positional Embeddings with frequency caching |
| `activation` | Softmax, SiLU, SwiGLU, GELU, ReLU + sampling |
| `attention` | Multi-head causal self-attention with KV-cache |
| `transformer` | Complete Llama-style transformer |
| `tokenizer` | BPE tokenizer with byte-level vocab + merge rules |
| `inference` | End-to-end pipeline: text → tokens → model → text |
| `profiler` | RDTSC cycle-accurate profiler |
| `gguf` | GGUF V3 parser |
| `router` | Hybrid compute router (GPU ↔ CPU dispatch) |
| `quant` | GGML K-Quants dequantization |
| `gemm` | General Matrix Multiply (scalar + AVX2+FMA) |

### GEMM (Matrix Multiply)

Two code paths with runtime selection:

| Path | Detection | Width | Operations |
|------|-----------|-------|-----------|
| Scalar | Always available | 4x unrolled | Basic FMA in software |
| AVX2+FMA | CPUID leaf 7 + leaf 1 | 256-bit YMM | 8-wide FMA3 instructions |

```rust
pub fn gemv(w: &[f32], x: &[f32], out: &mut [f32], rows: usize, cols: usize)
// If Neural Compute Pool active: partitions rows across all cores
```

### Inference Engine

```rust
pub struct InferenceEngine {
    pub tokenizer: Tokenizer,
    pub model: Transformer,
    pub config: TransformerConfig,
}

pub struct InferenceResult {
    pub output_text: String,
    pub input_tokens: usize,
    pub output_tokens: usize,
    pub prefill_cycles: u64,
    pub decode_cycles: u64,
    pub total_params: usize,
    pub vocab_size: usize,
    pub success: bool,
}
```

### AI Engine Phases

| Phase | Value | Description |
|-------|-------|-------------|
| IDLE | 0 | No model loaded |
| PARSING | 1 | Parsing GGUF header |
| LOADING | 2 | Streaming tensor data |
| READY | 3 | Model loaded, awaiting prompts |
| GENERATING | 4 | Token generation active |
| ERROR | 5 | Unrecoverable error |

All phases exposed as atomic globals readable from any UI thread.

---

## 31. GGUF Model Format Support

### Parser

- **Magic:** `0x46554747` ("GGUF" LE)
- **Version:** 3
- **Max metadata:** 1,024 entries
- **Max tensors:** 4,096 tensors
- **Default alignment:** 32 bytes

### Metadata Types

`Uint8, Int8, Uint16, Int16, Uint32, Int32, Float32, Bool, String, Array, Uint64, Int64, Float64`

### Tensor Quantization Formats (GGML)

| Format | ID | Block Size | Elements | Purpose |
|--------|-----|-----------|----------|---------|
| F32 | 0 | 4 bytes | 1 | Full precision |
| F16 | 1 | 2 bytes | 1 | Half precision |
| Q4_0 | 2 | 18 bytes | 32 | 4-bit quantization |
| Q4_1 | 3 | 20 bytes | 32 | 4-bit with min |
| Q8_0 | 8 | 34 bytes | 32 | 8-bit quantization |
| Q2_K | 10 | 84 bytes | 256 | 2-bit K-quant |
| Q3_K | 11 | 110 bytes | 256 | 3-bit K-quant |
| Q4_K | 12 | 144 bytes | 256 | 4-bit K-quant |
| Q5_K | 13 | 176 bytes | 256 | 5-bit K-quant |
| Q6_K | 14 | 210 bytes | 256 | 6-bit K-quant |
| BF16 | 29 | 2 bytes | 1 | BFloat16 |

All K-Quant dequantization is bit-for-bit compatible with llama.cpp.

---

## 32. Transformer Architecture

### Configuration

```rust
pub struct TransformerConfig {
    pub vocab_size: usize,       // Typical: 32K-128K
    pub dim: usize,              // Model dimension
    pub n_heads: usize,          // Attention heads
    pub n_kv_heads: usize,       // KV heads (GQA support)
    pub n_layers: usize,         // Transformer layers
    pub ffn_hidden: usize,       // FFN intermediate dimension
    pub max_seq_len: usize,      // Context window
    pub rope_theta: f32,         // RoPE frequency base
    pub norm_eps: f32,           // Normalization epsilon
    pub activation: ActivationType,  // SiLU/GELU/ReLU
    pub has_qkv_bias: bool,      // Bias in attention projections
}
```

### Supported Activations

| Type | Models |
|------|--------|
| SiLU (SwiGLU) | LLaMA, Mistral, Qwen, Phi |
| GELU | GPT-2, GPT-NeoX, BERT |
| ReLU | Classic architectures |

### Weight Organization

```rust
pub struct TransformerBlock {
    pub attn: AttentionWeights,    // Q, K, V, O projection matrices
    pub ffn: FfnWeights,          // gate, up, down matrices (SwiGLU)
    pub attn_norm: QTensor,       // Pre-attention RMSNorm
    pub ffn_norm: QTensor,        // Pre-FFN RMSNorm
}
```

### QTensor (Zero-Copy Quantized)

```rust
pub struct QTensor {
    pub ptr: *const u8,      // Points into mapped GGUF file data
    pub dtype: GgmlType,     // Quantization format
    pub rows: usize,
    pub cols: usize,
}
```

Zero-copy: QTensor points directly into memory-mapped GGUF data. No copying or conversion until dequantization in the hot loop.

### KV Cache — Demand Paging

```rust
pub enum KvBuffer {
    Heap(Vec<f32>),                    // Small context ≤2048 tokens
    DemandPaged { ptr: *mut f32 },     // ≥8 GiB virtual, frames on #PF
}
```

Physical frames allocated lazily via page fault handler. Only consumes RAM for tokens actually generated.

### Scratch Buffers (V7.1 — Zero Allocation Hot Path)

```rust
// Allocated once at model load, reused every token:
scratch_x: Vec<f32>,           // [dim]
scratch_norm_buf: Vec<f32>,    // [dim]
scratch_logits: Vec<f32>,      // [vocab_size] — 500KB for 128K vocab
scratch_ffn_gate: Vec<f32>,    // [ffn_hidden]
// ... (8 total scratch buffers)
```

### Attention Mechanism

```
Input x [dim]
    → Q, K, V projections (matmul with quantized weights)
    → Split into heads
    → RoPE(Q, K) — Rotary Positional Embedding
    → Attention scores = Q × K^T / sqrt(head_dim)
    → Causal mask (upper triangle = -inf)
    → Softmax
    → Weighted sum of V
    → Concat all heads
    → Output projection
    → [dim]
```

---

## 33. Quantization Engine

### GGML K-Quant Block Formats

All blocks are `#[repr(C, packed)]` for zero-copy over GGUF memory.

| Format | Block | Bytes | Elements | Layout |
|--------|-------|-------|----------|--------|
| Q2_K | `{ d[2], dmin[2], scales[16], qs[64] }` | 84 | 256 | d/dmin at start |
| Q3_K | `{ hmask[32], qs[64], scales[12], d[2] }` | 110 | 256 | d at END (offset 108) |
| Q4_K | `{ d[2], dmin[2], scales[12], qs[128] }` | 144 | 256 | d/dmin at start |
| Q5_K | — | 176 | 256 | — |
| Q6_K | — | 210 | 256 | — |

Super-block width: `QK_K = 256` elements.

All dequantization is scalar (no SIMD dependency), bit-for-bit matching llama.cpp output.

---

## 34. Asymmetric Multiprocessing (AMP)

### Core Isolation

| Core | Role | Workload |
|------|------|----------|
| **Core 0** (BSP) | Compositor | PS/2 input, rendering, UI — zero ML math |
| **Core 1** | Compute (inference master) | Transformer forward passes, AVX2 matmul — **HW-VERIFIED**: loaded Llama-3.2-1B-Q4_K_M (807 MB), token generation with GPU+CPU hybrid dispatch (96 GPU dispatches/token, fence_avg≈812.8M cycles). Fwd≈78.36B cycles/token. Q4_K GPU-CPU validation: maxDiff < 0.00002. |

### Lock-Free IPC Token Ring (Core 1 → Core 0)

```rust
const TOKEN_RING_CAP: usize = 256;     // SPSC ring buffer

pub struct IpcToken {
    pub token_id: u32,
    pub bytes: [u8; 16],     // Decoded UTF-8 payload
    pub byte_len: u8,
    pub position: u32,       // Sequence position
    pub logit_norm: f32,     // L2 norm health metric
}

pub fn push_token(tok: IpcToken) -> bool   // Core 1 writes
pub fn pop_token() -> Option<IpcToken>      // Core 0 reads
```

### Telemetry (Atomic Cross-Core)

```rust
static TELEM_TOKENS_GENERATED: AtomicU32
static TELEM_TOKS_PER_SEC_X100: AtomicU32   // Fixed-point ×100
static TELEM_GFLOPS_X10: AtomicU32           // Fixed-point ×10
static TELEM_STATE: AtomicU8                 // GenState enum
```

**GenState:** `Idle(0) → Prefill(1) → Decoding(2) → Complete(3) | Error(4)`

### Prompt Submission (HW-VERIFIED — End-to-End on Real Hardware)

> **Hardware status (Restore-Point Log):** Core 1 boots to "waiting for model." Pipeline tab click triggers model scan → FAT16 USB volume found → `LOADED "Llama-3.2-1B-Instruct-Q4_K_M.gguf" — 100%` (807 MB, CRC=0x1B186177, adaptive I/O ≈384 KB chunks). Core 1 transitions to `READY — accepting prompts via IPC`. UI prompt "ping pong" submitted → tokenized → 16-layer transformer forward pass → token generation with GPU-preferred hybrid dispatch. Per-token: 96 GPU dispatches, fence_avg≈812.8M cycles, Fwd≈78.36B cycles. Q4_K GPU-CPU validation verified (maxDiff < 0.00002 across all dims). Log exported to USB.

```
User types prompt → Tab activates PromptInput → Enter → amp::submit_prompt()
                                                              ↓
                                                        Core 1 wakes
                                                              ↓
                                                    Transformer forward pass
                                                              ↓
                                                    push_token() per generated token
                                                              ↓
                                                    Core 0 drains in compositor loop
                                                              ↓
                                                    Rendered in Pipeline View
```

---

## 35. Inference Gateway (MaaS)

Designed as TCP port 8080 — Model-as-a-Service endpoint.

> **Hardware status:** `init()` sets a `GATEWAY_ENABLED` atomic bool only. No real TCP listener is bound. On bare metal there is no network backend (Realtek RTL8168 has no driver, WiFi has no data plane). The protocol spec below is the design target.

### Binary Protocol (Little-Endian)

**Request:**
```
[0x02] INFER
[u32]  token_id          // Prompt token
[u16]  max_tokens        // Generation limit
[u8]   flags             // 0x01=stream, 0x02=greedy, 0x04=echo_prompt
```

**Response (streaming):**
```
[u8]   status            // 0x00=token, 0x01=EOS, 0xFF=error
[u32]  token_id
[u32]  logit × 1000      // Fixed-point confidence
[u16]  seq_pos           // Sequence position
```

**Status query:**
```
[0x03] STATUS → binary telemetry snapshot
```

### Gateway Telemetry

All lock-free atomics:
- `REQUESTS_TOTAL`, `REQUESTS_ACTIVE`, `TOKENS_SERVED`
- `NET_BYTES_RX/TX`, `NET_PACKETS_RX/TX`
- `LAST_LATENCY_US`, `AVG_LATENCY_US_X100`
- `ACTIVE_CONNECTIONS`, `GATEWAY_ENABLED`

---

## 36. Debug & Telemetry

### Debug Module Tree

| Module | Purpose |
|--------|---------|
| `debug::telemetry` | Global metrics collection and summary |
| `debug::logger` | In-memory kernel log ring buffer |
| `debug::crash_log` | V7.3 flight recorder — mirrors ALL serial output |

### Serial Output

All kernel logging routes through UART 16550 at COM1 (0x3F8):
- Atomic serialization (V7.1: prevents interleaving across cores)
- Mirrored to: in-memory logger + flight recorder
- Hex formatting: `print_hex_u64/u32/u16/u8()`

### Global Console (F1)

Debug overlay rendered on top of any compositor mode:
- Toggle with F1
- Scale cycling with F2 (1x–5x)
- HiDPI-aware text engine (IBM VGA 8×16 font)
- Shows: kernel log, heap stats, CPU state, driver status

### Forensic Dump

`forensic::forensic_panic_dump("KERNEL_PANIC")` — called on panic handler:
- Dumps CPU register state
- Stack trace (if available)
- Last N log entries from flight recorder

---

## 37. Async Runtime

### Design

Non-preemptive cooperative executor replacing spin-wait loops:

```rust
const MAX_TASKS: usize = 64;
const WAKE_QUEUE_SIZE: usize = 128;

enum TaskState { Free=0, Ready=1, Sleeping=2, Done=3 }
```

- Fixed-size task ring buffer (no heap allocation in hot path)
- Tasks stored as type-erased fat pointers (data + vtable, 2×u64)
- Wakers set atomic flag
- Integration: `wait_for_event_async()` replaces xHCI spin-waits
- CPU yields via HLT during I/O waits; hardware ISR wakes Waker

---

## 38. Hardware Configuration Reference

### Primary Development Target

| Component | Specification |
|-----------|--------------|
| CPU | Intel Core i3-10110U (Comet Lake, 2C/4T) |
| Architecture | x86_64, Comet Lake-U |
| SIMD | SSE2, AVX, AVX2, FMA3 |
| RAM | Variable (heap sized as RAM/4, 256MB–2GB) |
| GPU | Intel UHD 620 (Gen9, CML GT2) |
| WiFi | Intel Wi-Fi 6 AX201 (CNVi, PCI 8086:02F0) |
| WiFi BAR0 | 0xB131_8000 (64 KB) |
| WiFi HW_REV | 0x00000351 |
| USB | xHCI USB 3.0 |
| Storage | NVMe SSD (for OS) + USB Mass Storage (for models) |
| Battery | ACPI EC at 0x62/0x66 |
| Serial | UART 16550 @ COM1 (0x3F8) |
| APIC | Local APIC @ 0xFEE0_0000 + I/O APIC @ 0xFEC0_0000 |

### QEMU Development Configuration

```
Machine: q35
CPU: host (passthrough)
Memory: 2G+
Network: user-mode (10.0.2.x)
Display: VGA std or virtio-gpu
Firmware: OVMF (UEFI)
```

### WiFi Hardware State (Last Known)

```
GP_CNTRL = 0x08040005
  ├── RF_Kill_SW = false (radio enabled)
  ├── MAC_CLOCK_READY = true
  └── INIT_DONE = true

HW_REV = 0x00000351
MAC = b7:65:e2:c8:10:b0
Firmware = iwlwifi-Qu-b0-hr-b0-77.ucode (1,406,572 bytes)
Bootstrap = SUCCEEDED (ALIVE handshake confirmed)
```

---

## 39. Module Inventory

### Kernel Source Tree (~225 files)

```
kernel/src/
├── main.rs              — Entry point, boot sequence
├── boot/mod.rs          — Limine adapter, BootInfo
├── serial.rs            — UART 16550
├── gdt.rs               — GDT/TSS (BSP + per-AP)
├── interrupts.rs        — IDT, exception/IRQ handlers, MSI
├── cpu_init.rs          — CPUID, SSE/AVX/FMA/XSAVE
├── smp.rs               — AP wakeup, per-CPU init
├── pic.rs               — 8259 PIC
├── pit.rs               — 8253/54 PIT
├── apic.rs              — Local APIC + I/O APIC
├── rtc.rs               — MC146818 RTC
├── acpi.rs              — ACPI tables (RSDP/MADT)
├── intc.rs              — PIC vs APIC abstraction
├── memory.rs            — PMM, VMM, heap root
├── memory/
│   ├── pmm.rs           — Bitmap frame allocator
│   ├── vmm.rs           — Page table management
│   ├── heap.rs          — Linked-list heap (256MB-2GB)
│   ├── tensor_buffer.rs — Zero-copy tensor buffers
│   ├── vko_mapper.rs    — Demand-paged model tiles
│   ├── vko_prefetch.rs  — Tile prefetch engine
│   ├── vko_evictor.rs   — Cold page evictor
│   ├── vko_io_queue.rs  — VKO I/O request queue
│   └── kv_demand.rs     — KV cache demand paging
├── dma.rs               — 64MB DMA bump allocator
├── iommu.rs             — Intel VT-d
├── scheduler.rs         — Per-CPU cooperative/preemptive
├── process.rs           — Process slots, FD table, capabilities
├── syscall.rs           — 28 syscalls including AI-native ops
├── syscall_gate.rs      — SYSCALL/SYSRET MSR setup
├── security.rs          — SSP, KASLR, RDRAND, entropy
├── determinism.rs       — Reproducible execution enforcement
├── signal.rs            — POSIX-like signals
├── hal/
│   ├── pci.rs           — PCI config space, BAR, MSI/MSI-X
│   ├── storage.rs       — Block device detection
│   ├── usb.rs           — USB HAL wrapper
│   └── manager.rs       — NEXUS device manager
├── pcie/
│   ├── config.rs        — ECAM config access
│   ├── enumerate.rs     — BFS device discovery
│   ├── capability.rs    — PCIe capability parsing
│   ├── bar.rs           — BAR management
│   └── device.rs        — Device abstraction
├── drivers/
│   ├── battery.rs       — ACPI EC battery
│   ├── ide.rs           — Legacy IDE/ATA
│   └── usb/
│       ├── xhci.rs      — xHCI USB 3.0
│       ├── ehci.rs      — EHCI USB 2.0
│       ├── msc.rs       — Mass Storage Class
│       ├── scsi.rs      — SCSI commands
│       └── fat32_scanner.rs — GGUF file discovery
├── nvme/
│   ├── mod.rs           — Controller init, polled I/O
│   ├── regs.rs          — NVMe register definitions
│   ├── queue.rs         — Submission/Completion queues
│   ├── command.rs       — NVMe command building
│   └── identify.rs      — Controller/Namespace identify
├── gpu/
│   ├── core.rs          — Vendor-agnostic GPU discovery
│   ├── intel.rs         — Gen9/11/12 GPGPU_WALKER dispatch
│   ├── virtio.rs        — VirtIO-GPU backend
│   ├── virtio_compute.rs — virgl 3D + TGSI
│   ├── vram.rs          — VRAM allocator
│   ├── queue.rs         — GPU DMA ring buffers
│   ├── backend.rs       — GpuBackend trait
│   └── regs.rs          — NVIDIA register defs
├── net/
│   ├── wifi.rs          — WiFi state machine
│   ├── iwlwifi.rs       — Intel WiFi PCIe driver
│   ├── stack.rs         — smoltcp TCP/IP
│   ├── nano_stack.rs    — Zero-alloc minimal TCP
│   ├── virtio.rs        — VirtIO-net
│   ├── virtio_zc.rs     — VirtIO zero-copy
│   ├── loopback.rs      — Loopback device
│   └── irpc.rs          — Inter-node RPC bridge
├── fs/
│   ├── vfs.rs           — Virtual file system
│   ├── mbr.rs           — MBR partition table
│   ├── gpt.rs           — GPT partition table
│   └── detect.rs        — Filesystem detection
├── fat.rs               — FAT32 driver
├── storage.rs           — Block device traits
├── gfx/
│   ├── framebuffer.rs   — Raw FB, Color, ClipRect
│   ├── double_buffer.rs — Back-buffer + dirty rects
│   ├── compositor.rs    — Main loop, 15 modes
│   ├── painter.rs       — Obsidian palette + drawing API
│   ├── font.rs          — 3×5 mini font
│   ├── text_engine.rs   — IBM VGA 8×16
│   ├── atticus.rs       — Light theme
│   ├── atticus_design.rs — Design constants
│   ├── atticus_components.rs — Header/Dock
│   ├── atticus_renderer.rs   — Rendering helpers
│   ├── atticus_compositor.rs — Dirty-rect compositor
│   ├── ui_system.rs     — Window manager
│   ├── global_console.rs — F1 debug overlay
│   ├── boot_console.rs  — Boot-time display
│   ├── widgets.rs       — Widget abstraction
│   └── ...              — ~15 more rendering modules
├── input/
│   ├── keyboard.rs      — PS/2 keyboard, scan codes
│   ├── mouse.rs         — PS/2 mouse, relative mode
│   ├── events.rs        — Event types
│   ├── routing.rs       — Event dispatch
│   ├── lockfree_queue.rs — Lock-free key queue
│   ├── global_keys.rs   — Centralized keybinding registry
│   └── advanced.rs      — Gestures, macros
├── ml/
│   ├── ops.rs           — Matmul, add, relu, dot, scale
│   ├── norm.rs          — RMSNorm, LayerNorm
│   ├── rope.rs          — Rotary Positional Embeddings
│   ├── activation.rs    — Softmax, SiLU, SwiGLU, GELU
│   ├── attention.rs     — Multi-head causal self-attention
│   ├── transformer.rs   — Llama-style transformer
│   ├── tokenizer.rs     — BPE tokenizer
│   ├── inference.rs     — End-to-end pipeline
│   ├── gguf.rs          — GGUF V3 parser
│   ├── gemm.rs          — GEMM (scalar + AVX2)
│   ├── quant.rs         — K-Quant dequantization
│   ├── router.rs        — GPU ↔ CPU dispatch
│   └── profiler.rs      — RDTSC profiler
├── ai/
│   ├── fabric.rs        — AI subsystem framework
│   ├── engine.rs        — Model engine (forward pass)
│   ├── qos.rs           — QoS scheduler
│   ├── controller.rs    — AI controller
│   ├── model_scanner.rs — Model discovery
│   ├── neural_scheduler.rs — Neural scheduling
│   ├── ingest.rs        — Model ingest engine
│   └── ...
├── apps/
│   ├── desktop_obsidian.rs    — Main desktop shell
│   ├── dashboard_obsidian.rs  — Neural telemetry
│   ├── settings.rs            — 10-tab settings
│   ├── command_control.rs     — GGUF model manager
│   ├── pipeline_view.rs       — AI chat interface
│   ├── editor_view.rs         — Text editor
│   ├── explorer_view.rs       — File browser
│   ├── system_monitor.rs      — Hardware telemetry
│   ├── hardware_lab.rs        — PROJECT X-RAY
│   ├── silicon_lab.rs         — GPU EU fuzzer
│   ├── wifi_popup.rs          — WiFi overlay
│   └── ...
├── amp.rs               — Core 0↔Core 1 IPC
├── prompt_input.rs      — AI prompt bar
├── model_manager.rs     — 8-slot model lifecycle
├── inference_gateway.rs — TCP:8080 MaaS
├── pipeline.rs          — IO→Tensor zero-copy
├── thermal.rs           — PID thermal governor
├── async_rt.rs          — Cooperative async runtime
├── runtime.rs           — INTERACTIVE/BENCHMARK/SERVICE
├── debug/
│   ├── telemetry.rs     — Global metrics
│   ├── logger.rs        — In-memory log ring
│   └── crash_log.rs     — Flight recorder
└── ...                  — ~30 more supporting modules
```

---

## 40. Runtime Modes

AetherOS supports three execution modes selected at boot:

| Mode | Description | Behavior |
|------|-------------|----------|
| **INTERACTIVE** | Normal desktop operation | Full UI, all IRQs, keyboard/mouse |
| **BENCHMARK** | Deterministic measurement | No keyboard/mouse IRQs, noise budget tracking, pre-touched memory |
| **SERVICE** | Headless inference appliance | No input, TCP:8080 only, minimal rendering |

### Special Boot Configurations

| Feature Flag | Behavior |
|-------------|----------|
| `bench-mode` | Headless, run matmul benchmark, exit |
| `cloud-unikernel` | Super-loop: poll net → compute → render |
| `ci-exit` | Auto-exit after N ticks (for CI testing) |
| `appliance-mode` | Headless inference service |

---

## 41. Development Log & Improvements

### Key Engineering Decisions

1. **Single binary, no_std** — The entire OS is one Rust binary. No dynamic linking, no runtime loader. This ensures deterministic behavior and simplifies debugging.

2. **Ring 0 only (default)** — Running everything in Ring 0 eliminates syscall overhead for AI workloads. User-mode (Ring 3) exists as a feature flag for testing.

3. **Limine over GRUB** — Limine v8.x provides cleaner Rust bindings, simpler configuration, and native UEFI support without GRUB's complexity.

4. **Atomic telemetry everywhere** — Every subsystem exposes its state via `AtomicU32/U64/Bool`. Any thread can read any metric at any time without locking. This powers real-time dashboards and cross-core diagnostics.

5. **Zero-copy tensor path** — NVMe DMA → GGUF parse → QTensor pointer → dequantize in matmul. No intermediate copies. Model weights are read directly from their storage location.

6. **Demand-paged KV cache** — Promise 8+ GiB virtual, allocate physical frames only on page fault. A 128K context window model only uses physical RAM proportional to actual sequence length.

7. **AMP core isolation** — Core 0 handles UI, Core 1 handles ML. No lock contention between rendering and inference. Token IPC via lock-free SPSC ring.

8. **Dual design system** — Obsidian (dark) for runtime, Atticus (light) for analytical modes. Both fully specified with pixel-perfect color tokens, typography scales, and layout grids.

9. **Global Control Keys** — Centralized keybinding registry with 5-level priority (System > Global > Modal > App > Default). Eliminates scattered hotkey handling and enables help screens.

10. **Gen2 TX/RX command queues for WiFi** — Real DMA-based firmware communication instead of PRPH register polling. Proper UMAC scan commands, RX queue for firmware responses.

### Version History Highlights

| Version | Milestone |
|---------|-----------|
| v0.1.0 | Initial boot, framebuffer, serial output |
| v0.2.0 | Tensor syscalls, GGUF parser, USB mass storage |
| v0.2.1 | WiFi driver (iwlwifi), AMP inference, Gen2 TX/RX queues |
| — | SMP (4 CPUs), per-AP GDT/TSS |
| — | Intel iGPU GPGPU_WALKER dispatch |
| — | Demand-paged KV cache, VKO tile streaming |
| — | Obsidian + Atticus dual design system |
| — | Global Control Keys registry (192 slots, 18 apps) |
| — | NVMe polled driver, FAT32 cluster cache |
| — | xHCI USB 3.0 + MSC + SCSI pipeline |
| — | PID thermal governor |
| — | Inference Gateway (TCP:8080 MaaS) |
| — | Silicon Lab GPU EU fuzzer |

### Known Limitations

1. **WiFi scan** — Firmware bootstrap completes, radio online, but UMAC scan times out. Association path not implemented.
2. **GPU compute** — EU execution PROVEN (0xDEADBEEF magic, GEMV 4/4 correct). Add/RMSNorm/SiLU EU kernels not yet implemented. Lacks proper ISA assembler.
3. **No persistent storage writes** — FAT32/FAT16 are read-only. No journaling filesystem.
4. **Single address space** — All code runs in Ring 0 kernel space by default. Ring 3 smoke test exists behind feature flag.
5. **No audio output** — Intel HDA (8086:02c8) detected and bus-mastered but no codec driver.
6. **No display server protocol** — Applications render directly via Painter API, no windowing abstraction.
7. **AHCI/SATA** — Controller detected but driver is "init placeholder (not implemented)".
8. **Realtek Ethernet** — RTL8168 (10ec:8168) detected but misclassified as VirtioNet. No native Realtek driver.
9. **Process fork/exec** — PID table allocation only. No address space copy, no COW, no FD inheritance.
10. **Inference Gateway** — `init()` sets a bool. No real TCP accept loop. Passive packet dispatch via nano_stack.

---

## 42. Proof Matrix — What Is Real

> **This section is the honest truth about every subsystem.** Each entry is classified by the highest level of verification achieved. Serial logs from the real Intel i3-10110U target hardware serve as evidence:
>
> 1. **Boot Log** (1004 lines) — Hardware bring-up, PCI, NVMe, xHCI full stack, GPU EU proof, WiFi firmware.
> 2. **AETHLOGnew.TXT** (prior inference session) — Full xHCI chain: BIOS handoff → SCSI → FAT32 → 807 MB model load. Token generation at ~426.7B cycles/token.
> 3. **Restore-Point Log** (current working version) — Optimized inference: Fwd≈78.36B cycles/token (5.4× faster). GPU-CPU Q4_K validation, BATCH-DIAG profiling, 96 GPU dispatches/token, FAT16 USB model load, log export.

### Classification Key

| Symbol | Level | Meaning |
|--------|-------|---------|
| ✅ | **HW-VERIFIED** | Confirmed working on real bare-metal hardware via serial log evidence |
| 🟢 | **FUNCTIONAL** | Code is complete and correct, works in QEMU, awaiting bare-metal test |
| 🟡 | **PARTIAL** | Some paths work, others are stubs or incomplete |
| 🔶 | **SCAFFOLDING** | Types/interfaces exist, core logic is TODO or minimal |
| ⬜ | **PLANNED** | Documented intention, no implementation |
| 🚫 | **NOT PRESENT** | Does not exist in codebase |

### Boot & Core

| Status | Subsystem | Serial Log Evidence | Notes |
|--------|-----------|-------------------|-------|
| ✅ | **Limine Boot → Kernel Entry** | `_start (V14 SSE-enabled entry)` | Naked SSE-safe entry point |
| ✅ | **SSE/AVX2/FMA Detection** | `SSE=1 AVX=1 AVX2=1 FMA=1` | CPUID feature detection confirmed |
| ✅ | **GDT + IDT** | `init: gdt`, `init: idt` | Protected-mode tables installed |
| ✅ | **SYSCALL MSRs** | `syscall: MSRs configured` | STAR/LSTAR/FMASK/KERNEL_GS_BASE set |
| ✅ | **Heap Allocator** | `heap: mapped ... (509 MiB)` | linked_list_allocator, real pages |
| ✅ | **DMA Allocator** | `DMA allocator initialized, region: 0x18000000-0x1C000000` | 64 MiB bump allocator |
| ✅ | **Security (SSP)** | `[security] init: OK` | Stack canary active (deterministic in this build) |
| ✅ | **Serial Output** | 1004-line log exists | UART 16550 @ 0x3F8 |
| ✅ | **APIC (LAPIC + IOAPIC)** | `lapic_base=4276092928 ioapic_base=4273995776` | IRQ routing active |
| ✅ | **SMP (4 Cores)** | `4 core(s) online, mask=0xF` | BSP + 3 APs, sequential wake |
| ✅ | **PIT Timer** | `init: pit` | 100 Hz tick source |
| ✅ | **Scheduler** | `init: scheduler` | HLT-based + timer preemption |
| ✅ | **ACPI (MADT)** | LAPIC/IOAPIC addresses extracted | RSDP → RSDT → MADT parsing |
| 🟡 | **ACPI (FADT/DSDT)** | `No FADT found (ACPI table missing)` | Only MADT parsed; FADT/DSDT not walked |

### Input & Display

| Status | Subsystem | Serial Log Evidence | Notes |
|--------|-----------|-------------------|-------|
| ✅ | **Framebuffer** | `screen 1920x1080 pitch=7680 bpp=4 format=BGR` | Limine framebuffer, real hardware |
| ✅ | **Double Buffering** | `double-buffer allocation successful` (2×8 MiB) | Zone A allocation, dirty-rect present() |
| ✅ | **Compositor** | `compositor initialized in Desktop mode` + `entering compositor main loop` | 15 modes, 12+ render paths |
| ✅ | **Text Engine** | `Initialized: width=1920, scale=2x` | HiDPI 2x scaling |
| ✅ | **PS/2 Keyboard** | IRQ1 handler in IDT | Real scancode parsing |
| ✅ | **PS/2 Mouse** | `PS/2 relative mode initialized, resolution set to 1920x1080` | 3-byte packet parser, real IRQ12 |
| ✅ | **UI Windows** | `Explorer window created`, `Task Manager window created` | Real pixel rendering |
| ✅ | **Global Control Keys** | F1-F11 mode switching via compositor | 192-slot registry, priority dispatch |
| ✅ | **Desktop App** | Renders nav panel, header, dock, clock, menu | Full Obsidian theme |
| ✅ | **Settings App** | 10-tab interactive settings | Reads real system state |
| ✅ | **Neural Dashboard** | Live telemetry visualization | Sparkline graphs |
| 🟢 | **All Other Apps** | Render functions exist, tested in QEMU | Not individually verified on HW |

### Hardware Drivers

| Status | Subsystem | Serial Log Evidence | Notes |
|--------|-----------|-------------------|-------|
| ✅ | **PCI Enumeration** | `pci_devices=18` | Legacy I/O, all 18 devices on i3-10110U found |
| ✅ | **NEXUS Device Manager** | `Matched 18 device(s) to drivers` + full handshake | Driver injection pipeline proven |
| ✅ | **xHCI USB 3.0** | `NOOP SUCCESS`, `COLD RESET SUCCESS`, `Endpoints configured` | Full init: BIOS handoff, slot enable, address device, bulk endpoints |
| ✅ | **USB Mass Storage** | `SanDisk Cruzer Blade 29340 MB`, `SCSI Transport Ready` | INQUIRY, Read Capacity, MSC class |
| ✅ | **USB Port Reset** | Ports 2,7,9 all cold-reset to PED=1 PLS=U0 | MICROSCOPE + BLACK BOX forensics |
| ✅ | **USB DMA** | `DCBAA[0] MATCH (OK)`, `SILICON-FIST: Command ring OK!` | 65 scratchpad buffers, DMA coherency verified |
| ✅ | **NVMe** | `KBG40ZNT256G TOS`, `nvme: init OK (admin + io queue)` | Full controller init, admin + I/O queue |
| ✅ | **NVMe GPT Parsing** | `GPT Disk GUID: 5BC703EA...`, 12 partitions found | ChromeOS-style partition layout |
| ✅ | **FAT16 (NVMe)** | `FAT16: fat_start=102404 root_dir_start=102660` | EFI system partition mounted |
| ✅ | **FAT32 (USB)** | `USB0: FAT32 (USB_DRIVE)`, root dir 6 entries listed | Full cluster chain traversal |
| ✅ | **VFS Auto-Mount** | `3 filesystem(s) mounted` | NVMe FAT16 + USB FAT32 + RamFS |
| ✅ | **iwlwifi Init** | `Wi-Fi 6 AX201 (CNVi)`, `BAR0: phys=0xb1318000` | PCI probe, BAR map, HW_REV, MAC OTP |
| ✅ | **iwlwifi Firmware Bootstrap** | `FIRMWARE BOOTSTRAP COMPLETE — RADIO ONLINE` | 4 phases: APMG → DMA upload → ALIVE → NVM |
| ❌ | **iwlwifi Scan** | `Scan timeout — no results received` | Command sent but no response from firmware |
| 🔶 | **iwlwifi Association** | — | Not implemented. connect() returns "auth/assoc command path is not implemented" |
| ❌ | **AHCI/SATA** | `ahci: init placeholder (not implemented)` | Controller found (8086:02d3) but no driver |
| ❌ | **Intel HDA Audio** | Bus-mastered (8086:02c8) but no codec driver | Detected only |
| ❌ | **Realtek RTL8168** | `10ec:8168 => VirtioNet (Ethernet)` | **BUG: Misclassified.** No Realtek driver. |
| 🟡 | **IOMMU (VT-d)** | `Skipping compute domain (IOMMU not available)` | Register reading code exists but VT-d not exposed by BIOS on this laptop |
| 🟢 | **Thermal (MSR)** | Code reads MSR 0x19C/0x1A2/0x198/0x611 | PID governor implemented. Silent during boot (no serial output). **NEEDS LOG HOOK** |
| 🟡 | **Battery/ACPI EC** | `EC status: 0x40`, `AC=disconnected`, `present=false` | EC port probe works; FADT-based detection missing; laptop may have no battery in test config |

### GPU Compute

| Status | Subsystem | Serial Log Evidence | Notes |
|--------|-----------|-------------------|-------|
| ✅ | **Intel iGPU Probe** | `device_id=0x9b41 gen=Gen9 BAR0=0xb0000000 (16384KB)` | BAR0 + BAR2 (256 MB aperture) mapped |
| ✅ | **RCS Ring Buffer** | `RCS_RING_CTL = 0x00003001 (enabled=true)`, `RCS liveness test PASSED` | 16 KB ring, GGTT-backed |
| ✅ | **ForceWake** | `FW_ACK: GT=1 Render=1 Media=1` | All 3 domains acquired |
| ✅ | **PPAT + GGTT** | `PPAT programmed`, `GGTT PTE[8192] valid=true` | WB+LLC, WC, WT, UC policies |
| ✅ | **Logical Ring Context** | `LRC allocated: 80KB`, `EXECLIST_ENABLE=true`, `PPGTT active` | 20-page LRC with per-process PPGTT |
| ✅ | **EU Execution Proof** | `★ VICTORY: EU EXECUTION PROVEN ★`, `eu_magic=0xdeadbeef` | Fence arrived + 0xDEADBEEF at sync_page[0] |
| ✅ | **GPGPU_WALKER** | `WALKER EXEC CYCLES: 74` | 74 GPU cycles for dispatch+fence |
| ✅ | **GPU GEMV (8×8)** | `out[0]=1.0 out[1]=2.0 out[2]=3.0 out[3]=36.0 ★ SUCCESS` | Matrix-vector multiply verified on real GPU |
| ✅ | **Hybrid Router** | `GPU dispatches: 5, CPU dispatches: 1` (test), `96 dispatches/token, fence_avg=812.8M` (inference) | GPU-preferred with CPU fallback. During inference: 96 GPU dispatches per token, fence_avg≈812.8M cycles. BATCH-DIAG confirms consistent dispatch across all tokens. |
| ✅ | **Dequant Q8_0** | `dq[0]=1.0 dq[31]=32.0` | Correct dequantization |
| ✅ | **Dequant F16** | `f16[0..4] = [1.0, 2.0, 0.5, -1.0]` | F16C hardware conversion |
| ✅ | **Dequant Q4_K** | `q4k[0..4] = [5.0, 5.0, 5.0, 5.0]` | K-quant block decode |
| ✅ | **All K-Quant Formats** | `Q4_0=YES Q8_0=YES Q2_K-Q8_K=YES BF16=YES F16=YES F32=YES` | 11 quantization formats supported |
| ✅ | **AVX2+FMA+F16C** | `AVX2+FMA+F16C detection: AVAILABLE` | SIMD acceleration confirmed |
| ❌ | **GPU Add Kernel** | `Test3 GPU Add: dispatched=false result=FAIL` | EU kernel not implemented |
| ❌ | **GPU RMSNorm Kernel** | `Test4 GPU RMSNorm: dispatched=false result=FAIL` | EU kernel not implemented |
| ❌ | **GPU SiLU Kernel** | `Test5 GPU SiLU: dispatched=false result=FAIL` | EU kernel not implemented |
| 🟢 | **VirtIO-GPU** | `No VirtIO-GPU found` (correct on bare metal) | Works in QEMU with virgl, not applicable on HW |

### ML / AI Pipeline

| Status | Subsystem | Serial Log Evidence | Notes |
|--------|-----------|-------------------|-------|
| ✅ | **MatMul Verification** | `Phase 1: MatMul PASSED` | Scalar + AVX2 GEMM |
| ✅ | **Persistence Round-Trip** | `Phase 2: Persistence PASSED` | Tensor serialize/deserialize |
| ✅ | **ML Engine Pipeline** | `Phase 3: ML Pipeline PASSED — real math verified` | Forward pass, softmax, sampling |
| ✅ | **Model Fabric** | `Model Fabric initialized (budget: 512 MB)` | VKO tile mapper, 1024 MiB window |
| ✅ | **VKO Prefetch** | `vko-prefetch daemon spawned (chunk=128K, depth=32)` | Async prefetch with MDTS-safe reads |
| ✅ | **VKO Evictor** | `vko-evictor daemon spawned (trail=4)` | LRU page eviction |
| ✅ | **GGUF File Visible** | `Llama-3.2-1B-Instruct-Q4_K_M.gguf FILE 807694368B` | 807 MB model on USB drive |
| ✅ | **Neural Compute Pool** | `2 worker cores` | Cores 2+3 as pool workers |
| ✅ | **AMP Core 1** | `Core 1 = inference master, 2 pool workers` | SPSC token ring, TLB sync |
| ✅ | **Full Model Load** | `LOADED "Llama-3.2-1B-Instruct-Q4_K_M.gguf" — 100%`, `Model load COMPLETE — ready for inference` | **HW-VERIFIED (Restore-Point Log).** GGUF V3 parsed (147 tensors, 36 KV), vocabulary 128,256 tokens, tokenizer built (BOS=1, EOS=2), KV cache 128 MiB demand-paged, 16 layers × 2048 ctx. CRC=0x1B186177, adaptive I/O ≈384 KB chunks. |
| ✅ | **Token Generation** | `Compute: prompt="ping pong" max=128 temp=0.20` | **HW-VERIFIED (Restore-Point Log).** Prompt "ping pong" → token generation active. Per-token profiler: Fwd≈78.36B cycles, Attn≈15.18B, FFN≈63.02B, Norm≈384K, Alloc≈36c, Embed≈14.9K, LMH≈141M. 5.4× faster than prior build. |
| ✅ | **Hybrid Inference Dispatch** | `BATCH-DIAG: dispatches=96, fence_avg=812.8M` | **HW-VERIFIED (Restore-Point Log).** 96 GPU dispatches per token (16 layers × 6 matmul ops). Fence avg ≈ 812.8M cycles/dispatch. Consistent across all tokens. |
| ✅ | **Transformer Forward** | Profiler tokens 1/25 logged, BATCH-DIAG per-token | **HW-VERIFIED (Restore-Point Log).** Full 16-layer forward pass with attention, FFN, RMSNorm, RoPE, embedding, LM head, sampling — all running on real hardware. |
| ✅ | **BPE Tokenizer** | `GgufTokenizer: vocab=128256, max_tok_len=256, BOS=1, EOS=2, space=U+0120` | **HW-VERIFIED.** GGUF vocabulary extraction + merge-based encoding on real hardware. |
| ✅ | **Q4_K GPU-CPU Validation** | `maxDiff=0.000016@168` (2048×2048), `0.000019@425` (512×2048), `0.000000@156`, `0.000003@7298` | **HW-VERIFIED (Restore-Point Log).** GPU and CPU produce identical Q4_K dequant+matmul results across all matrix dimensions. Sub-0.00002 max divergence. |
| ✅ | **Log Export to USB** | `Log export to USB requested...` | **HW-VERIFIED.** Log file written to USB disk-on-key, proving FAT write path works. |
| 🔶 | **Inference Gateway** | `Inference Gateway initialized on port 8080` | init() sets atomic bool. No real TCP listener. No network backend on bare metal. |

### Network

| Status | Subsystem | Serial Log Evidence | Notes |
|--------|-----------|-------------------|-------|
| ✅ | **smoltcp Loopback** | `tcp_rx_len=24`, `cloud_reply_len=21`, `udp_loopback: 256 iterations OK` | Loopback device only |
| 🟢 | **smoltcp + VirtIO** | Works in QEMU | Real packet I/O, but requires VirtIO NIC (not present on bare metal) |
| 🟢 | **nano_stack** | Real TCP/IP/ARP parser | Packet processing code complete, needs VirtIO NIC |
| ❌ | **Bare-Metal Networking** | `VirtIO-Net ZC not found` | **No network on real hardware.** Realtek RTL8168 has no driver. |
| 🔶 | **WiFi Data Plane** | — | Firmware loads but no association, no data frames |

### Process & Userspace

| Status | Subsystem | Serial Log Evidence | Notes |
|--------|-----------|-------------------|-------|
| ✅ | **Syscall Gate** | `syscall: MSRs configured` | SYSCALL/SYSRET, trap frame save/restore |
| 🟢 | **Syscall Dispatcher** | ~25 handlers implemented | EFAULT/EINVAL/EPERM returns |
| 🟡 | **Ring 3 Smoke** | Behind `#[cfg(feature = "ring3-smoke")]` | ELF loading + SYSRET works, no IRQs in usermode |
| 🔶 | **Process fork/exec** | — | PID allocation only. No address space copy, no COW, no FD table. |
| 🔶 | **Multi-process** | 16-slot process table | State tracking exists, no real isolation |

### Simulation / Demo Components

These subsystems produce output but are **not connected to real hardware/networks**:

| Subsystem | What It Actually Does |
|-----------|----------------------|
| **Traffic Simulator** | `sim: Background simulation STARTED` — generates fake model request load for Neural Dashboard metrics |
| **WiFi Sim Mode** | When no WiFi adapter: fakes `HAS_ADAPTER=true`, `report_connected()` with no real radio |
| **Cloud RPC Demo** | smoltcp loopback UDP — no real network involved |
| **Net Stress Test** | loopback only, `884936` cycles for 256 iterations |

---

### Subsystem Readiness Summary

```
BOOT & CORE          ████████████████████ 100%  HW-VERIFIED
INPUT & DISPLAY      ████████████████████  95%  HW-VERIFIED (all apps not individually tested on HW)
PCI / NEXUS          ████████████████████ 100%  HW-VERIFIED
USB (xHCI + MSC)     ████████████████████ 100%  HW-VERIFIED (DMA, SCSI, FAT32 from USB)
NVMe                 ████████████████████ 100%  HW-VERIFIED (admin+IO queues, GPT, FAT16)
FILESYSTEMS          ██████████████████░░  90%  HW-VERIFIED read; write NOT implemented
GPU DISPATCH         ██████████████████░░  85%  HW-VERIFIED (EU+GEMV proven; Add/RMSNorm/SiLU missing)
GPU DEQUANT          ████████████████████ 100%  HW-VERIFIED (all 11 formats)
WiFi                 ██████░░░░░░░░░░░░░░  30%  FW bootstrap OK, scan TIMEOUT, assoc NOT impl
ML MATH              ████████████████████ 100%  HW-VERIFIED (matmul, pipeline, AVX2)
ML END-TO-END        ████████████████████ 100%  HW-VERIFIED (model load + token gen + GPU hybrid dispatch)
NETWORK (bare metal) ░░░░░░░░░░░░░░░░░░░░   5%  No driver for Realtek RTL8168
NETWORK (QEMU)       ████████████████░░░░  80%  VirtIO-net + smoltcp + nano_stack works
AHCI/SATA            ░░░░░░░░░░░░░░░░░░░░   0%  Placeholder only
AUDIO                ░░░░░░░░░░░░░░░░░░░░   0%  HDA detected, no codec driver
PROCESS MODEL        ██░░░░░░░░░░░░░░░░░░  10%  PID table only, no isolation
IOMMU                ██████░░░░░░░░░░░░░░  30%  Register read code exists, not available on test HW
THERMAL              ████████████████░░░░  80%  MSR code real, PID governor real, NEEDS serial log hook
BATTERY/POWER        ████████░░░░░░░░░░░░  40%  EC probe works, FADT missing, no battery in test config
```

---

## 43. Benchmarks & Performance

### What We Know (From Serial Log)

These numbers are **measured on real hardware** (Intel i3-10110U, 2036 MiB RAM):

| Metric | Value | Source |
|--------|-------|--------|
| **CPU Cores Online** | 4 (BSP + 3 APs) | SMP init log |
| **Heap Available** | ~509 MiB | Memory init log |
| **DMA Region** | 64 MiB (0x18000000–0x1C000000) | DMA init log |
| **Framebuffer** | 1920×1080, 32bpp, BGR, pitch=7680 | Framebuffer init log |
| **Double Buffer** | 2 × 8 MiB = 16 MiB | Zone A allocation |
| **PCI Enum** | 18 devices discovered | PCI scan |
| **USB Port Cold Reset** | ~7 ms per port | MICROSCOPE timestamps |
| **xHCI NOOP Latency** | 0–3 ms (4 NOOPs) | SILICON-FIST timestamps |
| **USB SanDisk Capacity** | 29,340 MB (60,088,320 blocks) | SCSI Read Capacity |
| **NVMe Model** | KBG40ZNT256G TOSHIBA | NVMe identify |
| **NVMe Partitions** | 12 (GPT, ChromeOS layout) | GPT parser |
| **USB Root Dir** | 6 entries listed | FAT32 dir traversal |
| **GPU EU Dispatch** | 74 cycles (GPGPU_WALKER) | `Time Before/After Walker` delta |
| **GPU GEMV 8×8** | 4/4 outputs correct | Hybrid compute test |
| **GPU Hybrid Dispatches** | 5 GPU + 1 CPU in test suite | Router stats |
| **GPU Hybrid (Inference)** | **96 GPU dispatches/token**, fence_avg≈812.8M cycles | Router stats (Restore-Point Log) — BATCH-DIAG confirms consistent dispatch per token |
| **Stress Test: Heap Churn** | 87,861,142 cycles | Phase 6 stress |
| **Stress Test: RamFS** | 32 cycles | Phase 6 stress |
| **Stress Test: Net (loopback)** | 884,936 cycles for 256 UDP iterations | Phase 6 stress |
| **WiFi FW Size** | 1,406,572 bytes | iwlwifi firmware |
| **WiFi APMG Init** | ~0 µs (MAC clock ready) | APMG polling |
| **WiFi ALIVE** | ~500 ms (GP_CNTRL poll) | Firmware alive poll |
| **VKO Tile Window** | 1024 MiB virtual, 512 tiles | VKO init |
| **GGUF Model File** | 807,694,368 bytes (Llama-3.2-1B Q4_K_M) | VFS listing |

### Inference Profiler Data (HW-VERIFIED — Restore-Point Log)

> **Source:** Real hardware, Intel i3-10110U, Llama-3.2-1B-Instruct-Q4_K_M (807 MB, Q4_K quantized, 16 layers, dim=2048, vocab=128,256). Prompt: "ping pong", max_tokens=128, temperature=0.20. GPU-preferred hybrid routing. **5.4× faster than prior AETHLOGnew.TXT build.**

| Token | Forward (cycles) | Attention (cycles) | FFN (cycles) | Norm (cycles) | Alloc (cycles) | Embed (cycles) | LM Head (cycles) | Sample (cycles) |
|-------|-----------------|-------------------|--------------|---------------|----------------|----------------|-------------------|-----------------|
| 1 | 78.36B | 15.18B | 63.02B | 383.7K | 36 | 14.9K | 141.08M | 0 |
| 25 | 78.36B | 15.19B | 63.02B | 459.7K | 34 | 13.3K | 141.16M | 0 |

**BATCH-DIAG (per-token GPU dispatch telemetry):**

| Metric | Value | Notes |
|--------|-------|-------|
| **GPU Dispatches/Token** | 96 (first token: 101) | 16 layers × 6 matmul ops = 96 dispatches |
| **CSB Spins/Token** | 48,000 (avg 505/dispatch) | Command Streamer Busy polling |
| **Fence Cycles/Token** | ~78.03B | Total GPU fence wait per token |
| **Fence Avg/Dispatch** | ~812.8M cycles | Per-dispatch GPU execution time |

**Q4_K GPU-CPU Validation (first token):**

| Matrix | Dimensions | GPU Output | CPU Output | Max Diff | Position |
|--------|-----------|-----------|-----------|----------|----------|
| #0 | 2048×2048 | [0.6794, -0.3416, 1.9964, -1.3588] | [0.6794, -0.3416, 1.9964, -1.3588] | 0.000016 | @168 |
| #1 | 512×2048 | [3.7715, 1.7499, 2.8350, 2.7473] | [3.7715, 1.7499, 2.8350, 2.7473] | 0.000019 | @425 |
| #2 | 2048×2048 | [-0.0134, 0.0086, -0.0379, -0.0044] | [-0.0134, 0.0086, -0.0379, -0.0044] | 0.000000 | @156 |
| #3 | 8192×2048 | [-0.1125, -0.0671, -0.0127, -0.0299] | [-0.1125, -0.0671, -0.0127, -0.0299] | 0.000003 | @7298 |

**Key observations:**
- **5.4× faster than prior build**: 78.36B vs 426.69B cycles/token — major optimization
- **Forward pass is stable**: Token 1 and Token 25 both at 78.36B — highly deterministic
- **FFN dominates ≈ 80.4%** of forward, **Attention ≈ 19.4%** — GPU dispatch optimization reduced attention overhead
- **Norm overhead ≈ 0.0005%** — negligible (RMSNorm is lightweight)
- **Allocation overhead: 34–36 cycles** — near-zero; slab allocator hot path
- **Embedding lookup: 13–15K cycles** — token ID → vector fetch
- **LM Head: ~141M cycles** — final vocab-size projection (128,256 outputs)
- **Sampling: 0 cycles** — greedy at temp=0.20 (argmax fast path)
- **GPU-CPU agreement: < 0.00002** across all matrix dimensions — proves GPU compute is numerically correct
- **96 dispatches/token at ~812.8M cycles each** — the GPU fence wait dominates; optimization target is dispatch overhead

### USB Model Load Chain (HW-VERIFIED — Restore-Point Log)

> **Source:** Real hardware, USB disk-on-key with Llama-3.2-1B GGUF model. FAT filesystem, adaptive I/O streaming.

| Stage | Evidence | Detail |
|-------|----------|--------|
| **Volume Scan** | `scan_all_models: 3 volumes to scan` | NVMe FAT16 + USB0 + RamDisk |
| **USB Discovery** | `Volume "/usb0" (USB0) -> 1 results` | USB volume mounted and readable |
| **Model Found** | `MODEL: "Llama-3.2-1B-Instruct-Q4_K_M.gguf" size=807694368` | 807 MB model file on USB |
| **Cache Diagnostics** | `virt→phys WB (Write-Back) ✓`, `MTRR default WB — tensor memory cached ✓` | Memory caching optimal for tensor data |
| **FAT Pre-Resolve** | `FAT pre-resolve OK: cluster=143 size=807694368` | FAT cluster chain resolved |
| **Adaptive I/O** | `Chunk Size = 384 KB` (typical), range 256–512 KB | Auto-tuned based on read latency (~82–130K µs/chunk) |
| **Streaming** | `25%`, `50%`, `75%` progress, `EOF at offset 807694368` | Full 807 MB streamed to RAM |
| **CRC Verification** | `CRC: 0x1B186177 (807694368 bytes, 0 errors)` | Zero corruption — data integrity proven |
| **GGUF Parse** | `Header: V3, 147 tensors, 36 metadata KV` | Full model structure parsed from RAM |
| **Fabric Load** | `Registered+Loaded in one shot: 809500672 bytes` | Model fabric registration complete |
| **Engine Build** | `Core 1: model detected, building engine...` → `LOADED — 100%` | Full model → engine pipeline |
| **Log Export** | `Log export to USB requested...` | Write path to USB verified |

> **Note:** The full xHCI boot stack (BIOS handoff → port reset → SCSI → FAT32 mount) was verified in AETHLOGnew.TXT (prior build). The restore-point log uses the same USB hardware path but the detailed xHCI boot messages are elided in this log capture.

**End-to-end chain:** Pipeline click → Volume scan → FAT pre-resolve → Adaptive I/O streaming (807 MB, ~384 KB chunks) → CRC verification → GGUF V3 parse → Fabric load → Engine build → Tokenizer ready → Prompt submit → Token generation → Log export to USB.

### What We Don't Know Yet (Needs Instrumentation)

These metrics **can be measured** by adding a few RDTSC log lines. After adding them, boot the OS, capture the serial log, and provide it to update this document.

| Metric | How to Measure | Where to Add Code |
|--------|---------------|-------------------|
| **Boot Time (total)** | RDTSC at `_start` and at `BOOT COMPLETE` | `main.rs` lines ~1 and ~end of init |
| **Boot Time (per-phase)** | RDTSC before/after each `Phase N:` message | `main.rs` at each phase boundary |
| **Model Load Latency** | RDTSC around VKO tile mapping + GGUF parse | `ml/model_manager.rs` load path |
| **Tokens/sec** | RDTSC per token in `inference.rs` decode loop | Already instrumented — needs model to be loaded |
| **Prefill Latency** | RDTSC around prefill phase | Already instrumented in `inference.rs` |
| **Per-Token Decode** | RDTSC per decode step | Already instrumented in `profiler.rs` |
| **Memory Overhead** | Log heap stats before/after model load | `allocator.rs` stats |
| **Latency Variance** | Min/max/stddev of per-token cycles | `profiler.rs` accumulators exist, need min/max tracking |
| **Framebuffer Present** | RDTSC around dirty-rect copy | `double_buffer.rs` present() |
| **Thermal (CPU Temp)** | Log MSR 0x19C reading at boot | `thermal.rs` — add serial_println in tick() |
| **NVMe Read Latency** | RDTSC around block read | `nvme/mod.rs` read path |
| **USB Bulk Transfer** | RDTSC around bulk_transfer() | `xhci.rs` — already has TELEMETRY hooks |
| **Scheduler Tick** | RDTSC in on_timer_tick() | `scheduler.rs` timer handler |

### Existing Instrumentation (Ready to Capture)

The following profiling infrastructure **already exists** in code and will produce data once inference runs:

```
profiler.rs:
  ALLOC_CYCLES      — heap allocation time per token
  ATTN_CYCLES       — multi-head attention time per token  
  FFN_CYCLES        — feed-forward network time per token
  NORM_CYCLES       — RMSNorm time per token
  EMBED_CYCLES      — token embedding lookup time
  LM_HEAD_CYCLES    — language model head (final projection)
  SAMPLE_CYCLES     — top-k/top-p sampling time
  FORWARD_CYCLES    — total forward pass time per token

telemetry.rs:
  latency_histogram  — 16-bucket histogram of request latencies
  tps_samples        — rolling tokens-per-second window
  memory_samples     — memory usage timeline
  error_count        — cumulative error counter
```

### What Cannot Be Measured (Unknown Until Implemented)

| Metric | Blocker |
|--------|---------|
| **WiFi Throughput** | Scan times out; association not implemented; no data plane |
| **Ethernet Throughput** | No Realtek RTL8168 driver |
| **Disk Write Speed** | FAT32/FAT16 are read-only |
| **Process Context Switch** | No real multi-process support |
| **Ring 3 Syscall Latency** | Ring 3 behind feature flag, no IRQs in usermode |
| **Audio Latency** | No audio driver |
| **GPU Tensor Ops** | Add/RMSNorm/SiLU EU kernels not implemented |
| **IOMMU Overhead** | VT-d not available on test hardware BIOS |

### Comparison Framework: AetherOS vs Linux + llama.cpp

> **Status: PARTIALLY MEASURED.** AetherOS inference is now proven with profiler data. Per-token cycle counts are available. Wall-clock tok/s still needs RDTSC-at-start timing. Linux baseline needs to be captured on the same i3-10110U hardware.

| Metric | AetherOS (bare metal) | Linux + llama.cpp (same HW) | Notes |
|--------|----------------------|----------------------------|-------|
| Boot → Ready | ? | ~15–30 sec | AetherOS: RDTSC delta needed |
| Model Load (1B Q4_K_M) | **HW-VERIFIED: loads from USB** | ~2–4 sec | AetherOS: 807 MB via xHCI SCSI, wall-clock TBD |
| Prefill (512 tokens) | ? | ~1–3 sec | AetherOS: profiler ready, needs prompt length test |
| Decode tok/s | **Fwd≈78.36B cycles/tok (96 GPU dispatches)** | ~8–15 tok/s (i3 CPU) | AetherOS: at 2.1 GHz ≈ ~37s/tok. 5.4× faster than prior build. GPU+CPU hybrid. |
| Memory Overhead (OS) | ~16 MiB (framebuffer) + ~32 MiB kernel | ~200–500 MiB | AetherOS: no userspace, no libc |
| Peak RAM (inference) | **~807 MB model + ~128 MiB KV cache** | ~1.2 GB for 1B Q4_K | AetherOS: demand-paged KV, model in HHDM |
| Jitter (tok-to-tok σ) | **< 0.001B cycles (Token 1 vs Token 25)** | ~5–15% | AetherOS: Token 1=78.36B, Token 25=78.36B — near-zero variance |
| GPU Offload | **96 GPU dispatches/token, fence_avg≈812.8M** | llama.cpp has no iGPU support | AetherOS: bare-metal Gen9 GPGPU dispatch |
| GPU-CPU Accuracy | **maxDiff < 0.00002 (Q4_K validation)** | N/A (CPU-only) | AetherOS: GPU+CPU produce identical results |
| Interrupt Latency | ? (APIC direct) | ~1–10 µs | AetherOS: no interrupt nesting/scheduling overhead |

### How to Capture Missing Benchmarks

1. **Add boot timing**: Insert `let boot_start = unsafe { core::arch::x86_64::_rdtsc() };` at top of `_start`, and `serial_println!("BOOT_CYCLES: {}", rdtsc() - boot_start);` at "BOOT COMPLETE" line.

2. **Trigger model load**: The model `Llama-3.2-1B-Instruct-Q4_K_M.gguf` is visible at `/usb0/`. Trigger load from Pipeline app or add `model_manager::load("/usb0/Llama-3.2-1B-Instruct-Q4_K_M.gguf")` after VFS mount.

3. **Capture inference**: Once model loads, Core 1 will run `run_streaming()`. The profiler will emit per-token cycle counts to serial.

4. **Provide serial log**: Boot, let it run 30+ seconds, capture serial output, and provide to update this document with real numbers.

---

## Appendix A: Color Quick Reference

### Obsidian Palette (Dark Theme)

```
Backgrounds:    #0A0F1A  #12171F  #1A1F2B  #242A38
Accents:        #00E5FF  #0091EA  #00E676  #FFB300  #FF5252  #BB86FC
Text:           #FFFFFF  #E8E8E8  #8892A0  #5A6270
Borders:        #2A3140  #0091EA  #1E2530
Heatmap:        #0A2463 → #1E5AA8 → #3D8EE0 → #FFB300 → #FF5252
```

### Atticus Palette (Light Theme)

```
Background:     #FAFAF8
Typography:     #2B2B2B
Accent:         #0E2A48 (Navy — point of focus ONLY)
Separators:     #E5E5E3
Status:         #8B3A3A (error)  #3A8B5E (success)  #3A5E8B (info)
```

---

## Appendix B: Register Quick Reference

### Critical CSR Registers (WiFi)

```
0x000  HW_IF_CONFIG    0x008  INT            0x00C  INT_MASK
0x020  RESET           0x024  GP_CNTRL       0x028  HW_REV
0x03C  GIO_REG         0x050  GP_DRIVER      0x05C  FW_ERROR
0x380  MAC_ADDR0_OTP   0x384  MAC_ADDR1_OTP
```

### APIC Registers

```
LAPIC: 0x20(ID) 0xB0(EOI) 0xF0(SVR) 0x320(LVT_TIMER)
       0x380(INIT_COUNT) 0x390(CURR_COUNT) 0x3E0(DIV)
IOAPIC: 0x00(REGSEL) 0x10(IOWIN)
```

### Intel iGPU Registers

```
0x02030  RCS_RING_TAIL     0x02034  RCS_RING_HEAD
0x02038  RCS_RING_START    0x0203C  RCS_RING_CTL
0x0A188  FORCEWAKE_MT      0x800000 GGTT_PTE_BASE
```

---

*This document is the definitive reference for AetherOS. Every architectural decision, hardware register, color value, and system interface documented here represents the actual state of the codebase. Section 42 (Proof Matrix) distinguishes hardware-verified facts from aspiration — now including end-to-end inference proof (Fwd≈78.36B cycles/token on real hardware with GPU+CPU hybrid dispatch, 5.4× faster than prior build). Section 43 (Benchmarks) includes per-token profiler data, BATCH-DIAG GPU dispatch telemetry, Q4_K GPU-CPU validation, and USB model load chain.*

*v1.2 — Updated from restore-point serial log (April 2026)*

*Last updated: April 2026 — AetherOS Kernel v0.2.1 "Infinite Horizon" — Proof Matrix v1.2*

---

# Part III — Source Integrity, Provenance & Update Record

## Source files used

| Source | Role | SHA256 |
|---|---|---|
| `Pasted markdown(3).md` | Latest attached August 2026 architecture / performance source | `A62A2ACFC131F383EBA7864FD8224F9795D9CF1F69969B7DC1EA71296EF4E9A5` |
| `AETHEROS_IDENTITY.md` | Exhaustive April 2026 43-section identity/reference source | `0DC36CF10F447FF3AD12963F4D861C14A54FDCE7A7967BFA29EDB3C5893797C6` |
| `danielforface/AetherOS-Showcase` | Public GitHub architecture/proof showcase | Git repository; latest observed commit `d88285d41a8db87d25d13b297846e7e1cfa4c549` |

## Current-document reconciliation notes

1. The public GitHub repository is **not treated as the newest technical source** because its latest observed push is June 7, 2026, while the attached architecture document is dated August 2026.
2. The old April proof matrix is preserved for historical traceability, but the August proof matrix is canonical for current GPU/CPU inference qualification.
3. `ROUND18EW` is the **latest round explicitly identified as current in the attached August source**. No later round is asserted here without source evidence.
4. Some older sections describe components as incomplete (for example, early GPU helper kernels, WiFi association, userspace/process behavior). Those statements are retained as historical implementation notes; they should not override newer explicit evidence in Part I.
5. The document intentionally preserves experimental and production-qualified terminology. A speedup observed in a shadow candidate (for example ROUND18DV B=8) is not silently promoted into the canonical production performance number.

## Update stamp

**Last consolidated:** 2026-08-17 14:48 Asia/Jerusalem  
**Canonical kernel identity in this document:** AetherOS v0.3.0 — “Silicon Sovereign”  
**Public showcase:** https://github.com/danielforface/AetherOS-Showcase

---

*End of consolidated AetherOS system reference.*
