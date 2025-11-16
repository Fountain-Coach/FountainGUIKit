# FountainGUIKit — Implementation Plan & Definition of Done

This plan tracks implementation of FountainGUIKit from the first NSView host to MetalViewKit/MIDI2 integration. It complements `AGENTS.md`, which describes the target design. When reality diverges from this plan, update both the milestones here and the relevant sections in `AGENTS.md`.

## High‑level goals

- Provide a small, NSView‑based GUI core (event model + node graph) that is independent of AppKit’s responder chain and SwiftUI.
- Make it trivial to host MetalViewKit renderers inside the node graph and treat them as MIDI 2.0 instruments with stable identities and property schemas.
- Enable deterministic, robot‑friendly testing by routing keyboard/mouse events and MIDI 2.0 messages through the same explicit event system.

## Milestones and DoD

### M1 — Core event model and root view

**Scope**
- Define canonical event types:
  - `FGKEvent`, `FGKKeyEvent`, `FGKMouseEvent`.
- Introduce the node graph and responder interface:
  - `FGKEventTarget` protocol.
  - `FGKNode` tree with `bubble(event:)` and optional `instrumentId`.
- Provide a single NSView entry point:
  - `FGKRootView` that maps `NSEvent` → `FGKEvent` and dispatches via `FGKNode`.

**Definition of Done**
- `swift build` for the FountainGUIKit package succeeds on macOS with these types exported.
- Basic unit tests exercise:
  - Event bubbling from a leaf node up to its parent.
  - Keyboard and mouse events mapped from synthetic `NSEvent` into `FGKEvent` in `FGKRootView`.
- `AGENTS.md` accurately documents the public API surface and event flow.

**Status**
- DONE: core types exist, tests cover bubbling and event mapping, and AGENTS/README are aligned.

### M2 — Layout and hit‑testing

**Scope**
- Add lightweight layout metadata to `FGKNode` (e.g. local frame in a shared coordinate space).
- Implement a deterministic hit‑testing helper that:
  - Chooses an initial target node for mouse events based on position.
  - Falls back to bubbling when no child consumes the event.
- Keep layout engine minimal (no full constraint solver), focused on canvas‑like scenes.

**Definition of Done**
- A hit‑testing API exists (e.g. `FGKNode.hitTest(at:)`) and is covered by unit tests.
- Mouse events dispatched from `FGKRootView` are routed to the node returned by hit‑testing before bubbling.
- `AGENTS.md` and `PLAN.md` document how hit‑testing interacts with event bubbling.

**Status**
- DONE: `FGKNode` exposes a frame and `hitTest(_:)`, tests cover hit‑testing and mouse dispatch, and AGENTS/PLAN document the behaviour.

### M3 — MetalViewKit adapter

**Scope**
- Design and implement a small adapter that binds a MetalViewKit renderer to a `FGKNode`:
  - Map FGK events to `MetalSceneRenderer` calls (e.g. focus, interaction).
  - Provide a place to expose the renderer’s property schema (name → type/range).
- Ensure the adapter stays NSView‑only (no SwiftUI) and does not depend on CoreMIDI.

**Definition of Done**
- A hostable MetalViewKit “instrument” can be attached to an `FGKNode` and rendered inside an AppKit window using `FGKRootView`.
- The adapter maintains a stable `instrumentId` that can be used later for MIDI 2.0 CI/PE.
- Example code (in README or tests) shows a minimal triangle/quad scene hosted via FountainGUIKit.

**Status**
- DONE (FountainGUIKit layer): the package defines `FGKInstrumentSink`, `FGKInstrumentAdapter`, and `FGKNode.attachInstrument(sink:)` so that MetalViewKit renderers can integrate from consuming packages. Concrete MetalViewKit wiring remains in FountainKit.

### M4 — MIDI 2.0 CI/PE integration

**Scope**
- Add optional MIDI 2.0 plumbing so that nodes with an `instrumentId` can:
  - Expose a property schema over CI/PE.
  - Receive and apply PE SET messages as property updates.
- Use existing `MIDI2`/`MIDI2Transports` infrastructure; no CoreMIDI usage.
- Ensure UI‑initiated changes (via FGK events) and MIDI‑driven changes share the same internal representation.

**Definition of Done**
- For an instrument‑backed node, property changes from MIDI 2.0 PE SET produce the same visual/effective result as the equivalent UI action.
- A small test harness (or sample app) can:
  - Discover FountainGUIKit instruments.
  - Read their schema.
  - Drive properties via UMP and observe deterministic effects.
- `AGENTS.md` documents the CI/PE mapping contract and any limitations.

**Status**
- DONE (FountainGUIKit layer): nodes expose a property schema (`[FGKPropertyDescriptor]`), a canonical value type (`FGKPropertyValue`), and a local setter (`setProperty(_ name:value:)`) that forwards to `FGKPropertyConsumer` targets. Concrete CI/PE ↔ property mapping remains in FountainKit, using these types as the application‑level contract.

### M5 — Consumers, docs, and stability

**Scope**
- Wire FountainGUIKit into at least one consuming app (for example a dedicated demo executable) as the GUI host.
- Add operator‑facing documentation:
  - `README.md` with quick start and API overview.
  - Pointers into the FountainKit repo where MetalViewKit renderers live.
- Stabilise APIs (marking them public/internal as appropriate) and adopt semantic versioning.

**Definition of Done**
- At least one executable target uses FountainGUIKit for its hosting and event routing (for example `fountain-gui-demo` in this package or a consumer in FountainKit).
- All public symbols are documented in `AGENTS.md` and mirrored in `README.md`.
- The package builds cleanly under CI with tests passing for all implemented milestones.

**Status**
- DONE (package‑local demo): the `fountain-gui-demo` executable target hosts an `FGKRootView` and logs events, and AGENTS/README describe how to consume the library from other packages.

### M6 — Testing, MRTS, and PB‑VRT integration

**Scope**
- Establish a testing strategy that keeps FountainGUIKit aligned with FountainKit’s MRTS (MIDI Robot Test Script) and PB‑VRT (Prompt‑Bound Visual Regression Testing) philosophy.
- In this package:
  - Provide focused XCTest suites for `FGKEvent`, `FGKNode`, and `FGKRootView` (event mapping, bubbling, and basic layout/hit‑testing once added).
  - Add helper APIs to render `FGKRootView` into an image buffer for snapshot‑style consumers.
- In FountainKit (consumers):
  - Define how a FountainGUIKit‑hosted surface participates in MRTS (driven via MIDI 2.0 instruments) and PB‑VRT (frame capture and comparison).

**Definition of Done**
- Local: `swift test` for FountainGUIKit exercises event routing, bubbling, and any layout/hit‑testing logic with deterministic expectations.
- Integration: at least one FountainApps test target uses FountainGUIKit surfaces as the render host for:
  - an MRTS‑style robot test (driving properties via MIDI 2.0 or instrument events),
  - and/or a PB‑VRT baseline frame captured through a FountainGUIKit‑backed NSView.
- `AGENTS.md` and FountainKit’s relevant AGENTS/testing docs document how FountainGUIKit surfaces are expected to be used in MRTS and PB‑VRT scenarios.

**Status**
- TODO: only basic XCTest scaffolding exists; MRTS/PB‑VRT integration points are design‑only.

### M7 — Full gesture and pointer support

**Scope**
- Provide a complete, predictable mapping from AppKit pointer and gesture events into FountainGUIKit’s event and property model, so trackpad/mouse users experience the framework as a first‑class, modern UI surface.
- Cover, at minimum:
  - Secondary and other mouse buttons: `rightMouseDown/Up`, `otherMouseDown/Up`, corresponding drag variants.
  - Dragging: `mouseDragged`, `rightMouseDragged`, `otherMouseDragged`.
  - Scrolling: `scrollWheel(_:)` with support for high‑resolution deltas and trackpad momentum.
  - Pinch/zoom: `magnify(with:)`.
  - Rotation: `rotate(with:)`.
  - Swipes and gesture lifecycle: `swipe(with:)`, `beginGesture`, `endGesture`.
- Decide and document how each gesture maps to:
  - FGK‑level event types (new `FGKEvent` cases and payload structs), and/or
  - property changes via `FGKNode.setProperty(_ name:value:)` (for example `canvas.zoom`, `canvas.translation.x/y`), and/or
  - vendor events delivered to `FGKInstrumentSink` for MetalViewKit renderers.

**Definition of Done**
- `FGKEvent` and its companion structs represent all supported gesture categories with typed payloads.
- `FGKRootView` overrides the relevant NSView gesture methods and:
  - maps them into FGK events and/or property changes,
  - routes them through the node graph using the same hit‑testing and bubbling model as mouse events.
- `AGENTS.md` clearly documents:
  - which gestures are supported,
  - how they are dispatched (event vs property vs vendor event),
  - and how consumers should interpret them (for example, canvas zoom vs content scroll).
- Tests in `FountainGUIKitTests` cover:
  - at least one representative case per gesture category (scroll, magnify, rotate, swipe, drag),
  - and verify that events/properties reach the expected node/target with correct values.

**Status**
- DONE (FountainGUIKit layer): `FGKEvent` and `FGKRootView` map drag, scroll, magnify, rotate, and swipe events into typed FGK events and route them through the node graph. Recommended gesture→property semantics are documented in `AGENTS.md`; downstream MRTS/PB‑VRT usage will be handled from consumers in FountainKit.

## Gap tracking

Use this section as a quick checklist when starting a new implementation session:

- [ ] M1 core types and tests implemented and green.
- [x] M1 core types and tests implemented and green.
- [x] M1 documented in `AGENTS.md` and README.
- [ ] M2 layout metadata and hit‑testing in place.
- [x] M2 layout metadata and hit‑testing in place.
- [x] M2 hit‑testing behaviour covered by tests.
- [ ] M3 MetalViewKit adapter designed and implemented.
- [x] M3 MetalViewKit adapter designed and implemented.
- [ ] M3 example code demonstrating hosting of a MetalViewKit scene via FountainGUIKit.
- [x] M4 MIDI 2.0 CI/PE integration for instrument nodes.
- [x] M4 CI/PE behaviour documented and testable.
- [x] M5 at least one app consuming FountainGUIKit.
- [ ] M5 docs and API surface stabilised.
- [ ] M6 local FountainGUIKit tests cover event routing and layout.
- [ ] M6 at least one MRTS/PB‑VRT scenario uses a FountainGUIKit surface as the render host.
- [x] M7 full gesture/pointer support implemented (AppKit → FGK mapping).
- [x] M7 gesture behaviour documented and covered by tests.

When any item flips from unchecked to checked, update both this file and the relevant sections in `AGENTS.md`.
