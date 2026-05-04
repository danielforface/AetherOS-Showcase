# Graphics & UI Framework

## The Compositor
The AetherOS compositor operates on a "Render-on-Demand" architecture (ABSOLUTE ZERO).
* It utilizes a double-buffered layout with dirty-rectangle tracking (up to 256 rects) to copy only modified regions to the linear framebuffer.
* Targets a steady 60 FPS pacing loop.
* Supports 15 distinct `CompositorMode` states, including Desktop, Neural Dashboard, Terminal, and hardware debugging labs.

## Dual Design System
AetherOS features two pixel-perfect, cohesive design languages:
1. **Obsidian Theme (Dark):** Used for active runtime and operational tools. Features deep navy backgrounds with cyan and amber neon accents, utilizing a heatmap gradient for tensor visualization.
2. **Atticus Theme (Light):** A neoclassical, minimalist design for analytical interfaces, utilizing strict 8px grids and relying on luminance shifts rather than drop shadows.

## Global Control Keys & App Framework
* Input from PS/2 devices is handled via lock-free queues routed to a centralized 5-level priority Global Control Keys registry.
* Over 18 built-in applications interact directly with atomic system states, eliminating heap allocation during the render path.
* Key tools include the **Hardware Lab (PROJECT X-RAY)** for live PCI/USB debugging, and the **Silicon Lab**, an autonomous genetic fuzzer for GPU Execution Units.
