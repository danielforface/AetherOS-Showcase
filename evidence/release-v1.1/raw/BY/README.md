# BY — Causal Repair Evidence

Start with `ROUND18BY_SOURCE_FINDINGS.txt`, then inspect `intel.rs.diff`, then search the physical log for:

- `root_proven`
- `8192`
- `tile[255]`
- `sentinel`
- `ROTATE4`

The log is the BY physical execution archived by the successor BZ package. This preserves the normal ROUND18 predecessor-evidence chain.
