# Building a Custom GUI Framework with

MetalViewKit and MIDI2 Integration

Understanding MetalViewKit’s Role

MetalViewKit  is an in-house framework that provides embeddable Metal-based views (for macOS) with

a stable rendering API . Unlike typical UI frameworks, MetalViewKit is “MIDI‑friendly by design”  – each

Metal view can operate in an  “instrument mode” , exposing itself as a  MIDI 2.0 instrument  with a

unique identity and property set . In practice, this means you can drop a MetalViewKit view into an

app and  treat it like a MIDI instrument , mapping external controls to its visual parameters and

querying  its  state  in  real-time .  Each  view  advertises  a  JSON  property  schema  (e.g.

rotationSpeed ,  zoom,  tint.r/g/b )  and  responds  to  MIDI-CI  Property  Exchange  GET/SET

messages for those properties . This design keeps the renderer itself  transport-agnostic  – the

view’s logic doesn’t depend on any specific input pipeline. Instead, enabling instrument mode  spawns a

CoreMIDI  virtual  endpoint  for  the  view,  allowing  MIDI  2.0  UMP  messages  to  drive  it.  In  short,

MetalViewKit turns UI views into self-contained “instruments”  that external controllers (or test code)

can discover via MIDI-CI and manipulate via standard MIDI 2.0 messages .

Notably,  “everything is an instrument”  in MetalViewKit’s philosophy: not just the raw Metal canvas, but

also higher-level UI components like canvases, nodes, or inspectors can each expose a MIDI-CI identity

and Property Exchange interface . For example, the MetalViewKit demo allows two Metal views (a

triangle and a textured quad) to be “linked”  so they respond in sync, and an Inspector panel itself acts

as an instrument to fetch or apply property snapshots via MIDI-CI . The key idea is that  any

interactive element can be treated as a MIDI 2.0 instrument , which yields a uniform way to control and

introspect the UI.

Requirements for a Feature-Complete GUI Framework

Creating a GUI framework comparable to Apple’s AppKit or SwiftUI is an ambitious task. To be “feature-

complete,” our MetalViewKit-based framework would need to provide many layers of functionality that

users expect from Apple’s frameworks:

Rendering and Layout:  We must manage a hierarchy of UI elements (windows, views, controls)

and  draw  them  efficiently.  MetalViewKit  already  covers  low-level  rendering  (using  Metal  for

custom drawing of content like shapes, textures, etc.), but we would need to add a  layout

system  (for positioning and sizing UI components) and possibly a scene graph  or view hierarchy

management.  Apple’s  frameworks  handle  coordinate  systems,  clipping,  and  compositing  of

subviews; our framework would need analogous capabilities to organize multiple MetalViewKit

“nodes” (the draft mentions  MetalCanvasNode  and  MetalCanvasView  for a canvas of nodes ).

Ensuring that UI elements can be composed, transformed (e.g. scaled/zoomed), and layered

predictably is essential.

Input and Event Handling:  This is the crux of the question. We need a robust event system for

keyboard input, mouse/trackpad events, gestures, etc. Apple’s frameworks use a responder chain

to route events through the view hierarchy (from the first responder up through parent views,1

1

2

1

1

3

45

•

6

•

1


--- PAGE 2 ---

windows, and the app). To match this, our framework must define how events find their target

and what happens if a target doesn’t handle them. Additionally, specialized inputs (like multi-

touch, drag-and-drop, or in our case  MIDI signals ) should integrate seamlessly. MetalViewKit

already provides per-view virtual MIDI endpoints , which cover external MIDI inputs; we’d extend

this so that internal user interactions (clicks, typing) are also translated into a unified event flow.

Standard Controls & Widgets:  A complete GUI framework usually provides ready-made controls

(buttons, sliders, text fields, etc.) with consistent look-and-feel and behavior . We would either

need to implement such controls on top of MetalViewKit (drawing them with Metal and handling

their  interaction  logic),  or  find  a  way  to  embed  or  interoperate  with  existing  controls.  For

example, text input fields require caret management, text rendering, selection handling, etc.,

which is non-trivial to build from scratch. Since MetalViewKit primarily covers custom-drawn

content (like our graphics “instruments”), building an entire library of controls would be a major

effort. However , if our use-case is focused (e.g. a music app with custom views, rather than a

general-purpose form UI), we might only implement a subset of controls needed (sliders for

parameters, toggles, etc.), possibly reusing Apple’s controls in places where custom drawing isn’t

needed.

Windowing and Compositing:  Apple’s frameworks manage windows, menus, and coordinate

spaces automatically. In our custom framework, we would rely on Metal  within an NSWindow (or

SwiftUI View) to host content. We might still use a minimal AppKit/SwiftUI container to create a

window and attach a root MetalViewKit canvas, but within that we’d implement our own sub-view

system. We would need to handle coordinate conversions  (window to view coordinates, etc.) if

we mix with OS components. Also, features like full-screen, resizing, or layering UI on top of our

Metal content (for instance, to show tooltips or context menus) would need attention – possibly

by rendering those in Metal too or carefully overlaying NSViews.

Performance and Loop Control:  A custom framework must manage its rendering loop and

event loop. MetalViewKit uses MTKView  which can continuously render at vsync. We’d ensure

that  UI  updates  (e.g.  animations  or  rapid  input  changes)  occur  smoothly  at  60fps.  Apple

frameworks handle a lot of optimization (like only redrawing dirty regions, etc.); we’d need to

adopt similar strategies with Metal (using techniques like partial redraw or caching if needed).

Fortunately, our current MetalViewKit demo aimed for stable 60fps rendering of a triangle/quad

with effects , so we have a baseline for performance.

Accessibility and System Integration:  To truly match Apple’s frameworks, we should consider

how accessible our custom controls are (VoiceOver , assistive tech) and how to integrate with

system services (copy/paste, drag/drop, etc.). These might be out-of-scope initially, but they are

part of what a “feature-complete” GUI toolkit eventually needs. We may defer these, focusing

first on core event handling and rendering, then later mapping accessibility properties to our

instrument’s property model.

In summary, using MetalViewKit gives us a head-start on  rendering  and an innovative approach to

control via MIDI , but we’d have to implement much of the UI machinery (layout, widget behaviors, event

routing) ourselves to reach parity with AppKit/UIKit. It’s a significant undertaking, so we might scope

the effort to the specific needs of our application (e.g. focusing on canvas, nodes, inspectors as in our

PatchBay app, rather than every possible UI control).•

•

•

7

•

2


--- PAGE 3 ---

Designing Event Flow: Responder Chain vs Event Bubbling vs

New Approach

A core challenge is making event flow (keyboard and mouse events)  predictable and testable . In

Apple’s AppKit/UIKit, events are delivered to the first responder  and then up the responder chain  until

handled. The first responder  is typically the focused control for keyboard events, or the view under the

mouse for click events. If that object doesn’t handle a given event or command, the system tries its

parent,  and  so  on  (view  → window  → app).  This  chain  can  sometimes  be  hard  to  reason  about,

especially in complex UIs or when mixing frameworks (for example, embedding NSView in SwiftUI can

lead to unexpected responder behavior). The user’s comment “where type lands must become predictable

and testable”  highlights frustration with not knowing which view will ultimately receive keyboard input

(text) or how to consistently direct it during tests.

Event Bubbling (and Capturing):  Another model, used in web frameworks (DOM), is event bubbling  –

the event is first sent to the most specific element (e.g. the clicked button), and if unhandled, it bubbles

up to parent elements. There’s also an initial capturing  phase from the root down to the target that can

intercept  events.  This  model  is  conceptually  similar  to  Cocoa’s  responder  chain  (hierarchical

propagation), but it’s explicitly ordered and can be easier to debug (you can see an event tunnel down

and then bubble up). We could adopt event bubbling in our framework: for example, a mouse click on a

node in our Metal canvas could first offer the node a chance to handle it; if not, the containing canvas

could handle it (perhaps selecting the node or starting a marquee select), and if not, a higher-level

controller could handle it (e.g. a global keyboard shortcut). Designing a bubbling scheme would require

our UI elements to know their parent/child relationships (so we can move up the tree), which implies

building our own view hierarchy  data structure within the MetalViewKit system.

Responder Chain (Cocoa-style):  We could also implement a responder chain  similar to AppKit’s. Each

MetalViewKit element (canvas, node, etc.) could conform to a protocol for event handling and have a

reference to a “next responder” (the parent in hierarchy, or maybe a controller). An event dispatch

function would attempt to call the event method on the first responder and, if it returns unhandled,

pass it to next responder , and so on. This is effectively equivalent to bubbling, just different terminology.

The advantage is that we can decide exactly what the chain is – for instance, perhaps keyboard events

always go to the currently focused element (e.g. a text field instrument), whereas mouse events start at

the hit-tested element under the cursor . By crafting our own chain, we can eliminate some of the

unpredictable aspects of Cocoa’s chain (which sometimes involves NSWindow or NSApp implicitly). We

can also instrument and unit test  this chain easily by simulating events.

A MIDI2-Inspired Event System:  One intriguing idea is to leverage the MIDI 2.0 instrument model

(CI/PE)  not just for external control and testing, but internally  for event routing. Since “everything is an

instrument”  in  our  view  hierarchy  concept ,  we  could  theoretically  dispatch  UI  events  as  MIDI

messages  or property changes to the target instrument. For example, a keyboard character input could

be translated into a vendor-defined MIDI message  (or simply a method call on the MetalSceneRenderer

interface) to the focused instrument’s endpoint. If that instrument doesn’t handle text input (say the

instrument doesn’t define a “text” property), we might then propagate or redirect the event to a higher-

level instrument. MIDI-CI’s Capability Inquiry  could even be used to discover if a component supports

certain events or commands (for instance, a CI query could tell us if the focused instrument has a

“textInput” capability). This would be a very novel use of MIDI CI/PE: essentially treating the UI event

system as a network of MIDI devices negotiating control. While unconventional, it aligns with our

testability goal  – if every UI action can be represented as a MIDI message or property change, then we

can simulate user input in tests by sending those same messages. In fact, our testing strategy already

does this for property changes: “No UI automation is needed — tests send UMP and observe deterministic3

3


--- PAGE 4 ---

transform updates” . This means the UI responds to MIDI messages in a fully deterministic way,

which is great for automation. Extending that approach, we could also generate UMP messages for key

presses or mouse clicks in testing scenarios, making the flow uniform.

Better Than the Traditional Chain?  The responder chain  and event bubbling  are proven patterns, but

our custom framework has the opportunity to improve on them: - Explicit Focus and Targeting:  We

can design the system so that it’s always explicit which instrument is receiving keyboard input. For

example, we maintain a single focused instrument  (much like first responder) for text/key events, and our

framework’s focus manager ensures it’s clearly set whenever a control is clicked or programmatically

focused. This would make “where typed text lands” completely deterministic. We could even expose the

focus  state  as  a  property  that  tests  can  query  or  set  (e.g.,  a  global  instrument  property

“focusedElementID”). -  Unified Event Pipeline:  By representing events as data (MIDI messages or

property dictionaries), we gain a log of events  that can be inspected. Our MetalViewKit already posts

notifications for certain interactions (e.g. MetalCanvasMIDIActivity  with details on zoom or note

events) . We could extend this to all user events, making it easy to log and debug the event flow.

This is akin to how web developers can inspect event propagation; we’d have an instrument-event log. -

Transport-Agnostic Control:  If our event dispatch is MIDI-based under the hood, then controlling the

UI remotely or in tests is the same mechanism as a real user interaction. This  “makes tests transport-

agnostic and production-faithful”  – a huge win for reliability. We could, for instance, drive the entire

UI from a remote MIDI controller or a script, which opens up creative possibilities (imagine a physical

MIDI device navigating the UI by triggering events).

In practical terms, a likely implementation might not literally use MIDI for OS-driven events  (we can just

call  the  handler  methods  directly),  but  we’d  adhere  to  the  same  interface .  Each  UI  component

(instrument)  would  implement  handlers  like  noteOn,  controlChange ,  pitchBend ,  and

vendorEvent  (already defined in the MetalSceneRenderer  protocol ). We can repurpose these:

for example, use a specific MIDI channel or message type to represent different UI events  – note-on

for generic “activate” actions, CC for slider movements, or vendor JSON events for complex data like text

strings  or  focus  changes.  The  MetalInstrument  class  already  routes  incoming  MIDI  UMP  to  the

MetalSceneRenderer  sink methods . So if a keypress is translated to a MIDI SysEx carrying a

JSON  {  "topic":  "keypress",  "data":  {"key":"A"}  } ,  our  instrument’s

vendorEvent(topic:data:)  would be invoked with that data , and we could handle it in the

target instrument’s code. If unhandled, we could then choose to forward that event to a higher-level

instrument (manually call the parent’s vendorEvent ), achieving a custom “bubbling” behavior .

Ensuring Predictability and Testability

To address the user’s main pain point: predictability and testability  of event handling, especially text input

(“where type lands”). In our custom framework, we will make focus explicit . For example, when a text-

editable field (instrument) is clicked, our framework can set an internal pointer to “focusedInstrument =

X”. Then, when the user types, we don’t rely on Cocoa’s mechanism; instead, our keyDown handler at

the  window  level  will  intercept  the  keys  and  forward  them  to  that  focused  instrument  (e.g.  via  a

vendorEvent  for “textInput” or by directly calling a method on the instrument). Because we control

this focusing logic, we avoid scenarios where Cocoa might unexpectedly change first responder . And

because we can expose it, our tests can simulate typing by simply sending the appropriate event to the

known target instrument (or even setting focus and sending a MIDI text event). This level of control

makes the landing place of input  100% predictable  – no guessing which view has focus, since our

framework will have a single source of truth for it.8

910

11

12

1314

1516

4


--- PAGE 5 ---

Moreover , by designing every interactive element as an instrument with a known ID and properties,

writing  tests  becomes  akin  to  sending  MIDI  messages  to  these  IDs  and  verifying  their  state.  Our

project’s documentation explicitly states this goal:  “we test every interactive surface by treating it as a

MIDI 2.0 instrument… tests send UMP and observe deterministic transform updates” . This means if we

extend the concept, we could test a button press by sending a “button.press” message to the button’s

instrument and then verifying through its state or a resulting action. We can test text input by sending a

sequence of “textInput” events and ensuring the instrument’s text property updated.

Finally, we should consider  event bubbling vs. direct targeting  in tests. It might actually simplify

things to  avoid bubbling for certain event types . For instance, rather than rely on a chain, we could

determine the target of a click via hit-testing in the test or in the event dispatcher , then send the event

directly to that instrument (no intermediate propagation needed unless we want global handlers).

Bubbling could be reserved for higher-level commands (like a “delete” key that might either delete a

selection in a focused control or , if none, maybe delete an object on the canvas). Those rules can be

clearly defined and coded, rather than implicit. By explicitly coding the fallbacks (if focused instrument

doesn’t handle, call a global handler , etc.), we make it both predictable and override-able as needed.

Conclusion: Viability of a MetalViewKit-Based GUI Framework

In  principle,  yes,  we  can  create  our  own  GUI  framework  atop  MetalViewKit  that  rivals  Apple’s

frameworks in capability, with the added benefit of MIDI2-based responder logic . MetalViewKit gives us a

strong foundation: high-performance Metal rendering, a flexible property-based control scheme, and

built-in MIDI-CI/PE support for introspection and automation . To reach feature-parity with AppKit/

UIKit, we must implement the surrounding infrastructure (layout, widgets, event propagation, etc.),

which is a non-trivial endeavor but feasible with careful scope management. The reward is a UI toolkit

where event handling is deterministic and testable by design  – a toolkit that treats UI interactions as

data flows (or MIDI messages) that we can log, replay, and manipulate. This could indeed surpass

traditional  responder  chains  in  clarity.  By  leveraging  MIDI  2.0’s  standardized  communication,  our

framework’s  “responder  chain”  might  actually  be  a  network  of  instrumented  UI  components

communicating their capabilities and state changes in a uniform way.

In  summary,  creating  a  MetalViewKit-based  GUI  framework  is  a  significant  project,  but  it  offers  a

promising solution to our current frustrations. We would gain full control over event flow (no more

black-box responder chain issues) and achieve tight integration between UI and MIDI. The flows of

events would be as predictable  as the mapping we define, and as testable  as sending a MIDI message

in our test suite. This approach aligns with our project’s philosophy of unifying creative UI with MIDI 2.0,

potentially  leading  to  a  highly  innovative  GUI  framework  that  not  only  matches  but  in  some  ways

outclasses  Apple’s traditional frameworks in flexibility and introspectability .

Sources:

MetalViewKit Design Docs – MetalViewKit Demo User Story & Agent Guide  (outlining the

instrument-mode design and test approach)

MetalViewKit Code – MetalView, MetalCanvasView, MetalInstrument  (implementation of MIDI-

driven views and event sinks)

AGENTS.md

https://github.com/Fountain-Coach/FountainKit/blob/9637ca83d4caddbaacf1b80cdaff5bdf3c3fb494/Packages/

FountainApps/Sources/MetalViewKit/AGENTS.md8

1

11

• 2 1 11

•

9 10

1 3 6 811

5


--- PAGE 6 ---

MetalViewKit-DEMO-USER-STORY.md

https://github.com/Fountain-Coach/FountainKit/blob/9637ca83d4caddbaacf1b80cdaff5bdf3c3fb494/Design/MetalViewKit-

DEMO-USER-STORY.md

MetalCanvasView.swift

https://github.com/Fountain-Coach/FountainKit/blob/9637ca83d4caddbaacf1b80cdaff5bdf3c3fb494/Packages/

FountainApps/Sources/MetalViewKit/MetalCanvasView.swift

MetalInstrument.swift

https://github.com/Fountain-Coach/FountainKit/blob/9637ca83d4caddbaacf1b80cdaff5bdf3c3fb494/Packages/

FountainApps/Sources/MetalViewKitCore/MetalInstrument.swift2 4 5 7

910

12 13 14 15 16

6
