# Hardware & Boot Architecture

## Build System & Toolchain
AetherOS relies on the Rust `nightly` toolchain compiled for the `x86_64-unknown-none` target. It is built as a single `#![no_std]` binary with zero runtime linking.
Key dependencies include:
* `limine` (v0.5) for the boot protocol.
* `x86_64` (v0.15.2) for CPU structures.
* `spin` and `linked_list_allocator` for memory management.

## Boot Sequence
The bootloader is Limine v8.x, utilizing a Higher Half Direct Map (HHDM). The entry point (`_start`) is a naked assembly function that aligns the stack, configures CR0 and CR4 for FPU/SSE, sets MXCSR for fast math mode, and jumps directly to Rust.
The `kernel_main()` function executes initialization in 8 distinct phases, covering everything from Framebuffer and Security (SSP, KASLR) to AI Fabric and SMP initialization.

## Memory Architecture
The Higher Half Kernel resides at `0xFFFFFFFF80000000`.
* **Heap Allocator**: Dynamically sizes between 256MB and 2GB, featuring KASLR-lite random page sliding to prevent fixed-address exploits.
* **Tensor Buffer System**: Features a zero-copy path from NVMe directly to the DMA buffer and Tensor Zone (≥512 MB).
* **VKO Demand Paging**: Offers 8+ GiB of virtual space, mapping physical frames lazily on `#PF` (Page Faults) to support massive LLM context windows without exhausting base RAM.

## CPU Initialization & SMP
Every core sets up its own SIMD environment (SSE2, AVX2, FMA3) optimal for ML inference.
* **SMP Architecture**: Supports up to 8 CPUs.
* The BSP wakes Application Processors (APs) sequentially using the Limine SMP protocol, assigning each an AP-specific GDT and TSS.

## Security & Determinism
To ensure reproducible benchmark and AI inference results, AetherOS utilizes:
* Memory residency tracking (HOT/WARM/COLD/PINNED).
* Stack Smashing Protection (SSP) and KASLR-Lite powered by RDRAND hardware entropy.
