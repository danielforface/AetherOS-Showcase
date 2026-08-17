# Validation & Promotion Methodology

## Objective

The optimization process attempts to maximize hardware utilization without sacrificing reproducibility or numerical correctness.

## Reference-first testing

Optimized GPU/CPU candidates are compared against known-correct reference executions.

Typical qualification dimensions include:

- exactness flag;
- mismatch count;
- maximum absolute difference where floating comparison is appropriate;
- timeout count;
- GPU fault registers;
- fence completion;
- recovery count;
- repeated-run stability;
- cycle distribution.

## Shadow before production

Large or aggressive experiments can execute in **shadow mode**. Shadow mode allows AetherOS to measure speed and correctness while preventing the candidate from becoming the result published to the production graph.

This is how the project can test large execution geometry changes without treating rollback as an afterthought.

## Version barriers and rollback

Optimization rounds are treated as explicit versioned experiments. A round should preserve:

- exact source predecessor identity;
- baseline hash;
- patched hash;
- deployed kernel hash;
- rollback artifact;
- validation report;
- hardware log.

The public showcase does not contain all private round packages, but this process explains the naming and evidence in the performance history.

## Bit-exactness

Where the numerical representation permits exact comparison, promotion requires exact output equality. The project uses explicit per-component flags for fused GPU projections rather than inferring correctness from downstream token output alone.

## Fault telemetry

Gen9 work is evaluated alongside:

- command completion;
- `FAULT_REG`;
- error/interrupt status registers where applicable;
- fence state;
- timeout state;
- recovery path activity.

## Performance measurement

AetherOS uses RDTSC-based cycle measurements inside the bare-metal runtime. Cycle counts are preferable to host-side wall-clock alone because they expose operator-level cost with much lower measurement ambiguity.

End-to-end tokens/s is still retained because it is the user-visible system metric.
