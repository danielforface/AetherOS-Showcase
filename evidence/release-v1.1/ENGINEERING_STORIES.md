# Three Engineering Stories

## Story 1 — BY: from unexplained mismatch to causal register proof

The problem was not approached by widening the patch surface.

BX first tested six plausible timing/retirement/scoreboard explanations. All failed.

Source audit then found a narrower mechanism: a helper named like a scalar move emitted an SIMD8 broadcast. In the final reconstruction copy, the write footprint crossed from `r109.3` into `r110.0..2`, overwriting a live ROTATE4 accumulator.

The experiment predicted a specific signature:

- unsafe path should replace `r110.0` with `tile[255]`,
- exact scalar repair should preserve the accumulator sentinel.

Hardware matched the prediction:

- unsafe: 2048/2048 overwrites,
- repaired: 2048/2048 sentinels preserved,
- unsafe full kernel: 2048 mismatches, all `row % 4 == 0`,
- repaired full kernel: 8192/8192 exact.

Then the process refused to declare victory: qualification later hit a fence timeout, so the arithmetic repair was retained while lifecycle work continued in BZ/CA.

**Why it matters:** this is not just a bug fix. It is hypothesis → predicted signature → physical reproduction → narrow causal repair → independent lifecycle gate.

---

## Story 2 — DV: when 7.768x is still not enough

A Q4 multicolumn reuse experiment attacked redundant weight work across output columns.

Controlled kernel results:

- B=1: 1.011x
- B=2: 1.924x
- B=4: 3.386x
- B=8: **7.768x**

The B=8 result was exact and clean.

But the full FFN graph did not gain enough. In some graph cases the candidate was slightly slower.

The round ended:

`CORRECT_BELOW_ARCHITECTURAL_GAIN`

and the production path was not changed.

**Why it matters:** this is a direct example of resisting benchmark theatre. A spectacular microbenchmark number was not promoted into an end-to-end claim.

---

## Story 3 — HAR: fixing the benchmark before accepting the result

HAQ found real projection gains, but its first-candidate measurements contained one-time construction/install/flush/readback costs.

That meant the benchmark could reject a genuinely faster steady path for the wrong reason.

HAR did not lower the threshold. It changed the qualification protocol:

- one explicit warm-up pair,
- two measured pairs,
- balanced/reversed order,
- same exactness checks,
- same admission thresholds,
- no fastest-sample selection,
- no shadow-output publication.

Only after correcting the measurement did all three projection paths qualify.

The resulting fixed matrix:

`5.23, 7.08, 7.08, 7.08, 7.08, 7.08, 7.08, 7.07, 7.07 tok/s`

Certified steady value:

**7.0775 tok/s**

**Why it matters:** benchmark methodology is treated as part of the system, not as post-hoc storytelling.
