# Adversarial Review — Public Release Gate

## Attack 1 — "These are self-produced logs; where is independent verification?"

**Valid criticism.**

Mitigation:
- state explicitly that the evidence is internal,
- publish raw source/log slices,
- invite external review,
- do not use the words "independently verified" or "certified" without a named external verifier.

Next credibility milestone: one external systems/GPU engineer reproduces or audits one bounded claim.

## Attack 2 — "This is AI-generated OS code; does the author understand it?"

This will be the highest social-risk objection in OS-development communities.

Mitigation:
- disclose AI assistance before anyone has to ask,
- publish failure lineage, not only final code,
- answer technical questions personally,
- use BY as the strongest demonstration of mechanism-level understanding,
- never argue that line count or project size proves expertise.

A reviewer should be able to ask why `r109.3` crossed into `r110.0`, why HAS did not promote, or why HAR changed measurement protocol, and receive a precise answer.

## Attack 3 — "7.08 tok/s compared with what?"

**Valid criticism.**

The current release establishes an internal operating point, not competitive superiority.

Do not claim AetherOS is faster than Linux, llama.cpp, Vulkan, OpenCL or another runtime without a same-machine matched-model comparison.

A same-hardware reference benchmark is a useful future experiment, but it is not required to publish the present systems-engineering evidence.

## Attack 4 — "The performance timeline looks causal."

The historical operating-point graph can be misread as a single controlled benchmark.

Mitigation:
- label the chart prominently: protocols differ by round,
- direct readers to the benchmark methodology,
- use paired percentages only inside the round that measured them.

## Attack 5 — "Gen9 is vague."

Use the exact device identity in technical contexts:

`PCI 8086:9b41 — Intel UHD Graphics / CML GT2, Gen9-class`

This is harder to dispute than a broad product-family label.

## Attack 6 — "Bare-metal means no Linux anywhere, right?"

Do not make that claim.

The supported claim is:
**AetherOS performs the reviewed inference at runtime without a Linux host OS.**

That says nothing about the development/build workstation or third-party toolchain.

## Attack 7 — "Why is the model filename Q4_K_M if some tensors are Q6_K?"

Do not imply every tensor is Q4.

GGUF mixed tensor types are visible in the runtime evidence. The filename is the model quantization label, not a promise that every tensor has one quant type.

## Attack 8 — "Why is RUN01 request 8 above 8 tok/s?"

Because it is only eight generated tokens. It is excluded from the sustained headline.

Keep HAR's complete 128-token matrix as the public performance anchor.

## Attack 9 — "Why should I trust a 7.768x number if it didn't ship?"

You should not interpret it as token throughput.

It is a bounded DV microbenchmark result. The evidence release highlights the rejection precisely to prevent that substitution.

## Attack 10 — "Where is the entire source repository?"

Public Evidence Release v1.1 publishes bounded source/log slices needed to inspect its three representative claims.

Full-source publication is a separate product decision. Do not imply that the complete AetherOS source is open if it is not.

## Release verdict

**Suitable for a controlled public technical launch after v1.1 source/log slices are present.**

The release is not ready to claim independent validation or competitive benchmark leadership.
