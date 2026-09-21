# Benchmark Methodology

## Tested configuration

The reviewed evidence concerns a physical Lenovo x86 laptop running AetherOS directly at runtime, with an Intel Gen9-class iGPU identified as PCI device `8086:9b41`.

Model used in RUN01:

`llama-3.2-1b-instruct-q4_k_m.gguf`

The file is approximately 808 MB and is loaded from external USB storage.

## Primary public performance number

The preferred public number is **7.0775 decode tokens/sec**, established by ROUND18HAR's fixed numeric steady matrix.

Why HAR is preferred:

1. It separates warm-up/proof cost from measured steady samples.
2. It uses balanced/reversed candidate/control ordering.
3. It does not select the fastest sample.
4. Promotion thresholds remain unchanged.
5. Exactness and physical pre/post checks remain active.
6. The request matrix is complete.

HAR request sequence:

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

The first request is intentionally retained. It contains cold/proof costs and is not silently removed from the record.

## RUN01 role

RUN01 is a continuous physical-laptop demonstration rather than the source of the benchmark headline.

Its matched 128-token requests reproduce the HAR-class operating point at approximately 7.08 tok/s. This makes the performance point visually inspectable while preserving HAR as the stronger controlled numeric qualification.

## Why short responses are excluded from the headline

Later RUN01 requests contain heterogeneous prompts and shorter outputs. A short response can report a higher instantaneous decode TPS while being a weaker steady benchmark.

For example, an 8-token decode is not used as evidence of "8 tok/s sustained."

## Component benchmarks vs end-to-end performance

AetherOS deliberately distinguishes them.

Examples:

- DV reached 7.768x in a controlled B=8 Q4 multicolumn kernel test, but did not improve the complete FFN graph enough to promote.
- HAI's attention subcomponent showed a large guarded local gain, while the full eight-request matrix was incomplete.
- HAS reduced local dynamic instruction count by ~15.4% but did not clear the physical promotion thresholds.

A component speedup is never automatically relabeled as a token/s speedup.

## Historical TPS values

The engineering chronicle contains earlier observed operating points (approximately 5–7 tok/s class). These are useful for lineage, but they were produced under their respective round protocols and are **not all matched-prompt causal A/B comparisons**.

They should therefore be described as historical operating points, not compounded into a single causal percentage.

## Reproducibility boundaries

Current evidence strongly supports repeatability on the reviewed physical machine and tested model/configuration.

Not yet established:

- independent third-party replication,
- multiple hardware platforms,
- broad model-family generalization,
- power/energy efficiency,
- final-pixel latency.
