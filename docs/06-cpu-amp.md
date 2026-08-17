# CPU SIMD & Asymmetric Multiprocessing

## CPU role in AetherOS

CPU execution is a first-class part of the hybrid inference architecture, not merely an emergency fallback. On the current i3-10110U target, Q6_K remains competitive for LM Head and selected large matrix paths when GPU transformation/dispatch economics are unfavorable.

## Core assignment

| Core role | Function |
|---|---|
| Core 0 | BSP, compositor, I/O, system orchestration |
| Core 1 | inference master, graph traversal, tokenizer, embeddings |
| Cores 2–3 | neural compute workers |

The latest hardware log brings all 4 logical CPUs online (`mask=0xF`).

## Q6_K AVX2 execution

The optimized Q6_K generation retains the zero-spill / register-budget concepts documented in ROUND18EW, including dual-row AVX2 accumulation.

The newer evidence adds a stronger **dispatch and synchronization contract**.

## Pinned-mailbox production path

ROUND18FB reports:

```text
workers=2
mailbox=PER_WORKER_GENERATION
staging=BOOT_LIFETIME
bounded=1
pinned=1
request_path=PINNED_MAILBOX_PRODUCTION
```

A preflight is executed before each request window. The captured requests report clean preflight completion and no legacy repair activity.

### Qualification shapes

The certification mask is built across three shapes:

| Certification bit | Shape | Representative role |
|---|---|---|
| `0x1` | `512×2048` | smaller projection path |
| `0x2` | `2048×8192` | large K path |
| `0x4` | `128256×2048` | LLaMA LM Head |

The complete mask reaches `0x7`.

### Latest reliability evidence

Across the latest FB request summaries:

- failures: 0;
- fallbacks: 0;
- timeouts: 0;
- exact failures: 0;
- mailbox claim/completion timeouts: 0;
- legacy repairs: 0;
- Q6 path remains enabled.

This is stronger than a one-off kernel benchmark: it demonstrates a qualified, repeatedly exercised two-worker production route.

## LM Head

The LLaMA-3.2-1B vocabulary projection is `128256×2048`.

Latest FB LM Head samples are approximately:

- `164.90M cycles`;
- `165.67M cycles`;
- `165.75M cycles`.

This is consistent with the ~164–166M-cycle class documented for the optimized multi-core Q6_K path.

## Why ROUND18EY matters

ROUND18EY introduced **Immediate Multi-Core Q6_K Dispatch & Unified GPU FFN Pipeline** and showed that a correctness-clean architecture can still regress system performance badly: its clean 128-token requests were around `1.13B cycles/token`.

That round is useful engineering evidence because it reinforces AetherOS's promotion rule: **correctness is necessary, but not sufficient for performance promotion**.

## F10 / system interference

AetherOS can suppress compositor work while generation is active to bias limited CPU and memory resources toward inference. This remains a system-level optimization rather than an assumption that every CPU core should run the same workload.

## Hybrid routing principle

The reference CPU path remains important even after GPU promotion because it serves as:

- a fallback;
- a correctness oracle;
- a performance comparator;
- a way to isolate GPU transport/dispatch regressions from model-math regressions.

See [Latest Real-Hardware State](18-latest-hardware-state.md).
