# HAR: HAQ physical results and projection steady-state qualification

## Evidence identity and scope

The complete export contains819816 bytes, SHA256
`E8D3AA7AE5DFF73DE161335731A5FCA9C1D7D141EC833C0986500842101153DA`.
It came from exact HAQ kernel
`2E0E0FB0C73844512B97B0C4D26EBD8EFEE297950CE8A754E8C1C9737E194480`.
`tests/ANALYZE_HAQ.ps1` parses5611 tagged rows and preserves the complete tag
census, per-request denominators, timing families and component evidence.

Twelve requests completed. Request6 produced15 outputs and request11 produced91;
the other ten produced128. The inherited collector reports no invariant issues
and no fatal events, but correctly classifies `HAQ_STEADY_MATRIX_INCOMPLETE`:
the fixed5..8 full128 matrix is incomplete. A complete exported log is not the
same as a complete length-controlled benchmark. Do not relabel later requests.

Requests5/7/8 report6.77/6.70/6.74TPS, mean6.7367. Full128 post-proof requests
5/7/8/9/10/12 average6.7467TPS. These are descriptive subsets, not a new fixed
matrix or a controlled causal comparison to HAP's observed5..7 mean6.5533.
Request6's7.28TPS is short-output denominator bias, not an optimization win.
Answer semantics, final-pixel latency and repeated cold boots remain unverified.

## Verified benefits within this boot

All64 HAQ Down pairs and all inherited64-pair laboratories passed finite
bitwise comparisons. HAQ Down and HAP Gate each own22897 production graphs;
HAQ Q4 Down owns11448. HAO remains qualified but has zero actual Down calls,
as intended for exclusive ownership. No parent failures or fallbacks appeared.

Across the32 Q4-only pairs, Down latency decreased6.073%, and captured graph
latency decreased1.675%. All four full-vocabulary LMH pairs passed; wall time
decreased5.202%, native GT5.460%. LMH candidate live count is1258. Q6 controls
do not contribute to Q4 speed qualification. These are paired measurements,
not the static instruction-count percentages from the preceding round.

Projection single512 and QKV3072 promoted independently, with11458/11456 live
calls. Single2048 passed all four exact comparisons, never disabled, but did
not promote and has0 live calls despite38849 completed opportunities.

## Missed opportunity: cold installation mixed into the steady gate

| single2048 request | Control wall | HAQ wall | Control wait | HAQ wait |
|---|---:|---:|---:|---:|
| 1 |2467952|4006384|1827036|1272310|
| 2 |2098406|1571330|1832956|1261890|
| 3 |2045852|1517464|1782520|1255678|
| 4 |2153074|1742386|1890252|1377630|

Units are TSC cycles, not microseconds. Request1 candidate overhead outside
submit/wait is2734074 cycles versus640916 for control. Source inspection shows
that `run` starts wall timing before the first candidate image construction,
installation, flush, readback and install diagnostic. The first candidate alone
pays that model-lifetime setup. The two-request aggregate wall ratio0.81868
therefore rejected the candidate, although its first-pair GPU wait was lower.

Requests2..4 show23.282% lower aggregate wall and29.252% lower wait for2048.
These later observations motivate a fresh experiment; they are not retroactively
substituted into HAQ's gate. The excess overhead cannot all be attributed to
installation without a finer timestamp, and request1 QKV also shows cache/
startup effects. HAR separately reports a symmetric warm-up pair and requires
new balanced measurements on the next boot.

## HAR change and boundaries

No shader, floating-point operation, reduction order, model layout or threshold
changes. For each of three projection paths and each of requests1..4:

1. Run one control/candidate warm-up pair. Preserve all physical pre/post image
   checks, restoration, positive timing, finite output and bitwise equality.
   Log its full wall and wait costs separately; never publish either output.
2. Run two measured pairs with reversed order, ABBA or BAAB. Sum both samples
   for each arm; never choose the fastest sample, retry a slow one, or discard
   a failed warm-up. Fresh first-two-request sums decide promotion with the
   unchanged1.005 wall and1.020 wait thresholds.
3. Requests3/4 remain exact canaries. An arithmetic mismatch revokes only that
   path; a transport failure stops immediately before the next arm. Shadows
   do not increment production counters. A separate actual call owns output.

The warm-up cost remains in request wall/TTFT; it is excluded only from the
explicitly steady-state gate. First-four-request proof cost increases from
two to six shadow dispatches per path/request. No additional dispatches,
allocations, hashes, warm-ups or copies are added to the steady production
path. The QKV post-response bootstrap remains non-production. No-gain fallback
remains valid, and this round does not force the2048 path on.

## Whole-system prioritization

Full128 requests5/7/8 average200.508M FFN,85.933M attention and93.206M LMH
cycles/output. FFN remains largest, but its paired HAQ gain is already active.
The blocked2048 projection is a directly evidenced recoverable opportunity in
the actual attention path, without another arithmetic or residency redesign.
Q6's already rotating headers and proven Gate/Down arithmetic remain intact.

Tokenization spans0.126..1.374s for these requests and reaches37% of request7
TTFT; queueing is about0.3s after request1. Neither is fixed by this round.
No new long-history indexing implementation is justified solely by these short
prompts. Existing HAK/tokenization semantics, guards, fences, flushes and
physical-hash checks are retained. Memory roof estimates are not proof of a
physical bandwidth wall. No10TPS, global optimum or stability claim is made.
