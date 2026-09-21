# ROUND18HAR — steady qualification at 7.0775 tok/s

## Why HAR exists

HAQ's first candidate sample could include one-time code construction/install/flush/readback cost.

HAR fixed the qualification protocol instead of lowering the gate:

1. explicit warm-up pair;
2. two measured pairs;
3. balanced/reversed order;
4. unchanged exactness/promotion thresholds;
5. no fastest-sample selection;
6. no shadow-output publication.

## Fixed numeric matrix

`5.23, 7.08, 7.08, 7.08, 7.08, 7.08, 7.08, 7.07, 7.07 tok/s`

Preferred public steady value:

**7.0775 decode tok/s**

for the reviewed Llama 3.2 1B Instruct Q4_K_M configuration.

## Inspect

- [`raw/HAR/REPORT.md`](raw/HAR/REPORT.md)
- [`raw/HAR/AUDIT_REDUNDANT_WORK.md`](raw/HAR/AUDIT_REDUNDANT_WORK.md)
- [`raw/HAR/HAR_RESULT.json`](raw/HAR/HAR_RESULT.json)
- [`raw/HAR/collector.log`](raw/HAR/collector.log)
- [`raw/HAR/ROUND18HAR_COLLECT.ps1`](raw/HAR/ROUND18HAR_COLLECT.ps1)
- [`raw/HAR/HAR_AETHLOG.TXT`](raw/HAR/HAR_AETHLOG.TXT)
