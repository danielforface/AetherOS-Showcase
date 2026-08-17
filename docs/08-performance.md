# Performance

## Performance reporting rule

AetherOS now distinguishes three different concepts that older documentation sometimes collapsed into one number:

1. **latest architecture** — the newest hardware-observed round;
2. **best verified E2E benchmark** — the fastest complete clean benchmark in the supplied evidence;
3. **operator / logical-throughput metrics** — subsystem measurements that are not automatically end-to-end speed.

As of the 2026-08-18 consolidation:

- **latest architecture:** `ROUND18FB`;
- **best verified clean 128-token E2E decode:** `ROUND18EO`, ~**3.411 tok/s**;
- **latest clean ROUND18FB 128-token result:** ~**3.271 tok/s** (best of two complete 128-token requests in the latest log).

## Verified evolution

| Milestone | Architecture | Clean 128-token decode evidence | Avg cycles/token | Throughput metric | Status |
|---|---|---:|---:|---:|---|
| v1.2 | early hybrid dispatch | historical | ~78.36B | ~0.02 GB/s historical estimate | historical |
| 18EL | QKV production generation | ~54 s class | ~0.79–0.83B | ~1.85 GB/s logical Q4 in later census | verified generation |
| 18EO | universal Q4_K 2OW packed | **37.523738 s** best request | **586.31M** best request | ~3.51 GB/s logical Q4 | **peak supplied E2E: ~3.411 tok/s** |
| 18EW | zero-spill AVX2 Q6_K + packed QKV | 39.21–40.07 s | ~612.7–626.1M | ~3.50–3.51 GB/s logical Q4 | clean / verified |
| 18EX | fused AVX2 SwiGLU / lean Q6 prefetch | one clean 128 request, another gate failure in run | ~619.8M clean request | ~3.53 GB/s logical Q4 | **hold architecture promotion** in failed gate window |
| 18EY | immediate multi-core Q6 + unified GPU FFN | two clean 128 requests | ~1.13B | ~3.27 GB/s logical Q4 | correctness clean, performance regression |
| 18FA | cooperative cache tiling + zero-stall dual-walker | three clean 128 requests | 612.08M best; 631.49M mean | ~3.51 GB/s logical Q4 | verified |
| **18FB** | **adaptive L2/L3 cooperative cache tiling + low-latency dual-walker** | **two clean 128 requests** | **611.48M best; 615.64M median** | **~3.51 GB/s logical Q4** | **latest observed architecture** |

## Peak vs latest

The current public benchmark headline should be written as:

> **Peak verified 128-token E2E decode: ~3.411 tok/s (ROUND18EO). Latest hardware-observed architecture: ROUND18FB, with a best clean 128-token request of ~3.271 tok/s.**

This avoids attributing ROUND18EO's peak throughput to a later round that did not reproduce the same wall-clock result.

## Logical Q4 throughput is not physical DRAM bandwidth

The latest baseline telemetry explicitly emits:

```text
semantics=LOGICAL_GRAPH_TRAFFIC_NOT_PHYSICAL_DRAM
```

Therefore values around `3.50–3.52 GB/s` should be called **logical Q4 graph throughput** or **effective logical weight traffic**, never directly measured DRAM bandwidth.

## Latest ROUND18FB clean 128-token requests

| Request | Avg cycles/token | Wall time | Derived output rate | GPU faults | Recoveries |
|---|---:|---:|---:|---:|---:|
| 1 | 619,805,583 | 39.667557 s | ~3.227 tok/s | 0 | 0 |
| 2 | **611,481,429** | **39.134811 s** | **~3.271 tok/s** | 0 | 0 |

The third request was clean but ended after 27 generated tokens and therefore is excluded from the 128-token comparison.

## Current decode cost shape

ROUND18FB request-level telemetry continues to show three dominant regions:

- FFN Gate/Up / large `8192×2048` Q4 work: about **28%** of decode in the bottleneck census;
- Q6_K LM Head: roughly **165M cycles/token** in the two-worker production path;
- attention/QKV/output projections: roughly the next major block, with request-level attention totals around the ~100M-cycle/token class.

The optimization frontier is therefore still dominated by large projection traffic and weight reuse rather than bootstrapping or basic walker correctness.

## Operator qualification context

ROUND18FB's QKV packed 2OW qualification reports a **~2.201×** speedup versus its factored reference in that specific qualification harness, with Q/K/V exactness and guarded per-request publication.

That ratio is not interchangeable with older per-layer timing tables. AetherOS documentation should retain the benchmark harness alongside every speedup claim.

## Prefill

The runtime implements LM-head bypass for intermediate prompt tokens and contains an audited KV/prefill-cache path. In the latest FB requests the cache audit reports `reused=0`; this evidence therefore proves the path is active but does not establish a cache-reuse speedup for those requests.

## Measurement discipline

Public numbers should always identify:

- round/build;
- physical hardware;
- prompt length;
- generated-token count;
- clean/correctness gate;
- whether the number is wall-clock, RDTSC cycles, GPU timestamp, or logical traffic;
- whether the result is production, guarded production, shadow, or lab-only.

See [Latest Real-Hardware State](18-latest-hardware-state.md) for the newest evidence snapshot.
