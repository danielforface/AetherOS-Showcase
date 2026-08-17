# Roadmap

This roadmap communicates direction, not delivery promises.

## Near term — performance saturation

- increase measured effective memory bandwidth;
- expand weight-reuse experiments beyond current shadow candidates;
- reduce LM Head latency;
- continue FFN graph fusion and packed-layout work;
- reduce GPU fence / command overhead;
- add power and thermal telemetry to performance qualification;
- extend repeated-run statistical reporting.

## Mid term — inference runtime maturity

- formalize operator routing policy using measured cost models;
- strengthen GGUF/model compatibility reporting;
- broaden context/KV stress qualification;
- improve tokenizer/sampling compatibility coverage;
- improve failure containment and recovery reporting;
- build a stable reproducible benchmark suite for the public showcase.

## Hardware research

- continue Gen9 EU/kernel research;
- evaluate portability boundaries across additional Intel integrated GPU generations;
- separate architecture-general mechanisms from target-specific register policy;
- evaluate more aggressive graph fusion where correctness can be proven.

## Public showcase

- keep proof matrix and performance tables synchronized with latest validated rounds;
- publish safe architecture diagrams and methodology;
- add sanitized hardware logs or benchmark artifacts when suitable;
- maintain explicit public/private IP boundaries.

## Long-term direction

AetherOS aims to become a reference architecture for **OS-level co-design of local AI inference**: a system where storage, memory residency, CPU topology, GPU submission, model graph and telemetry are optimized as one machine rather than separate software layers.
