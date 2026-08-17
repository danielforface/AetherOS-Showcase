# AetherOS Media / Portfolio Copy

This file contains approved public wording for GitHub profiles, CV/portfolio pages, posts and project listings.

## GitHub repository description

> Bare-metal AI unikernel: direct Intel Gen9 GPGPU + AVX2 transformer inference on x86_64, documented with real-hardware proof.

## Portfolio headline

> **AetherOS — a bare-metal AI operating system built from bootloader handoff to LLM token generation.**

## Portfolio paragraph

AetherOS is an independently developed Rust `#![no_std]` x86_64 research operating system designed around local LLM inference. The system owns its boot path, memory management, PCI/device initialization, xHCI/NVMe storage, GGUF ingestion, CPU AVX2 kernels and direct Intel Gen9 GPU command submission. The supplied real-hardware evidence includes a peak clean 128-token LLaMA-3.2-1B-Instruct decode of ~3.411 tokens/s (ROUND18EO); the newest observed architecture is ROUND18FB, with optimized paths gated by telemetry and numerical qualification.

## Technical résumé bullet

> Designed and implemented AetherOS, a Rust bare-metal x86_64 AI kernel with custom xHCI/NVMe/GGUF ingestion, AVX2 multi-core transformer kernels and direct Intel Gen9 RCS/GPGPU execution; progressed real-hardware LLaMA-3.2-1B inference from an early ~78.36B-cycle/token path to a peak verified ~3.411 TPS clean 128-token hybrid decode, while continuing architecture work through ROUND18FB.

## Research-style abstract

AetherOS investigates operating-system/inference co-design for resource-constrained local AI. The system combines a `#![no_std]` x86_64 kernel, explicit memory/DMA management, direct model ingestion, asymmetric CPU core roles and raw Intel Gen9 GPGPU submission. Rather than treating accelerator execution as an external service behind a vendor runtime, AetherOS integrates tensor layout, residency, command construction, synchronization and numerical qualification into the kernel's inference fabric. The public repository records architecture, hardware evidence, benchmark evolution and validation methodology while keeping sensitive implementation details outside the showcase.

## Claim guardrails

Use:
- “documented on physical hardware”;
- “peak verified clean 128-token decode in supplied logs: ~3.411 TPS (ROUND18EO); latest architecture: ROUND18FB” ;
- “direct Intel Gen9 RCS/GPGPU execution”;
- “bit-exact qualification for selected optimized paths.”

Avoid:
- “fastest bare-metal AI OS”;
- “beats llama.cpp” without same-hardware benchmark;
- “7.768× faster overall” for ROUND18DV;
- “production-ready Wi-Fi” without current data-plane proof;
- implying the complete private kernel is open source.
