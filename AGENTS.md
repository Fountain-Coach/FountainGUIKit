# FountainGUIKit — MetalViewKit × MIDI2 GUI Framework

This repository hosts **FountainGUIKit**, a reusable GUI framework built on top of MetalViewKit and the MIDI 2.0 stack from FountainTelemetryKit. It provides opinionated, instrument‑centric building blocks (views, scene renderers, and transports) for apps like PatchBay, Composer Studio, and future FountainAI surfaces. This file is the **source of truth** for the framework’s design: update it first, then keep code, `PLAN.md`, and README aligned.

## Scope

- Targets a SwiftPM **library** product named `FountainGUIKit`.
- Provides an **NSView‑only** host (`FGKRootView`) plus a pure‑Swift scene graph (`FGKNode`) and event model (`FGKEvent`).
- Is independent of SwiftUI: apps may wrap `FGKRootView` in SwiftUI if they choose, but no SwiftUI symbols live in this package.
- Is independent of AppKit’s responder chain semantics: events are routed through FountainGUIKit’s own node graph, not via `NSResponder`.
- Ships a small demo executable target (`fountain-gui-demo`) that embeds `FGKRootView` in an AppKit window for manual exploration and smoke testing.

MetalViewKit and MIDI 2.0 are **design anchors**, not hard dependencies yet. As the kit evolves, it will gain adapters that host `MetalViewKit` renderers and speak MIDI 2.0 CI/PE, but the core stays small and AppKit‑only. For background and rationale, see `Doc/Building-a-Custom-GUI-Framework-with-MetalViewKit-and-MIDI2-Integration.md`.

## Design principles

- **Instrument‑first**: every interactive element can be treated as a MIDI 2.0 instrument with a stable identity and property schema.
- **Event‑explicit**: keyboard and mouse events are represented as typed values (`FGKEvent`) and dispatched through a known path. No “mystery” focus or responder behaviour.
- **NSView host, not a UI framework**: FountainGUIKit embeds into existing windowing systems via `NSView`, but owns its own hierarchy and event routing.
- **No CoreMIDI**: any future transport integration uses MIDI 2.0 loopback/RTP/BLE via the existing `MIDI2`/`MIDI2Transports` stack. CoreMIDI is never imported here.

Gestures (trackpad/mouse) are first‑class citizens in this model. The long‑term goal is to cover all AppKit pointer and gesture events (scroll, magnify, rotate, swipes, multi‑button clicks/drags) with explicit mappings into FGK events and/or instrument properties. Users should experience FountainGUIKit‑hosted surfaces as fully interactive, modern macOS views, not as “mouse‑only” legacy widgets.

## Current API layers

Public surface (initial draft, kept tiny and stable):

- `FGKEvent`, `FGKKeyEvent`, `FGKMouseEvent`
  - Canonical event types for keyboard, mouse, and gestures.
  - Map 1:1 from `NSEvent` in `FGKRootView`, but are decoupled so tests can construct them directly.
  - Gesture cases:
    - `.mouseDragged(FGKMouseEvent)` — pointer drag after a mouse down.
    - `.scroll(FGKScrollEvent)` — trackpad/mouse wheel scroll with high‑resolution deltas.
    - `.magnify(FGKMagnifyEvent)` — pinch/zoom gestures with a magnification factor.
    - `.rotate(FGKRotateEvent)` — rotation gestures with a rotation delta.
    - `.swipe(FGKSwipeEvent)` — swipe gestures with directional deltas (for example two‑finger left/right).
- `FGKEventTarget`
  - Protocol for anything that wants to receive events: `func handle(event: FGKEvent) -> Bool`.
  - Used by nodes to implement a Cocoa‑style responder chain without touching `NSResponder`.
- `FGKNode`
  - Pure‑Swift tree node (no NSView base class).
  - Holds `parent`, `children`, an optional `frame` in the root view’s coordinate space, optional `instrumentId` (future MIDI2/CI identity), a local property schema (`[FGKPropertyDescriptor]`), and a weak `FGKEventTarget`.
  - Implements `bubble(event:)` to walk `self → parent → …` until a target handles the event (event bubbling model, as described in the MetalViewKit demo docs).
  - Provides `hitTest(_:)` to find the deepest node whose frame contains a given point (children are traversed in reverse order so later‑added nodes are considered frontmost).
  - Provides `setProperty(_ name:value:)` as a local counterpart to CI/PE SET, forwarding to a target that conforms to `FGKPropertyConsumer`.
- `FGKRootView: NSView`
  - The only AppKit entry point.
  - Owns a `rootNode: FGKNode` and forwards `keyDown`, `keyUp`, `mouseDown`, `mouseUp`, `mouseMoved` as `FGKEvent` into the node graph.
  - For pointer events, uses `rootNode.hitTest(_:)` to choose an initial target node before bubbling; if no node claims the point, events bubble from `rootNode`.
  - Overrides gesture‑related NSView methods and maps them into FGK events:
    - `mouseDragged`, `rightMouseDragged`, `otherMouseDragged` → `.mouseDragged`.
    - `scrollWheel` → `.scroll`.
    - `magnify(with:)` → `.magnify`.
    - `rotate(with:)` → `.rotate`.
    - `swipe(with:)` → `.swipe`.
  - Always accepts first responder; apps control focus and wiring by choosing which node’s target consumes events.

Future layers (to be designed here before code is added):

- MetalViewKit adapters:
  - A small bridge that binds a `MetalSceneRenderer`‑like instrument sink to a `FGKNode` (event sink + property schema) without introducing SwiftUI.
  - At the FountainGUIKit layer this is expressed as:
    - `FGKInstrumentSink` — a minimal protocol with `vendorEvent(topic:data:)` that MetalViewKit renderers can conform to in consumers.
    - `FGKInstrumentAdapter` — an `FGKEventTarget` that forwards FGK events to an instrument sink using well‑known topics (for example `fgk.keyDown`, `fgk.mouseDown`) and typed payloads (`FGKKeyEvent`, `FGKMouseEvent`).
    - `FGKNode.attachInstrument(sink:)` — convenience to attach an adapter as a node’s target.
  - Optional MIDI 2.0 adapter that exposes a node’s properties via CI/PE and consumes UMP from loopback/RTP transports.

## Gesture semantics and recommended mappings

FountainGUIKit’s job is to expose gestures as **typed events** and let host apps decide how to interpret them. To keep user expectations aligned across apps (PatchBay, Composer Studio, and future tools), we recommend the following defaults for canvas‑like surfaces:

- **Canvas pan (2D surfaces)**
  - Horizontal scroll (`FGKScrollEvent.deltaX`) → `canvas.translation.x` property.
  - Vertical scroll (`FGKScrollEvent.deltaY`) → `canvas.translation.y` property.
  - Use the host platform’s natural scrolling conventions: on macOS, treat positive `deltaY` as content moving up (canvas translating down) and vice versa.

- **Canvas zoom**
  - Pinch/zoom (`FGKMagnifyEvent.magnification`) → `canvas.zoom` property.
  - Positive magnification should increase zoom (zoom in), negative should decrease (zoom out).
  - Anchor zoom around the pointer location when possible (the point under the cursor stays as stable as feasible).

- **Drag‑to‑pan**
  - `.mouseDragged` on a canvas node can be interpreted as a pan gesture:
    - Convert drag deltas to `canvas.translation.x/y` updates.
    - Coordinate this with scroll behaviour so users can pan either via drag or scroll, depending on app affordances.

- **Rotation**
  - `FGKRotateEvent.rotation` can drive a rotation property (for example `canvas.rotation` or an instrument‑specific rotation field).
  - For surfaces where rotation is not meaningful, treat the event as no‑op or repurpose it for an instrument‑specific control (for example timeline scrub, depending on the property schema).

- **Swipes (navigation)**
  - Horizontal swipes (`FGKSwipeEvent.deltaX`) are ideal for discrete navigation:
    - For example previous/next page, scene, section, or cue.
    - Map to an app‑specific property such as `scene.index`, `page`, or a navigation command in the host app.
  - Vertical swipes can be reserved for advanced behaviours or left unhandled if scroll already covers the main use‑case.

These mappings are **recommendations**, not hard rules. FountainGUIKit only:

- emits the typed events (FGK*Event structs), and
- provides `FGKNode.setProperty(_ name:value:)` to apply property changes to interested targets.

Host apps are responsible for:

- declaring their property schema via `FGKPropertyDescriptor` (for example including `canvas.zoom`, `canvas.translation.x`, `canvas.translation.y`), and
- deciding which nodes should translate gestures into which properties, so that behaviour remains consistent with their UI/Teatro prompts and MRTS expectations.

## Testing, MRTS, and PB‑VRT

FountainGUIKit itself remains a small library, but it is designed to plug into FountainKit’s existing testing patterns from day one:

- **Local XCTest**
  - Tests in `FountainGUIKitTests` focus on:
    - Event mapping from synthetic `NSEvent` into `FGKEvent` via `FGKRootView`.
    - Event bubbling semantics in `FGKNode` (leaf → parent chain).
    - Any future layout/hit‑testing behaviour (e.g. which node receives a click at a given point).
  - These tests are headless and do not depend on Metal or MIDI stacks.

- **MRTS (MIDI Robot Test Script) readiness**
  - Nodes may carry an `instrumentId`, which is intended to match the identities used by FountainKit’s MIDI 2.0 instrument host and MRTS drivers.
  - FountainGUIKit does not run robots itself; instead, consuming apps (e.g. PatchBay, Composer Studio) can:
    - host their MetalViewKit views inside `FGKRootView`,
    - map MIDI 2.0 PE events into FGK‑level events or property changes,
    - and assert numeric invariants over the resulting state.

- **PB‑VRT (Prompt‑Bound Visual Regression Testing) readiness**
  - FountainGUIKit surfaces are NSViews, which can be rendered into images for PB‑VRT baselines.
  - The package may provide small helpers to snapshot a `FGKRootView` into an `NSImage`/`CGImage`, leaving PB‑VRT orchestration to the existing pb‑vrt service and tests in FountainApps.

The goal is that from the first milestone, FountainGUIKit surfaces are deterministic and easy to drive from MRTS and PB‑VRT harnesses, even though the orchestration lives in FountainKit.

## Source of truth and planning policy

- **AGENTS‑first**: any new concept (event type, node field, adapter, transport) is documented here before it appears in code.
- **Plan‑backed implementation**: `PLAN.md` captures milestones, Definition of Done, and gap tracking. When scope or status changes, update both `PLAN.md` and the relevant sections in `AGENTS.md`.
- **Implementation alignment**: when APIs in `Sources/FountainGUIKit/**` change, update:
  - this `AGENTS.md` file (primary design narrative),
  - `PLAN.md` (milestones and statuses),
  - then the package `README.md` (operator‑facing overview).
- **No divergent docs**: don’t duplicate design decisions in multiple places; link to `AGENTS.md` and `PLAN.md` from other docs instead.

## Next steps

- Document concrete MetalViewKit adapter patterns (renderer hooks, property naming, MIDI 2.0 mapping) as they are implemented in consuming apps.
- Keep `PLAN.md` and `README.md` in sync with this file whenever the public API surface changes.
