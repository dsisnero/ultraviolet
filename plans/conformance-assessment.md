# Conformance Harness Assessment

**Status:** Complete — not ported (intentional divergence)
**Upstream scope:** `vendor/ultraviolet/internal/conformance/`
**Date:** 2026-10-19

## What the Go harness does

The Go conformance suite decodes fuzz bytes into renderer operation programs,
runs them incrementally against a terminal emulator, and compares the final
screen with a from-scratch repaint. It depends on:

- Go fuzzing (`testing.F` / `go test -fuzz`);
- a cgo terminal-emulator oracle (`libghostty-vt`);
- the operation/seed corpus in `internal/conformance`.

The value comes from differential comparison against a real emulator, not from
asserting individual escape sequences.

## Decision

Do **not** port the harness to Crystal at this time.

Reasons:

1. The emulator oracle is the part that makes the harness meaningful, and there
   is no Crystal binding for it. Porting only the fuzz decoder and operation
   runner would add maintenance without any screen-level assertion.
2. Crystal already covers the portable cases with renderer resize/damage,
   styled-string, buffer, width, and terminal I/O specs (394 examples).
3. The inventory has **zero missing runtime rows**. The remaining conformance
   rows are classified as intentional divergences.
4. The harness is Go tooling, not a public API of the shard.

## What we keep

- The drift-cluster and operation-program ideas as references when debugging
  renderer resize or width issues.
- The saved Go corpus as a source of concrete sequences to reproduce manually.
- `plans/update-vendor-6b8d4ba.md` Phase 9 as the decision record.

## Revisit when

- a Crystal terminal-emulator oracle becomes available, or
- a renderer bug escapes the existing regression specs and needs differential
  screening.

Until then, the conformance inventory rows stay `intentional_divergence`.
