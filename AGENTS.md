# AGENTS.md — kustomize-ultraviolence

## Kustomize work style

Prefer rapid prototyping over extended reasoning. Kustomize has enough
undocumented edge cases that mental modeling alone produces confident-but-wrong
conclusions.

**Rendering validation (strict):** use **kustomize-mcp only** — not the shell
`kustomize` / `kubectl kustomize` — for any render used to validate layout or
to compare before/after. This keeps one pipeline (checkpoints, inventory, trace)
and avoids subtle drift from CLI options or versions.

**Default loop:** form a hypothesis → write the minimal files → render via
kustomize-mcp (checkpoints, inventory, trace) → inspect the output → adjust.
Two or three quick render cycles beat ten minutes of speculative analysis.
Only slow down for deliberate design once the mechanics are proven.

Use kustomize-mcp checkpoints to snapshot before/after states and diff them.
Use inventory to verify resource origins and transformer metadata. Use trace
to follow a specific resource back to its source file and transformers.

**Refactoring loop:** for any kustomize refactor (moves, renames, overlay
splits), follow this sequence every time: (1) create a **checkpoint** via
kustomize-mcp for the current render; (2) make the **smallest change** that
advances the refactor; (3) **validate** by rendering again and using the
kustomize-mcp **diff** against the checkpoint (or prior checkpoint) so only
intended deltas appear. Do not treat the refactor as done until the diff
review passes.

**Building from scratch:** start with the most straightforward flat scheme
that produces the desired end state — no layers, no abstraction. Use that
rendered output as the reference. Then refactor by extracting layers one at
a time, diffing each step against the reference to confirm equivalence.

**CI note:** GitHub Actions runs `kustomize build` (pinned kustomize) for
smoke coverage. For deep provenance, still use kustomize-mcp locally as above.
