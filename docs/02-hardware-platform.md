# Hardware Platform

## Primary verified target

| Component | Current target |
|---|---|
| CPU | Intel Core i3-10110U, Comet Lake |
| Topology | 2 physical cores / 4 logical processors |
| CPU SIMD | SSE4.2, AVX2, FMA3, BMI1/2 |
| GPU | Intel UHD 620 / Comet Lake GT2 |
| GPU PCI ID | `8086:9B41` |
| USB | Intel xHCI `8086:02ED` |
| Wi-Fi | Intel AX201 CNVi `8086:02F0` |
| NVMe | Toshiba/KIOXIA KBG40ZNT256G |
| Display | 1920×1080, 32bpp BGR |

## Why narrow hardware targeting matters

AetherOS is not currently optimized around hardware abstraction for its own sake. Narrow targeting allows the kernel to encode known register behavior, memory constraints, cache/residency assumptions and device-specific recovery logic while the architecture is still evolving rapidly.

## Key PCI devices

Representative verified enumeration includes:

- `00:02.0` — Intel UHD 620 / Comet Lake GT2;
- `00:14.0` — Intel xHCI USB controller;
- `00:14.3` — Intel AX201 CNVi companion device;
- `07:00.0` — NVMe controller.

## Memory and display environment

The system uses a higher-half kernel, HHDM-backed physical access, a dedicated DMA region, a tensor/model zone, and GPU-visible mappings through the GGTT.

The framebuffer is 1920×1080 at 32 bits per pixel with a 7680-byte pitch on the primary test machine.

## Portability status

Some device IDs and code paths include broader Gen9/Gen11/Gen12 discovery scaffolding, but the project should only call hardware **verified** when evidence exists on the physical target. “Supported in code” and “verified on silicon” are deliberately separate claims.
