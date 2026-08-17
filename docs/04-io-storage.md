# I/O, Storage & Model Ingestion

## PCI and NEXUS

The NEXUS device manager discovers PCI functions and applies device-class/vendor matching. The project uses a “Universal Handshake” concept to enable memory space and bus mastering for relevant devices before driver initialization.

## xHCI USB

AetherOS implements the xHCI command, event and transfer-ring model directly.

Core elements include:

- DCBAA and scratchpad setup;
- command ring;
- event ring;
- endpoint transfer rings;
- Enable Slot / Address Device / Configure Endpoint flows;
- Bulk-Only Transport;
- SCSI READ(10);
- FAT scanning for model files.

### DMA coherency

The current platform uses explicit `clflush` / `mfence` style coherency steps around selected DMA structures and doorbell interactions.

## Model ingestion path

```text
USB flash storage
  → xHCI
  → Bulk-Only Transport
  → SCSI READ(10)
  → FAT32
  → GGUF parser
  → model tensor views / packed representations
```

A documented hardware run streamed the ~807.69 MB LLaMA-3.2-1B-Instruct Q4_K_M model and validated CRC32 `0xFBCEC507`.

## NVMe

The NVMe stack uses admin and I/O queues, PRP-based DMA and a polled completion model in its low-level path.

## VFS / FAT

The historical complete reference includes FAT12/16/32 and partition-table handling. The public claim should remain focused on paths backed by current physical evidence.

## Why storage matters to inference architecture

AetherOS treats model load and memory residency as part of inference, not an unrelated boot concern. The architecture therefore links storage geometry, DMA alignment, GGUF extents, tensor mapping and later GPU visibility.
