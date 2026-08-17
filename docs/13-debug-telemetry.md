# Debugging & Telemetry

## Philosophy

AetherOS treats observability as a system feature rather than temporary instrumentation.

## Serial telemetry

The serial channel is the primary ground-truth stream for hardware qualification. It is used to record:

- boot phases;
- memory layout;
- PCI enumeration;
- xHCI state;
- GPU ring/fence/fault state;
- model loading;
- operator cycles;
- exactness results;
- recovery activity;
- token-generation metrics.

## Profiler categories

The historical runtime includes per-token accounting categories such as:

- allocation cycles;
- attention cycles;
- FFN cycles;
- norm cycles;
- embedding cycles;
- LM Head cycles;
- sampling cycles;
- total forward cycles.

## Hardware labs

The GUI includes engineering modes for device inspection and silicon experimentation. These are useful because AetherOS has no host OS beneath it to provide standard debugging facilities.

## Evidence retention

A complete optimization round should preserve the serial log alongside source/deployment hashes so later performance claims can be tied back to the executed kernel.
