# Development & Optimization Lineage

This file summarizes selected milestones that materially changed the public architecture. It is not a complete private round log.

## Early hardware proof

The first public showcase state established bare-metal model loading, Gen9 walker execution, hybrid CPU/GPU inference and end-to-end token generation at roughly `78.36B cycles/token`. That result is historical.

## Cooperative Q4 debugging

### ROUND18BX
A reconstruction investigation isolated a likely register-footprint error in which reconstruction state crossed into a live accumulator register. This shifted the root-cause model away from generic SLM/barrier/fence explanations.

### ROUND18BY
The reconstruction write footprint was repaired and subsequently reported successful.

## Multi-column weight reuse

### ROUND18DV
A shadow experiment exercised Q4 multi-column execution at `B=1/2/4/8` with repeated bit-exact comparison against independent B=1 references.

The B=8 candidate reported **7.768× acceleration** in the experiment while remaining `production_publish=0`. It is evidence for weight reuse, not a 7.768× end-to-end claim.

## Production-performance generation

### ROUND18EL
QKV production generation reached the ~0.8B cycles/token class and established the later packed-Q4 progression.

### ROUND18EO — peak supplied E2E benchmark
Universal Q4_K 2OW packed execution produced the fastest complete clean 128-token request in the supplied logs:

- 586.31M avg cycles/token;
- 37.523738 s decode wall time;
- ~**3.411 tok/s**.

This remains the **peak verified E2E benchmark** in the supplied evidence set.

### ROUND18EW
Zero-spill AVX2 Q6_K, streamlined shift/mask handling and memory prefetch consolidated the later CPU path. Clean 128-token requests were ~612.7–626.1M cycles/token.

## Post-EW architecture rounds

### ROUND18EX
**Fused AVX2 SwiGLU, Lean Q6_K Prefetch & Vectorized Readback.**

The run contains both a clean 128-token request and a later `BASELINE_CORRECTNESS_OR_LIVENESS_FAIL`, with `next=HOLD_ARCHITECTURE_PROMOTION`. It should be documented as an explored generation, not as an unqualified promotion.

### ROUND18EY
**Immediate Multi-Core Q6_K Dispatch & Unified GPU FFN Pipeline.**

Q6 qualification succeeded, but two clean 128-token requests regressed to roughly **1.13B cycles/token**. This is a useful negative result: a locally attractive fusion can worsen end-to-end scheduling/traffic economics.

### ROUND18FA
**Cooperative Cache Tiling & Zero-Stall GPU Dual-Walker.**

Three clean 128-token gates were captured. The best request reached ~612.08M cycles/token, while Q4 logical throughput returned to the ~3.51 GB/s class.

### ROUND18FB — latest supplied hardware state
**Adaptive L2/L3 Cooperative Cache Tiling & Low-Latency GPU Dual-Walker.**

The newest hardware log records:

- two complete clean 128-token requests;
- best full request: **611.48M cycles/token / 39.134811 s / ~3.271 tok/s**;
- a third clean request that ended after 27 tokens;
- zero GPU faults/recoveries in the baseline windows;
- guarded QKV packed-2OW promotion with ~2.201× qualification-harness speedup;
- pinned two-worker Q6_K production with `cert_mask=0x7`, no timeout/fallback/exact failures;
- adaptive cache-tiling generation active in the backend banner.

ROUND18FB is therefore the **latest architecture**, but ROUND18EO remains the **peak E2E benchmark**.

## Architectural lesson

AetherOS performance is governed by data movement, residency, execution geometry and synchronization as much as arithmetic throughput. The recurring successful themes are:

- weight reuse;
- packed layout;
- register-budget discipline;
- residency and cache lifecycle;
- multi-walker fusion;
- CPU/GPU specialization;
- guarded reference-backed promotion.

The post-EW sequence adds another lesson: **newer does not automatically mean faster**. Architectural lineage and benchmark leadership must be tracked separately.
