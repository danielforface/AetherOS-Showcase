# AI & ML Inference Engine

## Transformer Architecture & Quantization
AetherOS embeds a native inference engine designed to execute large language models directly on bare metal. 
* Supports Llama-style transformers featuring RMSNorm, Rotary Positional Embeddings (RoPE), and SwiGLU/SiLU activations.
* Features a BPE tokenizer with byte-level vocabulary and merge rules.
* The Quantization Engine supports 11 GGML formats, including Q4_K, Q8_0, and F16. The `QTensor` structure points directly into memory-mapped GGUF file data to ensure zero-copy operations.

## GPU Compute (Intel iGPU)
AetherOS implements direct GPGPU execution on Intel Gen9+ graphics without a traditional OS stack.
* It utilizes the Render Command Streamer (RCS) ring and a custom Global Graphics Translation Table (GGTT) to map physical addresses to GPU-visible space.
* The `GPGPU_WALKER` dispatch sequence executes hardware-accelerated GEMV compute kernels.
* A Hybrid Compute Router dynamically partitions workloads, prioritizing GPU dispatch while falling back to CPU AVX2+FMA for scalar operations.

## Asymmetric Multiprocessing (AMP)
To maintain 60 FPS UI rendering during heavy inference, AetherOS uses Asymmetric Multiprocessing.
* **Core 0 (BSP):** Dedicated entirely to the compositor, hardware I/O, and UI rendering.
* **Core 1:** Isolated as the "inference master," performing transformer forward passes and AVX2 matmul.
* Communication between cores is handled via a lock-free SPSC (Single-Producer, Single-Consumer) IPC Token Ring, avoiding mutex contention.
