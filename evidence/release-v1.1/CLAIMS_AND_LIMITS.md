# Claims and Limits

## Supported

**Runtime / hardware**

- AetherOS boots directly on physical x86 hardware.
- RUN01 visibly shows USB boot, the AetherOS UI, external model discovery/loading and local generation.
- The reviewed runtime identifies Intel PCI device `8086:9b41`.
- A custom Intel Gen9 bare-metal compute backend is initialized and used as part of a hybrid CPU/iGPU route.

**Model / inference**

- The reviewed RUN01 loads `llama-3.2-1b-instruct-q4_k_m.gguf` from USB.
- Local generation occurs on the physical machine.
- Multi-turn context/KV reuse is visible in serial telemetry.

**Performance**

- HAR establishes a fixed numeric steady decode point of **7.0775 tok/s** for the reviewed configuration.
- RUN01 later reproduces approximately the same ~7.08 tok/s level on camera.
- Multiple optimization candidates are explicitly rejected when they fail gain or lifecycle thresholds.

**Engineering process**

- Selected ROUND18 packages contain SHA256 manifests, source snapshots, predecessor/release/rollback kernels, build/deployment records and physical logs.
- The reviewed evidence includes both positive and negative experiments.
- BY provides a causal register-corruption experiment with a predicted hardware signature.
- DV demonstrates a large local kernel gain that is deliberately rejected at the E2E level.
- HAR demonstrates correction of the measurement protocol before qualification.

## Not claimed

- Pure-GPU inference.
- 100% GPU offload.
- That dispatch-count percentage equals compute-time percentage.
- Zero-copy GGUF execution directly from USB (`RUN01` reports `vko_zero_copy=false`).
- Universal 7 tok/s performance.
- Cross-hardware reproducibility.
- Independent benchmark certification.
- Semantic answer-quality certification.
- Exact power efficiency.
- Final-pixel/UI latency measurement.
- That HAS promoted or caused the ~7.08 tok/s production result.
