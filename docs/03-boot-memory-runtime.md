# Boot, Memory & Runtime

## Boot flow

AetherOS boots through Limine v8.x and enters a Rust `#![no_std]` kernel.

At entry, the kernel establishes the minimum x86_64 execution contract required for safe SIMD and Rust execution:

- stack alignment;
- CR0 FPU/SSE state;
- CR4 OSFXSR / OSXMMEXCPT;
- MXCSR exception mask;
- transition into Rust initialization.

## Initialization phases

The runtime is organized broadly around:

1. framebuffer and serial bring-up;
2. CPU feature detection, GDT/TSS and IDT;
3. memory allocator, heap and DMA zones;
4. compositor and input infrastructure;
5. APIC/PIC, timer and SMP;
6. PCI, device manager, storage and filesystems;
7. AI fabric, GPU/CPU compute, model runtime and network services;
8. interrupt enable and steady-state compositor/runtime loop.

## Memory architecture

### Physical memory

Important regions include:

- kernel image;
- dedicated DMA allocation space;
- NVMe/xHCI transient buffers;
- tensor/model memory zone;
- PCI MMIO windows;
- LAPIC / I/O APIC MMIO.

### Virtual memory

AetherOS uses:

- a higher-half kernel;
- HHDM mappings from the bootloader;
- dynamically mapped MMIO;
- kernel heap space;
- direct model mappings;
- demand-paged KV-cache space.

## Physical memory management

The kernel uses a 4 KiB frame-granularity bitmap allocator built from the Limine memory map.

## Heap

The kernel heap is dynamically sized within documented bounds and uses KASLR-lite sliding. The hot inference path is designed to avoid allocation rather than depending on allocator speed.

## SMP and AMP

All logical processors receive SIMD/FPU initialization. AetherOS then applies asymmetric roles for inference rather than treating all CPUs as general scheduling peers.

## Interrupts

The kernel supports local APIC / I/O APIC operation with a fallback PIC path. The IDT covers standard exceptions, timer/input IRQs and dynamic MSI/MSI-X vectors.

## Page faults as runtime mechanisms

Page faults are not only fatal conditions. AetherOS uses dedicated fast paths for demand-backed structures such as model/KV memory where configured.


## Latest measured boot/runtime memory evidence (ROUND18FB)

The newest supplied hardware log closes several measurements that earlier documentation left open:

- boot-to-dashboard: **~14.51 s** (`29,015,702,552 cycles`, reported as `14,507,851 us`);
- 4 logical CPUs online (`mask=0xF`);
- dynamic tensor-zone total: **7,348 MB**;
- model stream/working budget: **772 MB**;
- reserved headroom: **193 MB**;
- total model budget: **966 MB**;
- free tensor-zone memory after streaming: approximately **6,576 MB**.

These are observed values for ROUND18FB on the primary physical test machine, not universal configuration constants.
