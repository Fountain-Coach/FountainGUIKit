# Building a Custom GUI Framework with MetalViewKit and MIDI 2.0 Integration

This note explores what it would take to build a custom GUI framework on top of MetalViewKit, with MIDI 2.0 as a first‑class control and testing surface. The goal is to make UI behaviour predictable, instrument‑friendly, and robot‑testable, not to recreate every feature of AppKit or SwiftUI.

The framing here informs FountainGUIKit’s design, but the authoritative contracts live in the package‑local `AGENTS.md` and `PLAN.md`.

## Understanding MetalViewKit’s Role

MetalViewKit is an in‑house framework that provides embeddable, Metal‑based views for macOS with a stable rendering API. Unlike typical UI frameworks, MetalViewKit is **MIDI‑friendly by design**:

- Each Metal view can operate in an **instrument mode**, exposing itself as a **MIDI 2.0 instrument** with:
  - a unique identity, and
  - a small set of named properties (for example `rotationSpeed`, `zoom`, `tint.r/g/b`).
- Views advertise a JSON property schema and respond to MIDI‑CI Property Exchange GET/SET messages for those properties.
- The renderer itself is transport‑agnostic: its logic does not depend on a specific input pipeline.

In practice, this means you can drop a MetalViewKit view into an app and **treat it like a MIDI instrument**:

- map external controllers to visual parameters,
- query state in real time, and
- drive the view from tests without any UI automation, by sending UMP and observing deterministic transform updates.

The philosophy is that **everything is an instrument**:

- not just the raw Metal canvas, but also higher‑level UI elements such as canvases, nodes, or inspectors;
- each can expose a MIDI‑CI identity and a Property Exchange surface.

For example, the MetalViewKit demo:

- lets two Metal views (a triangle and a textured quad) be “linked” so they respond in sync; and
- uses an Inspector panel that itself acts as an instrument, fetching or applying property snapshots via MIDI‑CI.

The key idea is that any interactive element can be treated as a MIDI 2.0 instrument, which yields a uniform way to control and introspect the UI.

## Requirements for a Feature‑Complete GUI Framework

Creating a GUI framework comparable to AppKit or SwiftUI is ambitious. A MetalViewKit‑based framework would need to provide several layers of functionality that developers expect from Apple’s frameworks.

### Rendering and layout

- Manage a hierarchy of UI elements (windows, views, controls) and draw them efficiently.
- MetalViewKit already covers low‑level rendering (Metal draw calls, shapes, textures).
- We still need:
  - a layout system for positioning and sizing UI components, and
  - a scene graph or view hierarchy management layer.
- Apple’s frameworks handle coordinate systems, clipping, and compositing of subviews; our framework must offer analogous capabilities to organise multiple MetalViewKit “nodes” (for example, a `MetalCanvasNode` inside a `MetalCanvasView`).
- UI elements must be composable, transformable (scale/zoom), and layerable in predictable ways.

### Input and event handling

This is the crux: we need a robust event system for:

- keyboard input,
- mouse / trackpad events,
- gestures, and
- specialised inputs (in our case, MIDI).

Apple’s frameworks route events through a responder chain:

- keyboard events typically go to the focused control (the first responder),
- mouse events start at the view under the cursor, and
- events bubble up through parents (view → window → app) if not handled.

To match or improve on this, our framework must define:

- how events find their initial target (hit‑testing and focus), and
- what happens if the target does not handle a given event.

MetalViewKit already provides per‑view MIDI endpoints, which cover external MIDI inputs. The framework described here extends that idea so that **internal interactions** (clicks, typing) also pass through a unified event flow we can reason about and test.

### Standard controls and widgets

A complete GUI framework usually provides ready‑made controls:

- buttons, sliders, text fields, pop‑ups, etc.,
- with consistent look‑and‑feel and behaviour.

Building all of these from scratch on top of MetalViewKit is a major undertaking:

- text fields alone require caret management, text layout/rendering, selection handling, and input method integration;
- sliders and toggles need focus handling, keyboard access, and accessibility hooks.

Given our use‑cases (music and graphics apps with custom views), a pragmatic approach is:

- implement only the subset of controls we truly need (for example, sliders for parameters, toggles, and a minimal text input surface), and/or
- embed existing AppKit controls where we do not need custom drawing, while keeping heavy‑weight widgets at the edges.

### Windowing and compositing

Apple’s frameworks manage windows, menus, coordinate spaces, and compositing out of the box.

In a custom framework, we:

- rely on AppKit to host windows and integrate with the OS; but
- own the composition of Metal‑backed content inside those windows (for example, via a root NSView).

The custom layer is responsible for:

- tracking the hierarchy of MetalViewKit views and other content,
- managing transforms (zoom, pan, scaling), and
- coordinating redraws and invalidation within that hierarchy.

## Designing Event Flow

A core challenge is to make event flow **predictable and testable**, especially for keyboard input (“where typed text lands?”).

### Responder chains (Cocoa‑style)

In AppKit/UIKit:

- events are delivered to the first responder and then up the responder chain until handled;
- the first responder is usually:
  - the focused control (for keyboard input), or
  - the view under the mouse (for clicks).

This model works but can be hard to reason about in complex UIs or when mixing frameworks. For example, embedding NSView inside SwiftUI can create surprising responder behaviour.

The goal for a MetalViewKit‑based framework is to keep the good parts—hierarchical propagation, the notion of focus—but make the path explicit and inspectable.

### Event bubbling (DOM‑style)

Web frameworks often use event bubbling:

- the event is first sent to the most specific element (the clicked button),
- if unhandled, it bubbles up to parent elements,
- an optional capturing phase lets ancestors intercept events on the way down.

This is conceptually similar to Cocoa’s responder chain, but often easier to debug because the order is explicit.

We can adopt this model by:

- giving each UI element a parent/child relationship in a custom node graph, and
- defining a clear “bubble up” strategy when an element does not handle an event.

For example, a click on a canvas node could:

1. first be offered to the node,
2. then to the containing canvas (to select or start marquee),
3. then to a higher‑level controller, if neither node nor canvas handle it.

### Custom responder chain in our framework

We can combine these ideas by defining our own responder chain independent of AppKit’s:

- Each element in the MetalViewKit hierarchy conforms to a protocol for event handling.
- Every element knows its “next responder” (parent or controller).
- A dispatcher:
  - identifies the initial target via hit‑testing and focus,
  - calls the target’s event handler, and
  - walks up the chain when the event is not consumed.

This is effectively event bubbling with explicit structure. It lets us:

- make keyboard input target selection explicit (a focus manager instead of implicit first responder rules),
- keep mouse event routing aligned with the visual hierarchy,
- and instrument the chain for unit tests by simulating events and asserting which element handled them.

## A MIDI 2.0–Inspired Event System

MetalViewKit already treats each interactive Metal view as a MIDI 2.0 instrument:

- it supports MIDI‑CI Discovery and Property Exchange;
- it has a concept of instrument identity and property schemas.

An intriguing extension is to apply this model internally for **UI event routing**:

- treat every interactive element as a MIDI 2.0 instrument,
- represent certain UI events as MIDI messages or property changes,
- and use the existing MIDI infrastructure as a transport for robot tests or remote control.

Examples:

- A keyboard character input could be translated to:
  - a vendor‑defined MIDI message, or
  - a `vendorEvent(topic:data:)` call on the instrument sink (for example `topic: "keypress"`, `data: { "key": "A" }`).
- If the focused instrument does not support text input (no `textInput` capability), the event can be:
  - redirected to a higher‑level “parent” instrument, or
  - handled by a global controller.

MIDI‑CI Capability Inquiry can even be used to discover:

- whether a component supports certain events or commands,
- for example, whether it has a `textInput` capability or responds to specific vendor events.

This would be a novel use of MIDI‑CI/PE: the UI event system becomes a network of MIDI‑aware components negotiating control.

From a testing perspective, this is attractive:

- if every UI action can be represented as a MIDI message or property change,
- tests can drive the UI by sending those messages and asserting on state, without traditional UI automation.

## Ensuring Predictability and Testability

The main pain point we want to address is the predictability of event handling, especially text input.

### Explicit focus

In a custom framework, we can make focus explicit:

- When a text‑editable element (instrument) is clicked, the framework sets `focusedInstrument = X`.
- When the user types:
  - we do not rely on AppKit’s responder chain;
  - instead we route all key events to `focusedInstrument`.
- Focus state can itself be a property, so tests can:
  - set the focused element, and
  - verify that key events land where expected.

### Unified event pipeline

By representing events as data:

- either as MIDI messages, or
- as structured event objects,

we gain:

- a log of events that can be inspected and replayed;
- a uniform way to drive UI in production and tests.

MetalViewKit already posts notifications for certain interactions (for example, `MetalCanvasMIDIActivity` for zoom and note events). Extending this to all user events yields:

- a consistent “instrument event log”,
- easier debugging of event flow, and
- deterministic replay in tests.

### Transport‑agnostic control

If our event dispatch model is compatible with MIDI:

- controlling the UI in production or in tests uses the same mechanism,
- tests can be transport‑agnostic and production‑faithful.

We can:

- drive the UI from a remote MIDI controller or a test harness,
- record and replay event sequences,
- and keep the entire stack deterministic by design.

In practice, we do not need to route OS‑driven events literally over MIDI:

- key and mouse events can call handler methods directly, but
- we align their shape with the MIDI‑driven paths (for example, via `vendorEvent(topic:data:)`),
- so that tests can still drive the same handlers via UMP when needed.

### Bubbling vs direct targeting in tests

For test clarity, some events may be better handled via **direct targeting** rather than bubbling:

- Hit‑test the click in the dispatcher or test harness,
- send the event directly to the chosen instrument,
- and avoid propagation for simple cases.

Bubbling is still useful for higher‑level commands (for example, delete/backspace), where:

- the focused control may choose to consume the event, or
- a global handler (such as a canvas controller) may step in if the focused control does not.

By encoding these rules explicitly, we make fallback behaviour both predictable and overrideable.

## Conclusion: Viability of a MetalViewKit‑Based GUI Framework

In principle, we **can** build a GUI framework on top of MetalViewKit that rivals traditional frameworks in capability, while adding MIDI 2.0–based responder logic and testability.

MetalViewKit already provides:

- high‑performance Metal rendering,
- a flexible, property‑based control scheme, and
- built‑in MIDI‑CI/PE support for introspection and automation.

To reach parity with AppKit/UIKit in terms of developer expectations, we must supply:

- layout and hierarchy management,
- a considered set of widgets and controls,
- a predictable event propagation model, and
- good integration with text and input methods where needed.

This is non‑trivial, but the payoff is a UI toolkit where:

- event handling is deterministic and testable by design,
- UI interactions are treated as data flows (or MIDI messages) that can be logged, replayed, and manipulated, and
- the responder chain can be conceptualised as a **network of instrumented UI components** communicating their capabilities and state in a uniform way.

This approach aligns well with the broader goal of unifying creative UI with MIDI 2.0 and with the testing philosophy already used in FountainKit (MRTS and PB‑VRT). A MetalViewKit‑based framework, implemented carefully, could match—and in some ways surpass—traditional frameworks in flexibility, introspectability, and automation‑friendliness.

## Sources

- MetalViewKit design docs — MetalViewKit Demo User Story & Agent Guide (instrument mode and test approach).
- MetalViewKit code — `MetalView`, `MetalCanvasView`, `MetalInstrument` (MIDI‑driven views and event sinks).
- FountainKit `AGENTS.md` and related notes in the FountainKit repository.

