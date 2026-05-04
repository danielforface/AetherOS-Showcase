# Drivers & IO Subsystem

## Hardware Abstraction Layer (HAL)
The HAL provides full bare-metal abstractions for x86_64 hardware, including I/O APIC, Local APIC, 8259 PIC, RTC, UART 16550, and ACPI tables[cite: 11].

## PCI & NEXUS Device Manager
PCI configuration space is accessed via legacy I/O (0xCF8/CFC) and ECAM MMIO[cite: 11].
* The **NEXUS Industrial Device Manager** controls the hardware lifecycle, dynamically matching devices like xHCI, NVMe, and Intel WiFi to their respective drivers[cite: 11].
* Features a Universal Handshake that enables Memory Space and Bus Mastering automatically for non-bridge PCI devices[cite: 11].

## Storage & VFS
* **NVMe Driver**: Operates in polled mode with zero-copy DMA, utilizing admin and I/O submission/completion queues to bypass interrupt latency[cite: 11].
* **VFS (Virtual File System)**: Supports mounting `FAT32` directly from NVMe and USB mass storage[cite: 11]. It features a custom FAT32 Cluster Chain Cache to eliminate O(n²) table walks during large model loads[cite: 11].

## USB Subsystem (xHCI)
* Features a full xHCI 3.0 implementation with Command, Event, and Transfer TRB rings[cite: 11].
* Uses `clflush` and `mfence` for DMA-SHIELD coherency prior to doorbell rings[cite: 11].
* Implements Bulk-Only Transport (BOT) and SCSI Transparent Command Sets to read GGUF models directly from external drives[cite: 11].

## Networking (Intel WiFi AX201)
AetherOS includes a driver for the Intel Wi-Fi 6 AX201 (CNVi) module[cite: 11].
* Bootstraps the `iwlwifi` firmware via DMA upload directly to the device SRAM[cite: 11].
* Implements Gen2 TX/RX command queues for Host-to-Firmware communication[cite: 11].
