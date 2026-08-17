# Proof Matrix

## Evidence classes

AetherOS uses evidence classes so documentation does not collapse implementation, experimentation and production into one status.

| Class | Meaning |
|---|---|
| DESIGN | architecture exists as a documented plan |
| IMPLEMENTED | code path exists |
| BOOT-TESTED | path executes during system boot/test |
| HW-VERIFIED | behavior observed on physical target hardware |
| BIT-EXACT | optimized result matched reference under qualification |
| SHADOW | candidate measured without production publication |
| PRODUCTION-PROMOTED | active execution path after promotion gate |
| LAB | exploratory / diagnostic path |

## Current public matrix

| Subsystem / feature | Evidence | Classification |
|---|---|---|
| Limine higher-half boot | physical boot + serial telemetry | HW-VERIFIED |
| Physical memory / heap | boot logs and active runtime | HW-VERIFIED |
| SMP core bring-up | logical-core execution | HW-VERIFIED |
| xHCI USB mass storage | device address + SCSI BOT + model read | HW-VERIFIED |
| GGUF V3 ingestion | 807.69 MB + CRC32 validation | HW-VERIFIED |
| Intel Gen9 RCS | ring / walker / fence execution | HW-VERIFIED |
| Q4_K 2OW kernels | K=2048 / K=8192 paths | HW-VERIFIED |
| QKV triple walker | exactness counters | HW-VERIFIED + BIT-EXACT |
| FFN Gate+Up dual walker | exactness counters | HW-VERIFIED + BIT-EXACT |
| FFN Down 2OW | parity test | HW-VERIFIED + BIT-EXACT |
| zero-flush GGTT residency | decode run with no pressure flush | HW-VERIFIED |
| Q6_K dual-row AVX2 | dispatch telemetry + parity | HW-VERIFIED + BIT-EXACT |
| prefill LM-head bypass | prompt timing comparison | HW-VERIFIED |
| end-to-end generation | multi-token real-hardware generation | HW-VERIFIED |
| ROUND18DV B=8 | shadow qualification | SHADOW + BIT-EXACT |

## Why proof status matters

A systems project can easily overstate progress when “the code compiled” is presented as equivalent to “the silicon executed correctly.” AetherOS documentation should instead preserve the strongest evidence actually available for each claim.


## ROUND18FB evidence addendum

| Capability | Latest observed evidence | Classification |
|---|---|---|
| latest backend generation | ROUND18FB banner on physical boot | HW-VERIFIED |
| clean 128-token E2E decode | two complete clean gates | HW-VERIFIED |
| QKV packed triple-walker | Q/K/V exact, zero mismatch, promoted with per-request audit | HW-VERIFIED + BIT-EXACT + GUARDED-PRODUCTION |
| FFN dual-walker | repeated live pair execution, no observed failures/quarantines | HW-VERIFIED |
| Q6 pinned mailbox | cert mask `0x7`, no timeout/fallback/exact failures | HW-VERIFIED + BIT-EXACT + PRODUCTION-PATH |
| GPU baseline stability | zero faults / zero recoveries in measured decode windows | HW-VERIFIED |
| boot-to-dashboard | ~14.51 s | HW-MEASURED |
| Q4 ~3.5 GB/s metric | logical graph traffic only | HW-MEASURED, **NOT physical DRAM bandwidth** |
| prefill prefix reuse | mechanism active, latest requests reused 0 tokens | IMPLEMENTED/AUDITED; reuse speedup NOT PROVEN in these requests |

See [Latest Real-Hardware State](18-latest-hardware-state.md).
