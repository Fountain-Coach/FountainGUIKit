import AppKit
import Testing
@testable import FountainGUIKit

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
    let target = RecordingTarget(handleResult: true)
    let rootNode = FGKNode(target: target)
    let view = FGKRootView(frame: NSRect(x: 0, y: 0, width: 200, height: 200), rootNode: rootNode)

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

    #expect(target.events.count == 1)
    if case let .mouseDown(mouseEvent) = target.events[0] {
        #expect(mouseEvent.locationInView.x == clickPoint.x)
        #expect(mouseEvent.locationInView.y == clickPoint.y)
    } else {
        #expect(Bool(false), "Expected mouseDown event")
    }
}
