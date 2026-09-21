# ROUND18BY — causal register-corruption repair

This evidence slice is intentionally bounded.

## Claim

A reconstruction path used a helper that emitted an SIMD8 write footprint where an exact scalar write was required. The final write beginning at `r109.3` crossed into `r110.0`, a live ROTATE4 accumulator.

## Physical signature

Unsafe:
- 2048/2048 threads: `r110.0 == tile[255]`
- 0/2048 sentinels survived

Repaired:
- 2048/2048 sentinels survived
- 0/2048 leaked `tile[255]`

Full kernel:
- unsafe: 2048 mismatches, all `row % 4 == 0`
- repaired: 8192/8192 exact

The later qualification still encountered a separate fence/lifecycle failure. The arithmetic repair and lifecycle qualification are therefore not conflated.

## Inspect

- [`raw/BY/ROUND18BY_SOURCE_FINDINGS.txt`](raw/BY/ROUND18BY_SOURCE_FINDINGS.txt)
- [`raw/BY/intel.rs.diff`](raw/BY/intel.rs.diff)
- [`raw/BY/ROUND18BY_REPORT.txt`](raw/BY/ROUND18BY_REPORT.txt)
- [`raw/BY/ROUND18BY_AETHLOG.txt`](raw/BY/ROUND18BY_AETHLOG.txt)
