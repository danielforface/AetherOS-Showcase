# Latest Real-Hardware State — ROUND18FB

**Evidence date:** 2026-08-17 (latest captured hardware log in the supplied evidence set)  
**Documentation consolidation:** 2026-08-18  
**Latest observed round:** `ROUND18FB`  
**Target:** Intel Core i3-10110U + Intel UHD 620 / Comet Lake GT2 (`8086:9B41`)

> This document separates **latest architecture** from **best historical benchmark**. They are not the same thing.

## Executive state

The newest supplied serial log boots a kernel identifying the active backend as:

```text
ROUND18FB Adaptive L2/L3 Cooperative Cache Tiling & Low-Latency GPU Dual-Walker active
```

ROUND18FB therefore supersedes ROUND18EW as the newest observed hardware state in the supplied evidence.

It does **not** supersede ROUND18EO as the best verified 128-token end-to-end decode result.

## Latest clean 128-token decode results

ROUND18FB contains two complete, clean 128-token decode gates:

| Request | Result | Decode cycles | Avg cycles/token | Wall time | Derived output rate |
|---|---|---:|---:|---:|---:|
| 1 | `COLD_BOOT_BASELINE_PASS_128` | 79,335,114,720 | 619,805,583 | 39.667557 s | ~3.227 tok/s |
| 2 | `COLD_BOOT_BASELINE_PASS_128` | 78,269,622,980 | **611,481,429** | **39.134811 s** | **~3.271 tok/s** |

A third request remained clean but generated only 27 tokens, so it is not used as a 128-token headline result.

### Peak benchmark remains ROUND18EO

ROUND18EO request 2 recorded:

- `75,047,476,918` decode cycles;
- `586,308,413` average cycles/token;
- `37.523738 s` for 128 generated tokens;
- approximately **3.411 tok/s**.

Therefore:

- **Latest hardware architecture:** ROUND18FB.
- **Best verified 128-token E2E decode in the supplied logs:** ROUND18EO at ~3.411 tok/s.
- **Latest clean ROUND18FB 128-token result:** ~3.271 tok/s.

This distinction should be preserved in every public performance claim.

## Q4 throughput semantics

The latest logs explicitly label the bandwidth accounting as:

```text
semantics=LOGICAL_GRAPH_TRAFFIC_NOT_PHYSICAL_DRAM
```

ROUND18FB reports approximately `3.50–3.525 GB/s` for this **logical Q4 graph-throughput metric**.

This number must not be presented as directly measured physical DRAM bandwidth.

## GPU QKV production qualification

The latest QKV qualification reports:

- kernel family: `ED_W32_2OW_REGION_MULADD`;
- packed layout: `AOSOA32_XSUM`;
- walker: `QKV_TRIPLE`;
- selected variant: `79`;
- selected window: `32`;
- Q/K/V exactness: all exact;
- mismatch count: zero;
- qualification speedup: approximately **2.201×** against the factored reference in this qualification harness;
- state: `production_promoted=1`;
- publication mode: `GUARDED_PER_REQUEST_AUDIT`.

The qualification-harness speedup is not interchangeable with older per-layer latency figures; both should retain their original measurement context.

## GPU FFN dual-walker state

The live FFN pair path reports:

```text
path=DUAL_RESIDENT_PACKED_XSUM
walkers=2
submissions=1
fences=1
fallback=FACTORED_DUAL_WALKER
```

The request-level telemetry remains clean:

- failures: `0`;
- fallback/quarantine events: `0` in the observed production windows;
- kernel repairs: `0`;
- L3 repairs: `0`;
- restore failures: `0`;
- average live pair cost near `12.26M cycles` in ROUND18FB;
- average fence cost near `10.71M cycles/pair`.

The bottleneck telemetry continues to attribute roughly **28% of decode** to the `8192×2048` FFN Gate/Up region in representative requests.

## Q6_K pinned-mailbox production path

The latest CPU Q6_K path is stronger than the earlier generic “dual-row AVX2” description.

Observed contract:

```text
workers=2
mailbox=PER_WORKER_GENERATION
staging=BOOT_LIFETIME
bounded=1
pinned=1
request_path=PINNED_MAILBOX_PRODUCTION
```

Three qualification shapes accumulate `cert_mask=0x7`:

1. `512×2048`;
2. `2048×8192`;
3. `128256×2048` (LM Head).

Across the latest requests the path reports:

- `fail=0`;
- `fallback=0`;
- `timeout=0`;
- `exact_fail=0`;
- `disabled=0`.

The latest LM Head samples remain around **165M cycles** (`164.9–165.7M`) on the two-worker path.

## GGTT / model residency evidence

The latest log reports:

```text
GGTT STATIC ZONE EXPLICITLY LOCKED: 147 entries, 195426 pages (781704KB)
```

It also parses a GGUF V3 file containing **147 tensor descriptors**.

This is the newest directly observed static-model residency figure. Earlier documentation that references a 260,000-page / ~1.01 GiB GGTT threshold should be treated as an earlier policy/working-set figure, not as the newest observed static-zone count.

Packed GPU caches then operate on top of the model-resident state. In full 128-token requests the Q4 telemetry shows thousands of hits with no steady-state misses after the initial cache population.

## Boot and model-ingestion evidence

ROUND18FB provides a measured boot milestone that older documentation marked as unknown:

```text
total_boot_to_dashboard: 29015702552 cycles (~14507851 us)
```

That is approximately **14.51 seconds boot-to-dashboard** on the test machine for this build.

The same log also verifies:

- 4 logical CPUs online (`mask=0xF`);
- GPU GT requested/observed at 1000 MHz during decode telemetry;
- model file size: `807,690,656 bytes`;
- CRC32: `0xFBCEC507` with `0 errors`;
- GGUF V3: 147 tensors, 30 metadata KV pairs;
- vocabulary: 128,256;
- FFN hidden size: 8192;
- 8 KV heads / 32 attention heads;
- model context: 2048.

## Dynamic tensor-memory budgeting

The latest runtime exposes a more concrete memory budget than the earlier static description:

```text
ZONE_TENSOR total = 7348 MB
stream          = 772 MB
working         = 772 MB
headroom        = 193 MB
budget          = 966 MB
```

After model streaming, the log reports approximately `6576 MB` free in the tensor zone.

## Prefill cache status

The runtime contains a GPU prefill/KV cache path and commits prompt/generated-token residency. However, the three latest observed requests report:

```text
reused=0
reuse_x1000=0
```

Therefore the evidence proves the mechanism is active and audited, but **does not prove prefix reuse was exercised in these requests**. Public documentation should not claim a measured prefill-cache reuse speedup from this log set.

## Evidence-level conclusion

The post-EW rounds materially change the current understanding:

- `ROUND18EX` explored fused AVX2 SwiGLU / lean Q6_K prefetch / vectorized readback but included a baseline gate failure and was held from architecture promotion in that run.
- `ROUND18EY` introduced immediate multi-core Q6_K dispatch and a unified GPU FFN pipeline; Q6 qualification was clean, but 128-token decode regressed to ~1.13B cycles/token.
- `ROUND18FA` introduced cooperative cache tiling and a zero-stall dual-walker generation; three clean 128-token gates were observed.
- `ROUND18FB` is the newest observed state, adding adaptive L2/L3 cooperative cache tiling and low-latency dual-walker operation while preserving guarded QKV promotion, pinned-mailbox Q6 exactness, and zero GPU fault/recovery counts in the measured requests.

The public story should therefore be: **AetherOS has moved beyond ROUND18EW, but the newest architecture and the peak benchmark must be reported separately.**
