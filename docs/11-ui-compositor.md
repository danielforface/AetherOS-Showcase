# Graphics, Compositor & System UI

## Purpose

AetherOS includes a native framebuffer UI because the target machine is a complete bare-metal environment, not merely a headless accelerator test.

## Compositor

The compositor uses double buffering and dirty-region rendering. The historical architecture calls this render-on-demand model **ABSOLUTE ZERO**.

The primary target framebuffer is 1920×1080, 32bpp BGR.

## Core separation

UI rendering remains associated with Core 0 so inference orchestration and worker cores can be isolated from display work.

F10 Turbo mode can suppress UI rendering during active generation to reduce contention.

## Design systems

### Obsidian
Dark operational language used for live telemetry, system state, compute dashboards and debugging.

### Atticus
Light analytical language intended for structured inspection and lower-noise analysis views.

## Built-in engineering surfaces

The project includes system-level applications and labs such as:

- Neural Dashboard;
- Pipeline / chat interface;
- Hardware Lab / Project X-Ray;
- integrity and performance views;
- Silicon Lab for GPU experimentation;
- explorer/editor/system monitor surfaces.

These interfaces are part of the research workflow: hardware state and model execution can be inspected from the same machine that owns the bare-metal runtime.
