# Doc — FountainGUIKit Documentation Guide

This directory contains human‑oriented documentation for FountainGUIKit. It complements the root `AGENTS.md` (design narrative) and `PLAN.md` (implementation milestones). Documents here are reference material; do not treat them as the design source of truth.

## Layout

- `Building-a-Custom-GUI-Framework-with-MetalViewKit-and-MIDI2-Integration.md`
  - Markdown transcription of the design note “Building a Custom GUI Framework with MetalViewKit and MIDI2 Integration”.
  - Explains the motivation for using MetalViewKit as a MIDI‑friendly rendering layer and for building an explicit event system and responder model.

## Source of truth

- Architectural decisions and public APIs are owned by:
  - root `AGENTS.md` — design and integration contracts,
  - `PLAN.md` — milestones and Definition of Done.
- Documents under `Doc/` may add background, rationale, or extended discussion, but they must not introduce conflicting rules. When there is a conflict, follow `AGENTS.md` and `PLAN.md`.

## Maintenance

- When the design of FountainGUIKit changes:
  - update `AGENTS.md` and `PLAN.md` first,
  - then revise or annotate any relevant documents under `Doc/`.
- If you add new design papers or notes, prefer Markdown and link them from this file so agents and humans can find them easily.

