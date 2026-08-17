# Public / Private Repository Boundary

## Why the boundary exists

AetherOS is an active research project with implementation details that may carry intellectual-property or future product value. The public showcase is therefore designed to demonstrate the project's reality and architecture without publishing every source file, experimental kernel, low-level opcode sequence or deployment artifact.

## Public by design

This repository may contain:

- architecture descriptions;
- system diagrams;
- benchmark summaries;
- hardware proof matrices;
- high-level register/command-flow descriptions;
- validation methodology;
- selected historical optimization findings;
- public issue/discussion material.

## Private by default

Unless intentionally released, the following should remain outside the public showcase:

- full kernel source tree;
- complete Intel EU instruction emitter / binary kernels;
- proprietary compiler/backend implementation;
- complete experiment packages and deploy scripts;
- unpublished model-serving/product code;
- secrets, device identifiers that should not be public, or private logs;
- exploit-quality security details before remediation;
- code or assets whose third-party license does not allow redistribution.

## Claim policy

The public repository can state that a private implementation exists when that statement is backed by supplied hardware evidence. It should not invent unavailable source links or imply that readers can reproduce private-only implementation details from this repository.

## Contribution implications

External contributors should primarily target documentation, methodology, architecture critique, reproducibility discussion and public tooling unless a separate source release is made.
