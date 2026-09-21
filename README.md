# AetherOS — Public Evidence Release v1.1

> **Bare-metal Rust OS / AI runtime for physical x86 hardware**  
> Evidence-first release: physical runs, source/binary provenance, promotion/rejection gates, and inspectable failure lineage.

**Evidence refresh:** 2026-09-21  
**Tested physical GPU:** Intel PCI `8086:9b41` — CML GT2 / Intel UHD Graphics, Gen9-class  
**Reviewed model:** `llama-3.2-1b-instruct-q4_k_m.gguf`  
**Strongest reviewed steady decode point:** **7.0775 tokens/sec** — ROUND18HAR  
**Later physical reproduction:** **~7.08 tokens/sec** — continuous RUN01 laptop recording  
**Evidence status:** internally produced and inspectable; **not** independent third-party certification

---

## What AetherOS is

AetherOS is a Rust `#![no_std]`, x86_64 bare-metal operating system / inference runtime built to explore how much of the LLM execution stack can be owned directly by the OS.

On the reviewed physical machine, AetherOS:

- boots directly on x86 hardware from USB;
- mounts external storage and discovers a GGUF model;
- loads Llama 3.2 1B Instruct Q4_K_M;
- initializes a custom Intel Gen9-class compute backend;
- runs a **hybrid CPU / Intel iGPU** inference path;
- produces live local text generation;
- records detailed physical telemetry for promotion, fallback, exactness and recovery.

The reviewed runtime inference does **not** require a Linux host OS. That statement is about the runtime path, not the development/build workstation or toolchain.

---

## Why this repository exists

The complete AetherOS source tree is not published here.

This repository is a **public evidence and engineering showcase**. Its purpose is to make bounded technical claims reviewable without asking readers to trust project size, screenshots, or authorship rhetoric.

The current release focuses on three representative engineering stories:

1. **ROUND18BY — causal register-corruption proof and repair**
2. **ROUND18DV — a 7.768x local kernel win that was deliberately rejected at E2E**
3. **ROUND18HAR — benchmark protocol corrected before 7.0775 tok/s steady qualification**

Start here:

- [Reviewer start guide](evidence/release-v1.1/REVIEWER_START_HERE.md)
- [Claims and limits](evidence/release-v1.1/CLAIMS_AND_LIMITS.md)
- [Benchmark methodology](evidence/release-v1.1/BENCHMARK_METHODOLOGY.md)
- [Engineering stories](evidence/release-v1.1/ENGINEERING_STORIES.md)
- [Raw evidence manifest](evidence/release-v1.1/RAW_EVIDENCE_MANIFEST.md)
- [104-second RUN01 evidence cut](public-evidence/AETHEROS_RUN01_PUBLIC_DEMO_V1.mp4)

---

## The public performance claim

The preferred public number is:

> **7.0775 decode tokens/sec** in ROUND18HAR's fixed numeric steady qualification for the reviewed Llama 3.2 1B Instruct Q4_K_M configuration.

HAR preserved the slower first request instead of hiding it:

| Request | Generated tokens | Observed TPS |
|---:|---:|---:|
| 1 | 128 | 5.23 |
| 2 | 128 | 7.08 |
| 3 | 128 | 7.08 |
| 4 | 128 | 7.08 |
| 5 | 128 | 7.08 |
| 6 | 128 | 7.08 |
| 7 | 128 | 7.08 |
| 8 | 128 | 7.07 |
| 9 | 128 | 7.07 |

The later RUN01 physical laptop recording reproduces approximately the same ~7.08 tok/s operating point.

RUN01 is a **visual/serial reproduction** of the operating point. HAR remains the stronger controlled numeric qualification.

---

## Evidence before claims

AetherOS uses promotion gates instead of assuming every optimization should ship.

### Exact and faster — still rejected

ROUND18BT completed 120/120 exact control/candidate pairs and measured ~1.1% improvement, but missed the predeclared 2% architecture threshold.

**Result: not promoted.**

### 7.768x local kernel result — still rejected

ROUND18DV reached **7.768x** speedup at B=8 in a controlled Q4 multicolumn weight-reuse experiment while remaining exact.

The complete FFN graph did not improve enough.

**Result: `CORRECT_BELOW_ARCHITECTURAL_GAIN`; not promoted.**

### 15.4% fewer local instructions — still rejected

ROUND18HAS reduced a local paired-convert path from 13,278 to 11,230 dynamic instructions/thread.

Physical gain was only ~1.5–1.8% and did not clear the declared submit/GT gates.

**Result: `promoted=0`; prior HAR-class production path remained live.**

---

## Causal debugging example: ROUND18BY

A cooperative Q4 path contained a deterministic accumulator corruption.

The source audit found that a helper used as a scalar move emitted an SIMD8 write footprint. The final reconstruction write beginning at `r109.3` crossed into `r110.0..2`, where `r110.0` was still a live ROTATE4 accumulator.

The predicted hardware signature was then tested.

**Unsafe reconstruction**

- 2048/2048 threads overwrote `r110.0` with `tile[255]`;
- 0/2048 sentinels survived.

**Exact reconstruction**

- 2048/2048 sentinels survived;
- 0/2048 threads leaked `tile[255]` into `r110.0`.

**Full kernel**

- unsafe version: exactly 2048 mismatches, all `row % 4 == 0`;
- repaired version: **8192/8192 exact**.

The arithmetic repair was still not declared production-qualified because a later fence timeout exposed a separate lifecycle issue.

See [BY evidence](evidence/release-v1.1/BY.md).

---

## Why HAR matters

HAQ exposed real projection gains, but its first-candidate measurement could include one-time code construction/install/flush/readback cost.

HAR changed the **measurement protocol**, not the acceptance threshold:

- one warm-up control/candidate pair, reported separately;
- two measured pairs;
- balanced/reversed order;
- unchanged exactness and promotion thresholds;
- no fastest-sample selection;
- no shadow-output publication.

Only after this correction did the three projection paths qualify.

See [HAR evidence](evidence/release-v1.1/HAR.md).

---

## What this release supports

### Supported

- physical x86 boot into AetherOS;
- external GGUF model discovery/loading;
- live local inference;
- Intel PCI `8086:9b41` compute-device initialization;
- custom Intel Gen9-class backend used in a hybrid CPU/iGPU route;
- source/binary provenance across selected ROUND18 packages;
- physical promotion/rejection gates;
- causal BY register-corruption experiment;
- HAR steady numeric qualification at **7.0775 tok/s** for the tested configuration;
- later RUN01 reproduction at approximately the same ~7.08 tok/s level.

### Not claimed

- pure-GPU inference;
- 100% GPU offload;
- zero-copy GGUF execution directly from USB;
- that dispatch-count percentage equals compute-time percentage;
- 7 tok/s on arbitrary models or hardware;
- independent third-party benchmark certification;
- cross-hardware reproducibility;
- semantic answer-quality certification;
- exact power efficiency;
- measured final-pixel/UI latency;
- that HAS caused the ~7.08 tok/s production result.

RUN01 explicitly reports `vko_zero_copy=false`.

---

## AI-assisted development disclosure

AetherOS uses AI-assisted engineering workflows.

That is disclosed deliberately.

The evidence standard for this repository is therefore not "who typed every line?" It is whether the architecture, changes, failure mechanisms and physical results can be inspected, explained, reproduced and challenged.

Selected evidence includes:

- predecessor/release/rollback kernels;
- source snapshots and diffs;
- SHA256 manifests;
- physical serial logs;
- exactness gates;
- synthetic negative cases;
- compiler / IGA / IGC evidence;
- promotion and rejection records;
- benchmark methodology.

External technical criticism is welcome.

---

## Historical documentation status

The existing `docs/` tree records earlier public snapshots of AetherOS, including the August 2026 ROUND18FB-era state around the ~3 tok/s class.

Those documents remain valuable **historical engineering records**, but they are no longer the authoritative current-performance summary.

For current claims, use this README and `evidence/release-v1.1/`.

Git history preserves the previous public README unchanged.

---

## What I want reviewed

If you are a systems, GPU, compiler, Rust or inference-runtime engineer, the most useful review is narrow and adversarial:

- Does the BY source/log evidence support the claimed causal mechanism?
- Is the DV local-vs-E2E distinction presented correctly?
- Does HAR's measurement protocol justify the 7.0775 tok/s steady claim?
- Are any public statements broader than the evidence supports?

Start at [REVIEWER_START_HERE.md](evidence/release-v1.1/REVIEWER_START_HERE.md).

---

**AetherOS — evidence before claims.**
