# Proof Matrix & Benchmarks

> All metrics reflect execution on physical, bare-metal hardware (Intel Core i3-10110U / UHD 620), verified via continuous serial port telemetry.

## HW-VERIFIED: End-to-End Inference
AetherOS successfully loaded and executed the `Llama-3.2-1B-Instruct-Q4_K_M` model (807 MB) directly from a FAT32 USB drive.
* **Model Load:** Full 807 MB streamed to RAM via adaptive I/O chunks (~384 KB) over the xHCI SCSI protocol.
* **KV Cache:** 128 MiB demand-paged for a 16-layer transformer.
* **GPU-CPU Validation:** Matrix dequantization and matmul operations produced identical results on both GPU and CPU (max divergence < 0.00002).

## Performance Metrics
* **Token Generation:** Reached ~78.36 Billion cycles per token on hardware.
* **Hybrid Dispatch:** Averaged 96 GPU dispatches per token with a fence wait of ~812.8M cycles per dispatch.
* **Allocation Overhead:** Near-zero runtime allocations (~36 cycles per token) on the hot path.
* **GPU Execution Proof:** Successfully passed the `0xDEADBEEF` magic sync page test during GPGPU_WALKER dispatch.
