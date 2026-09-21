# Round18DV run plan

1. Cold boot the pinned USB.
2. Load the same Q4_K model used for Round18DU.
3. Send one ordinary GPU-routed request and allow it to finish. This executes
   the full B=1/2/4/8 matrix and the first full-shape FFN graph gate.
4. Preferred: send three more GPU-routed requests to close the four-request
   graph census. CPU-only requests are explicitly logged and do not consume the
   GPU count.
5. Return the USB and execute `ROUND18DV_COLLECT.ps1 -Finalize`.

Required early evidence: one `[GPU-DV-BEGIN]`, four `[GPU-DV-BATCH]` records,
one `[GPU-DV-BATCH-FINAL]`, one `[GPU-DV-EARLY-FINAL]`, three
`[GPU-DD-CASE]` records and no DV publication marker.

Required full evidence adds four consumed GPU requests, twelve graph cases and
one `[GPU-DV-FINAL]`.

