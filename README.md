```markdown
# 🌌 AetherOS — Infinite Horizon
> **Bare-Metal AI Operating System & Inference Engine**

⚠️ **Notice:** *The core engine (kernel, Z3-verified logic, and LLVM backend) is currently maintained in a private repository pending intellectual property and stealth phase considerations. This repository serves as the public architectural documentation, hardware verification log, and proof-of-work showcase.*

AetherOS is a RAM-native, Rust-first experimental x86_64 operating system designed from scratch. It is an **AI-native research operating system** where the kernel itself understands tensors, quantized model formats, and GPU compute dispatch. The entire stack — from boot to inference — is a single Rust binary with zero runtime dependencies.

## 🔥 Core Engineering Achievements

*   **Bare-Metal AI:** Native token generation on real hardware (Intel i3-10110U / UHD 620). Loaded Llama-3.2-1B-Q4_K_M (807 MB) end-to-end bypassing traditional OS layers.
*   **Hybrid Compute Dispatch:** GPU+CPU hybrid compute routing. Validated Q4_K GPU-CPU execution with `maxDiff < 0.00002` across all matrix dimensions.
*   **Zero-Copy Tensor Path:** NVMe SSD → DMA Buffer → GGUF Parser → Tensor Buffer → GPU VRAM. Zero intermediate copies.
*   **Asymmetric Multiprocessing (AMP):** Core 0 handles a rendering compositor (60 FPS, double-buffered), while Core 1 is the strictly isolated inference master.
*   **Demand-Paged KV Cache:** Physical frames are allocated lazily via page fault handlers, allowing massive context windows with minimal base RAM footprint.

---

## 🏗️ Architecture Overview

AetherOS operates entirely in Ring 0, eliminating syscall overhead for AI workloads. 
```text
┌─────────────────────────────────────────────────────────────────┐
│                        USER INTERFACE                           │
│  ┌──────────┐ ┌─────────┐ ┌──────────┐ ┌──────────┐          │
│  │ Desktop  │ │ Neural  │ │ Pipeline │ │ Settings │  ...      │
│  │ (Obsidi) │ │ Dashboard│ │ (AI Chat)│ │          │          │
│  └────┬─────┘ └────┬────┘ └────┬─────┘ └────┬─────┘          │
│       └─────────────┴──────────┴─────────────┘                │
│                        │                                       │
│              ┌─────────┴──────────┐                           │
│              │    COMPOSITOR      │  Double-buffered,          │
│              │  (Global Keys +    │  render-on-demand,         │
│              │   15 Modes)        │  60 FPS target             │
│              └─────────┬──────────┘                           │
├────────────────────────┼──────────────────────────────────────┤
│                   KERNEL SERVICES                              │
│  ┌─────────┐ ┌────────┐ ┌──────────┐ ┌───────┐ ┌──────────┐ │
│  │Scheduler│ │Process │ │ Syscall  │ │  VFS  │ │ Security │ │
│  │(per-CPU)│ │(16 max)│ │(28 calls)│ │       │ │(SSP/KASL)│ │
│  └─────────┘ └────────┘ └──────────┘ └───────┘ └──────────┘ │
├───────────────────────────────────────────────────────────────┤
│                    AI / ML RUNTIME                             │
│  ┌──────┐ ┌──────────┐ ┌──────────┐ ┌────────┐ ┌──────────┐ │
│  │ GGUF │ │Transformer│ │ BPE     │ │  GEMM  │ │  AMP     │ │
│  │Parser│ │(LLaMA/Qw)│ │Tokenizer│ │AVX2+FMA│ │Core0↔C1  │ │
│  └──────┘ └──────────┘ └──────────┘ └────────┘ └──────────┘ │
├───────────────────────────────────────────────────────────────┤
│                  HARDWARE ABSTRACTION                          │
│  ┌─────┐ ┌──────┐ ┌──────┐ ┌───────┐ ┌──────┐ ┌──────────┐ │
│  │ PCI │ │ USB  │ │ NVMe │ │  GPU  │ │ WiFi │ │  DMA     │ │
│  │     │ │xHCI  │ │Polled│ │Intel  │ │AX201 │ │64MB Bump │ │
│  │     │ │EHCI  │ │      │ │Gen9+  │ │CNVi  │ │          │ │
│  └─────┘ └──────┘ └──────┘ └───────┘ └──────┘ └──────────┘ │
├───────────────────────────────────────────────────────────────┤
│                      x86_64 HARDWARE                           │
│  Local APIC · I/O APIC · PIC · PIT · RTC · UART · ACPI      │
│  CR0/CR4/XCR0 · GDT/TSS · IDT · SYSCALL/SYSRET · MSRs      │
└──────────────────────────────────────────────────────────────┘
```
---

## 📚 Deep Dive Documentation

The complete architectural documentation has been modularized for readability:

1. [Hardware & Boot Architecture](./docs/01-hardware-and-boot.md) — Toolchain, Boot Sequence, Memory Architecture, SMP, and Interrupts.
2. [Drivers & IO Subsystem](./docs/02-drivers-and-io.md) — PCI, Storage, VFS, USB (xHCI), NVMe, and WiFi.
3. [AI & ML Inference Engine](./docs/03-ai-inference-engine.md) — GPU Compute, Transformer Architecture, Quantization, and AMP.
4. [Graphics & UI Framework](./docs/04-graphics-and-ui.md) — Compositor, Obsidian/Atticus Design Systems, and App Framework.
5. [Proof Matrix & Benchmarks](./docs/05-proof-matrix-and-benchmarks.md) — Hard telemetry data verifying end-to-end execution on physical hardware.
```

---
