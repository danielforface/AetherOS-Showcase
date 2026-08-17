# Transformer Runtime

## Current primary model

The latest documented target is LLaMA-3.2-1B-Instruct.

| Parameter | Value |
|---|---:|
| Parameters | ~1.23B |
| Model dimension | 2048 |
| Layers | 16 |
| Attention heads | 32 |
| KV heads | 8 |
| FFN dimension | 8192 |
| Vocabulary | 128,256 |
| RoPE theta | 500,000 |
| Norm | RMSNorm, epsilon `1e-5` |
| FFN activation | SwiGLU / SiLU |

## GGUF

AetherOS parses GGUF metadata and tensors directly in its kernel/runtime environment. The design favors tensor views into model-backed memory and only creates alternate packed layouts when an optimized compute path requires them.

## Quantization

The system contains support for multiple GGML tensor formats. The current performance work centers on Q4_K_M and Q6_K because they map to the GPU and CPU optimization paths described elsewhere in this repository.

## Attention

The model uses Grouped-Query Attention with 32 query heads and 8 KV heads.

The runtime includes:

- RMSNorm;
- Q/K/V projection;
- RoPE;
- KV-cache update;
- attention score/softmax path;
- output projection;
- FFN Gate/Up/Down;
- final normalization;
- LM Head;
- sampling.

## Prefill optimization

For prompt tokens `0..N-2`, the runtime can populate transformer/KV state without computing the expensive final vocabulary projection. The LM Head is needed only for the token position that will actually produce the next-token distribution.

Documented prompt examples show substantial latency reductions under this optimization.

## KV cache

The architecture includes a demand-backed KV-cache concept and ring-style reuse for token positions. The goal is to avoid unnecessary up-front physical allocation while preserving predictable access during generation.

## Hot-path allocation policy

Forward execution uses persistent scratch/storage structures so token generation does not depend on heap allocation in the hot path.
