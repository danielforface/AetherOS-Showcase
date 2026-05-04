# Drivers & IO Subsystem

## Hardware Abstraction Layer (HAL)
The HAL provides full bare-metal abstractions for x86_64 hardware, including I/O APIC, Local APIC, 8259 PIC, RTC, UART 16550, and ACPI tables.

## PCI & NEXUS Device Manager
PCI configuration space is accessed via legacy I/O (0xCF8/CFC) and ECAM MMIO.
* The **NEXUS Industrial Device Manager** controls the hardware lifecycle, dynamically matching devices like xHCI, NVMe, and Intel WiFi to their respective drivers.
* Features a Universal Handshake that enables Memory Space and Bus Mastering automatically for non-bridge PCI devices.

## Storage & VFS
* **NVMe Driver**: Operates in polled mode with zero-copy DMA, utilizing admin and I/O submission/completion queues to bypass interrupt latency.
* **VFS (Virtual File System)**: Supports mounting `FAT32` directly from NVMe and USB mass storage. It features a custom FAT32 Cluster Chain Cache to eliminate O(n²) table walks during large model loads.

## USB Subsystem (xHCI)
* Features a full xHCI 3.0 implementation with Command, Event, and Transfer TRB rings.
* Uses `clflush` and `mfence` for DMA-SHIELD coherency prior to doorbell rings.
* Implements Bulk-Only Transport (BOT) and SCSI Transparent Command Sets to read GGUF models directly from external drives.

## Networking (Intel WiFi AX201)
AetherOS includes a driver for the Intel Wi-Fi 6 AX201 (CNVi) module.
* Bootstraps the `iwlwifi` firmware via DMA upload directly to the device SRAM.
* Implements Gen2 TX/RX command queues for Host-to-Firmware communication.
