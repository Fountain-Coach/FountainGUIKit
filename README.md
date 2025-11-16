# FountainGUIKit — NSView‑Based GUI Core for MetalViewKit and MIDI 2.0

FountainGUIKit is a small, NSView‑only GUI framework designed to host MetalViewKit renderers and MIDI 2.0 “instruments” without depending on SwiftUI or AppKit’s responder chain. It provides a custom event model, a pure‑Swift node graph, and a single root NSView that you can embed into existing macOS apps.

This repository follows an **agent‑driven design**: `AGENTS.md` is the primary design narrative, and `PLAN.md` tracks milestones and Definition of Done. The conceptual foundations are described in the design note `Doc/Building-a-Custom-GUI-Framework-with-MetalViewKit-and-MIDI2-Integration.md`, which explains why we want predictable, MIDI‑friendly UI surfaces.

## What FountainGUIKit Provides

- **NSView‑only host**
  - `FGKRootView: NSView` is the single entry point. It receives `NSEvent`s and forwards them into a framework‑owned event system instead of using AppKit’s responder chain.
  - The package does not expose any SwiftUI types; apps can wrap `FGKRootView` in SwiftUI themselves if desired.

- **Explicit event model**
  - `FGKEvent`, `FGKKeyEvent`, `FGKMouseEvent` capture keyboard and mouse input as simple Swift types.
  - Events are created from `NSEvent` in `FGKRootView` but can also be constructed directly in tests.

- **Custom responder chain and node graph**
  - `FGKEventTarget` is a protocol for anything that wants to receive events: `func handle(event: FGKEvent) -> Bool`.
  - `FGKNode` is a pure‑Swift tree node (no NSView base class) with:
    - `parent` and `children` to represent the UI hierarchy.
    - an optional `instrumentId` for future MIDI 2.0/CI integration.
    - a `bubble(event:)` method that walks `self → parent → …` until a target handles the event (an explicit, testable responder chain).

- **Future integration points**
  - MetalViewKit: planned adapters will attach MetalViewKit renderers to `FGKNode` instances and treat them as instrumented views.
  - MIDI 2.0 CI/PE: nodes with an `instrumentId` will eventually map their property schema into MIDI 2.0 Property Exchange, reusing FountainTelemetryKit transports (loopback/RTP/BLE) without CoreMIDI.

## Design Anchors

FountainGUIKit is shaped by three main sources:

- `AGENTS.md` — the authoritative design document for this repo. It defines:
  - scope (NSView‑only host, no SwiftUI, no CoreMIDI),
  - current API layers (`FGKEvent`, `FGKNode`, `FGKRootView`),
  - and how the framework should integrate with MetalViewKit and MIDI 2.0 over time.
- `PLAN.md` — the implementation plan and Definition of Done:
  - M1: core event model and root view.
  - M2: layout and hit‑testing.
  - M3: MetalViewKit adapter.
  - M4: MIDI 2.0 CI/PE integration.
  - M5: consumers and documentation.
  - M6: testing, MRTS, and PB‑VRT integration.
- `Doc/Building-a-Custom-GUI-Framework-with-MetalViewKit-and-MIDI2-Integration.md`
  - A design note (transcribed from the original PDF) that motivates the framework:
    - treat every interactive element as a MIDI 2.0 instrument,
    - replace “mystery” responder chains with explicit, testable event flows,
    - and make UI behaviour controllable via MIDI messages and property changes.

When you change the framework, update `AGENTS.md` first, then `PLAN.md`, then this README.

## Relationship to FountainKit

FountainGUIKit is intended to be consumed by the main FountainKit workspace, not to replace it:

- MetalViewKit lives in `FountainKit/Packages/FountainApps/Sources/MetalViewKit`.
- MIDI 2.0 transports live in `FountainTelemetryKit`.
- PB‑VRT and MRTS harnesses live under `Packages/FountainApps/Tests` and related scripts.

FountainGUIKit’s role is to:

- provide a predictable, instrument‑friendly NSView host and event system; and
- make it easy for apps like PatchBay, Composer Studio, and future tools to expose their UI surfaces as MIDI 2.0 instruments and PB‑VRT scenes.

## Getting Started

### Add the package

In a consuming package’s `Package.swift`:

- Add FountainGUIKit as a dependency:
  - For development, point to the local checkout or the GitHub URL:
    - `.package(url: "https://github.com/Fountain-Coach/FountainGUIKit.git", from: "0.1.0")`
- Add `"FountainGUIKit"` to the target’s dependencies.

### Embed `FGKRootView` in an AppKit window

A minimal usage pattern in an AppKit app looks like:

```swift
import AppKit
import FountainGUIKit

final class MyEventTarget: FGKEventTarget {
    func handle(event: FGKEvent) -> Bool {
        // Decide which events to consume.
        return false
    }
}

let rootNode = FGKNode(instrumentId: "my.app.surface", target: MyEventTarget())
let rootView = FGKRootView(frame: .zero, rootNode: rootNode)

// Attach rootView to your NSWindow contentView as usual.
```

From here you can:

- add child nodes to `rootNode` to build a logical hierarchy; and
- implement `handle(event:)` on your targets to respond to keyboard and mouse input.

MetalViewKit integration and MIDI 2.0 adapters will build on top of this structure without changing the embedding model.

## Testing, MRTS, and PB‑VRT

The framework is designed to integrate with FountainKit’s test infrastructure:

- **Local XCTest**
  - `FountainGUIKitTests` focuses on:
    - mapping `NSEvent` to `FGKEvent` in `FGKRootView`,
    - event bubbling behaviour in `FGKNode`,
    - and (once added) layout and hit‑testing.

- **MRTS (MIDI Robot Test Script) readiness**
  - Nodes can carry an `instrumentId` aligned with the identities used by FountainKit’s MIDI 2.0 instrument host.
  - Consuming apps can host their MetalViewKit views inside FountainGUIKit and drive them via MIDI 2.0 PE, asserting numeric invariants as they already do for PatchBay and other surfaces.

- **PB‑VRT readiness**
  - Because `FGKRootView` is an NSView, FountainApps can render it into images and feed those into the existing PB‑VRT service as baselines and regression checks.
  - FountainGUIKit may eventually expose small snapshot helpers, but PB‑VRT orchestration remains in FountainKit.

## Contributing

- Start by reading `AGENTS.md` to understand the design rules and intended integration points.
- Check `PLAN.md` and the gap checklist before adding new APIs.
- Keep AGENTS, PLAN, and README in sync when you modify the public surface.

FountainGUIKit is intentionally small and focused: its job is to make MetalViewKit and MIDI 2.0 easier to use in deterministic, testable GUIs, not to replace full UI frameworks. Design first in AGENTS, plan in PLAN, then implement. 
