# Intel Gen9 Bare-Metal GPGPU Compute

## Overview

AetherOS directly programs the Intel Gen9 Render Command Streamer (RCS), GGTT and GPGPU media pipeline without a conventional host graphics stack in the active inference path.

The verified target is Intel UHD 620 / Comet Lake GT2 (`8086:9B41`). The newest supplied hardware log identifies the backend as **ROUND18FB — Adaptive L2/L3 Cooperative Cache Tiling & Low-Latency GPU Dual-Walker**.

## Command pipeline

```text
PIPELINE_SELECT
  → STATE_BASE_ADDRESS
  → MEDIA_VFE_STATE
  → MEDIA_INTERFACE_DESCRIPTOR_LOAD
  → GPGPU_WALKER
  → MEDIA_STATE_FLUSH
  → PIPE_CONTROL
```

The exact state sequence varies across qualification rounds, but the invariant is that AetherOS constructs and submits the GPU command stream itself.

## Current runtime structures

- RCS ring buffer;
- state heap / interface descriptors;
- synchronization page;
- PPGTT/GGTT mappings;
- GPU-visible model-resident and packed tensor regions;
- completion fences and GPU timestamp telemetry;
- guarded operator publication with per-request audits.

## Latest GGTT residency evidence

The latest FB log directly reports:

```text
GGTT STATIC ZONE EXPLICITLY LOCKED: 147 entries, 195426 pages (781704KB)
```

The model parser reports **147 GGUF tensor descriptors**. This is the newest observed static-model mapping count.

Earlier architecture notes referenced a **260,000-page (~1.01 GiB) residency threshold**. That value should now be treated as an earlier policy/working-set threshold, not as the latest observed static-zone count. Packed GPU caches are allocated in addition to the raw model-resident mappings.

## Packed Q4_K execution

AetherOS uses 2-Octoword / 32-byte packed execution for major Q4_K paths. The runtime logs identify packed layouts such as `AOSOA32_XSUM` / `AOSOA32_1X8OW`, with model-resident packed buffers and explicit cache census.

Design goals remain:

- contiguous weight transport;
- reuse metadata and activations;
- bounded GRF pressure;
- avoid scratch spilling;
- support `K=2048` and `K=8192`;
- keep packed weights resident across repeated decode work.

## QKV triple-walker — latest guarded qualification

ROUND18FB reports:

```text
kernel=ED_W32_2OW_REGION_MULADD
layout=AOSOA32_XSUM
walker=QKV_TRIPLE
selected_variant=79
selected_window=32
production_publish=GUARDED_PER_REQUEST_AUDIT
```

Qualification evidence:

- `q_exact=1`;
- `k_exact=1`;
- `v_exact=1`;
- clean guard state;
- zero mismatches;
- ~**2.201×** speedup versus the factored reference in that qualification harness;
- production promotion remains **guarded**, not unconditional.

Older documentation contains different per-layer QKV timing results from different harness generations. They remain historical evidence rather than being silently replaced by the latest qualification ratio.

## FFN Gate + Up dual-walker

The current production pair path reports:

```text
path=DUAL_RESIDENT_PACKED_XSUM
walkers=2
submissions=1
fences=1
fallback=FACTORED_DUAL_WALKER
```

The pair is certified against two single factored references. Latest full-pair telemetry remains around `12.26M cycles`, with fence cost around `10.71M cycles/pair` and no failures in the observed FB windows.

The large `8192×2048` region remains a leading bottleneck at roughly **28% of decode** in the latest bottleneck census.

## Steady-state cache / restore evidence

In the latest requests:

- Q4 packed cache hits rise into the thousands;
- steady-state misses are zero after initial population in the full-request Q4 baseline;
- `kernel_repairs=0`;
- `l3_repairs=0`;
- `restore_failures=0`;
- GPU fault and recovery deltas remain zero.

This is stronger evidence than simple walker completion: the optimized path is surviving repeated live transformer requests without repair/fallback activity in the captured windows.

## GPU clock evidence

The latest baseline records RCS MMIO GPU timestamps and GT samples at:

```text
gt_min_mhz=1000
gt_avg_mhz=1000
gt_max_mhz=1000
```

for the measured decode windows.

## Correctness contract

GPU speed alone is insufficient. Promotion evidence includes exactness, clean guards, mismatch counters, fault/recovery deltas, restore state and a reference path.

The public evidence vocabulary should distinguish:

- candidate;
- guarded production;
- unguarded production;
- shadow/lab-only.

## Research frontier

The question is no longer whether Gen9 can execute AetherOS compute. The frontier is:

- more useful weight reuse;
- cache-aware tiling;
- lower dispatch/fence cost;
- larger fused graph regions;
- preserving bit-exactness under broader reuse geometries;
- keeping current guarded publication semantics while reducing audit overhead.

See [Latest Real-Hardware State](18-latest-hardware-state.md).
