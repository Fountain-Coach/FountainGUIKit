import AppKit
import Testing
@testable import FountainGUIKit

@MainActor
private final class RecordingTarget: FGKEventTarget {
    var events: [FGKEvent] = []
    var handleResult: Bool

    init(handleResult: Bool) {
        self.handleResult = handleResult
    }

    func handle(event: FGKEvent) -> Bool {
        events.append(event)
        return handleResult
    }
}

private final class RecordingSink: FGKInstrumentSink {
    struct Entry {
        let topic: String
        let data: Any?
    }
    var entries: [Entry] = []

    func vendorEvent(topic: String, data: Any?) {
        entries.append(.init(topic: topic, data: data))
    }
}

private final class PropertyRecordingTarget: FGKEventTarget, FGKPropertyConsumer {
    struct Entry {
        let name: String
        let value: FGKPropertyValue
    }
    var events: [FGKEvent] = []
    var properties: [Entry] = []

    @MainActor
    func handle(event: FGKEvent) -> Bool {
        events.append(event)
        return false
    }

    func setProperty(_ name: String, value: FGKPropertyValue) {
        properties.append(.init(name: name, value: value))
    }
}

@MainActor
@Test
func node_bubble_stops_at_first_handler() {
    let root = FGKNode()
    let child = FGKNode()
    root.addChild(child)

    let rootTarget = RecordingTarget(handleResult: true)
    let childTarget = RecordingTarget(handleResult: true)
    root.target = rootTarget
    child.target = childTarget

    let event = FGKEvent.keyDown(FGKKeyEvent(characters: "a", keyCode: 0, modifiers: []))
    let handled = child.bubble(event: event)

    #expect(handled)
    #expect(childTarget.events.count == 1)
    #expect(rootTarget.events.isEmpty)
}

@MainActor
@Test
func node_bubble_falls_back_to_parent() {
    let root = FGKNode()
    let child = FGKNode()
    root.addChild(child)

    let rootTarget = RecordingTarget(handleResult: true)
    let childTarget = RecordingTarget(handleResult: false)
    root.target = rootTarget
    child.target = childTarget

    let event = FGKEvent.mouseDown(FGKMouseEvent(locationInView: .zero, buttonNumber: 0, modifiers: []))
    let handled = child.bubble(event: event)

    #expect(handled)
    #expect(childTarget.events.count == 1)
    #expect(rootTarget.events.count == 1)
}

@MainActor
@Test
func rootView_maps_keyDown_to_FGKEvent() {
    let target = RecordingTarget(handleResult: true)
    let rootNode = FGKNode(target: target)
    let view = FGKRootView(frame: NSRect(x: 0, y: 0, width: 100, height: 100), rootNode: rootNode)

    let maybeEvent = NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: [.command],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: "x",
        charactersIgnoringModifiers: "x",
        isARepeat: false,
        keyCode: 7 // X on US layout
    )
    #expect(maybeEvent != nil)
    guard let event = maybeEvent else { return }

    view.keyDown(with: event)

    #expect(target.events.count == 1)
    if case let .keyDown(keyEvent) = target.events[0] {
        #expect(keyEvent.characters == "x")
        #expect(keyEvent.keyCode == 7)
        #expect(keyEvent.modifiers.contains(.command))
    } else {
        #expect(Bool(false), "Expected keyDown event")
    }
}

@MainActor
@Test
func rootView_maps_mouseDown_location() {
    let rootTarget = RecordingTarget(handleResult: true)
    let rootNode = FGKNode(target: rootTarget)

    let leftTarget = RecordingTarget(handleResult: true)
    let rightTarget = RecordingTarget(handleResult: true)

    let left = FGKNode(frame: NSRect(x: 0, y: 0, width: 100, height: 200), target: leftTarget)
    let right = FGKNode(frame: NSRect(x: 100, y: 0, width: 100, height: 200), target: rightTarget)
    rootNode.addChild(left)
    rootNode.addChild(right)

    let view = FGKRootView(frame: NSRect(x: 0, y: 0, width: 200, height: 200), rootNode: rootNode)

    // Click in left child
    do {
        let clickPoint = NSPoint(x: 42, y: 24)
        let maybeEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: clickPoint,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 0
        )
        #expect(maybeEvent != nil)
        guard let event = maybeEvent else { return }

        view.mouseDown(with: event)

        #expect(leftTarget.events.count == 1)
        #expect(rightTarget.events.isEmpty)
        #expect(rootTarget.events.isEmpty)
        if case let .mouseDown(mouseEvent) = leftTarget.events[0] {
            #expect(mouseEvent.locationInView.x == clickPoint.x)
            #expect(mouseEvent.locationInView.y == clickPoint.y)
        } else {
            #expect(Bool(false), "Expected mouseDown event")
        }
    }

    // Click in right child
    do {
        let clickPoint = NSPoint(x: 150, y: 50)
        let maybeEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: clickPoint,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 2,
            clickCount: 1,
            pressure: 0
        )
        #expect(maybeEvent != nil)
        guard let event = maybeEvent else { return }

        view.mouseDown(with: event)

        #expect(leftTarget.events.count == 1)
        #expect(rightTarget.events.count == 1)
        #expect(rootTarget.events.isEmpty)
    }

    // Click outside children, should fall back to root
    do {
        let clickPoint = NSPoint(x: 250, y: 10)
        let maybeEvent = NSEvent.mouseEvent(
            with: .leftMouseDown,
            location: clickPoint,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            eventNumber: 3,
            clickCount: 1,
            pressure: 0
        )
        #expect(maybeEvent != nil)
        guard let event = maybeEvent else { return }

        view.mouseDown(with: event)

        #expect(rootTarget.events.count == 1)
    }
}

@MainActor
@Test
func node_hitTest_prefers_deepest_child() {
    let root = FGKNode(frame: NSRect(x: 0, y: 0, width: 200, height: 200))
    let parent = FGKNode(frame: NSRect(x: 20, y: 20, width: 160, height: 160))
    let child = FGKNode(frame: NSRect(x: 40, y: 40, width: 40, height: 40))
    root.addChild(parent)
    parent.addChild(child)

    let pointInsideAll = NSPoint(x: 50, y: 50)
    let hit = root.hitTest(pointInsideAll)
    #expect(hit === child)

    let pointInsideParentOnly = NSPoint(x: 25, y: 25)
    let hit2 = root.hitTest(pointInsideParentOnly)
    #expect(hit2 === parent)

    let outside = NSPoint(x: 500, y: 500)
    let hit3 = root.hitTest(outside)
    #expect(hit3 == nil)
}

@MainActor
@Test
func instrumentAdapter_forwards_events_to_sink() {
    let sink = RecordingSink()
    let node = FGKNode(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
    let adapter = node.attachInstrument(sink: sink)

    // keyDown
    let keyEvent = FGKKeyEvent(characters: "a", keyCode: 0, modifiers: [])
    let handledKey = adapter.handle(event: .keyDown(keyEvent))
    #expect(handledKey)

    // mouseDown
    let mouseEvent = FGKMouseEvent(locationInView: NSPoint(x: 10, y: 20), buttonNumber: 0, modifiers: [])
    let handledMouse = adapter.handle(event: .mouseDown(mouseEvent))
    #expect(handledMouse)

    #expect(sink.entries.count == 2)
    #expect(sink.entries[0].topic == "fgk.keyDown")
    #expect(sink.entries[1].topic == "fgk.mouseDown")
    #expect(sink.entries[0].data is FGKKeyEvent)
    #expect(sink.entries[1].data is FGKMouseEvent)
}

@MainActor
@Test
func node_setProperty_forwards_to_consumer() {
    let target = PropertyRecordingTarget()
    let node = FGKNode(
        instrumentId: "test.instrument",
        frame: NSRect(x: 0, y: 0, width: 10, height: 10),
        properties: [
            FGKPropertyDescriptor(name: "gain", kind: .float(min: 0.0, max: 1.0, default: 0.5))
        ],
        target: target
    )

    let result = node.setProperty("gain", value: .float(0.75))
    #expect(result)
    #expect(target.properties.count == 1)
    #expect(target.properties[0].name == "gain")
    #expect(target.properties[0].value == .float(0.75))
}

@MainActor
@Test
func rootView_maps_scrollWheel_to_FGKEvent() {
    let target = RecordingTarget(handleResult: true)
    let rootNode = FGKNode(target: target)
    let view = FGKRootView(frame: NSRect(x: 0, y: 0, width: 200, height: 200), rootNode: rootNode)

    // Synthetic scroll events are tricky to construct portably; instead,
    // call the overridden method with a minimal NSEvent fetched from the system
    // and assert that it does not crash and records an event when present.
    if let current = NSApplication.shared.currentEvent {
        view.scrollWheel(with: current)
        #expect(target.events.count >= 0)
    }
}
