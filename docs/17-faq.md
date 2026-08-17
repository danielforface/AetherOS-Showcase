# Frequently Asked Questions

## Is AetherOS Linux-based?
No. The default inference path is a bare-metal Rust kernel and does not require Linux or libc.

## Is the complete kernel source in this repository?
No. This is the public architecture and proof showcase. See [Public / Private Boundary](15-public-private-boundary.md).

## Does AetherOS really use the Intel integrated GPU without Mesa/OpenCL?
The documented target uses a direct Gen9 command-submission path built around RCS, GGTT and GPGPU Walker execution. The current proof matrix includes physical-hardware execution and bit-exact operator qualification.

## What model has been demonstrated?
The current documentation centers on LLaMA-3.2-1B-Instruct with Q4_K_M / Q6_K execution paths.

## What is the current speed?
The correct answer now has two parts. The **best verified clean 128-token E2E result** in the supplied logs is ROUND18EO at ~**3.411 tokens/s**. The **latest hardware architecture** is ROUND18FB; its best complete clean 128-token request is ~**3.271 tokens/s**. Newest and fastest are deliberately reported separately.

## What happened to the old ~78.36B cycles/token number?
It is an early hardware milestone. Later optimization rounds reduced the forward path by roughly two orders of magnitude. The old number remains in history but is not current performance.

## Did AetherOS become 7.768× faster in ROUND18DV?
That figure belongs to a **shadow multi-column candidate** at `B=8`. It demonstrated strong local acceleration and bit-exactness, but it was explicitly not production-published and should not be quoted as an end-to-end system speedup.

## Why not just use Linux + llama.cpp?
AetherOS is a systems research project exploring what changes when the OS, memory system and accelerator control are co-designed around inference. It is not claiming that a bare-metal system is automatically faster at every stage or on every workload.

## Is Wi-Fi production-ready?
The historical architecture contains significant AX201 driver work, but public claims should distinguish code presence from verified data-plane maturity. The strongest current AetherOS story is inference, storage, CPU/GPU compute and observability.

## Is AetherOS open source?
The complete kernel is not currently published under an open-source license. This showcase is public, but publication alone does not grant rights to the private implementation.
