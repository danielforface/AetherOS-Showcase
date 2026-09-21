# Round18DV experiment ledger

- Predecessor hardware log SHA256:
  `319D877A84D5D65640D76A98BC116F3AEDDA7921C4616B08515CB98771BFF946`
- Predecessor kernel SHA256:
  `55B7B558C63B0679DA092D632F26A11C8289C42D5CAE9B72001D908D337D7EE1`
- DU result: 12/12 exact 1OW controls; 34/34 clean 2OW completions with no
  returned payload; 2OW retired.
- Production baseline from DU: 128 tokens, 1,257,803,243 cycles/token,
  approximately 1.590 token/s at 2 GHz; FFN 66.3%, attention 20.9%, LM head
  12.3%; 80 submissions/fences per token.
- DV independent variable: number of activation columns sharing one streamed
  packed-weight block (`B=1,2,4,8`).
- Fixed variables: SFID10, 1OW/rsp=1, factored Q4 arithmetic, 32 blocks,
  seven interleaved repetitions, production output disabled.
- Correctness gate: bit equality to B separate B=1 hardware dispatches,
  completion metadata, fault/recovery deltas and resident restoration.
- Graph gate: real full-shape packed Gate+Up plus GPU SwiGLU in one command and
  fence, compared with packed Gate+Up plus CPU SwiGLU.
- Serious gain: B8 median speedup ≥1.5x. Useful gain: ≥1.1x. Lower exact
  results direct the next round to speculative/multi-sequence scheduling, not
  wider transport.

