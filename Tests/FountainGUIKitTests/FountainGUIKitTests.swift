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
