# Glossary

**2OW** — Two-Octoword / 32-byte packed execution/data-layout concept used in current Gen9 Q4_K work.

**AMP** — Asymmetric Multiprocessing. AetherOS assigns different CPU cores specialized system/inference roles.

**BIT-EXACT** — Candidate output matched the chosen reference exactly under the qualification test.

**BSP** — Bootstrap Processor, Core 0 on the primary target.

**ELSP** — Execlist submission mechanism used in Intel graphics context submission work.

**EU** — Intel GPU Execution Unit.

**GGTT** — Global Graphics Translation Table, mapping system pages into GPU-visible address space.

**GGUF** — Model container format used for metadata and tensors.

**GPGPU_WALKER** — Intel command used to dispatch compute thread groups through the media/GPGPU pipeline.

**GRF** — General Register File in Intel GPU execution architecture.

**HW-VERIFIED** — Behavior observed on physical target hardware.

**NEXUS** — AetherOS device-management layer responsible for discovery/matching/initialization policy.

**Production publish** — Whether an optimized candidate's output becomes the active graph result.

**Q4_K / Q6_K** — GGML K-quant formats used in optimized GPU/CPU paths.

**RCS** — Intel Render Command Streamer.

**Shadow candidate** — Experiment executed and measured without publishing its result into production inference.

**SLM** — Shared Local Memory in the GPU execution model.

**VKO** — AetherOS virtual/demand-backed model-memory concept retained in the system architecture.
