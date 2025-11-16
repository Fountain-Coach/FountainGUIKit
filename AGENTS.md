# FountainGUIKit — MetalViewKit × MIDI2 GUI Framework

This repository hosts **FountainGUIKit**, a reusable GUI framework built on top of MetalViewKit and the MIDI 2.0 stack from FountainTelemetryKit. It provides opinionated, instrument‑centric building blocks (views, scene renderers, and transports) for apps like PatchBay, Composer Studio, and future FountainAI surfaces.

What
- Targets a SwiftPM library package named `FountainGUIKit`.
- Wraps `MetalViewKit` primitives into higher‑level controls (canvas, instruments, inspectors) with MIDI 2.0 Property Exchange semantics.
- Integrates with `MIDI2`/`MIDI2Transports` for loopback/RTP‑based testing and live control, without using CoreMIDI.

Why
- Centralise cross‑app GUI patterns (Metal‑backed canvases, instrument overlays, inspectors) in a dedicated kit instead of duplicating them across `FountainApps`.
- Ensure every new GUI surface is “instrument‑ready” by construction: stable identities, PE schemas, and MIDI‑driven invariants.

How
- Implement reusable SwiftUI/AppKit components as library targets under `Sources/FountainGUIKit/**`.
- Depend on `MetalViewKit` and `MIDI2Transports` from the FountainKit workspace once wired as a dependency.
- Keep CoreMIDI out of this repo entirely; transports are loopback/RTP/BLE only.

Next steps
- Align the framework design with `Building a Custom GUI Framework with MetalViewKit and MIDI2 Integration.pdf` on your Desktop.
- Add a `README.md` that documents the primary view types, expected MIDI 2.0 behaviour, and how apps should consume the package.

