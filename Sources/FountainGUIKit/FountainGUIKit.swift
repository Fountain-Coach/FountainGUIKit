import AppKit

/// Canonical event types understood by FountainGUIKit.
public enum FGKEvent {
    case keyDown(FGKKeyEvent)
    case keyUp(FGKKeyEvent)
    case mouseDown(FGKMouseEvent)
    case mouseUp(FGKMouseEvent)
    case mouseMoved(FGKMouseEvent)
}

public struct FGKKeyEvent {
    public let characters: String
    public let keyCode: UInt16
    public let modifiers: NSEvent.ModifierFlags

    public init(characters: String, keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.characters = characters
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

public struct FGKMouseEvent {
    public let locationInView: NSPoint
    public let buttonNumber: Int
    public let modifiers: NSEvent.ModifierFlags

    public init(locationInView: NSPoint, buttonNumber: Int, modifiers: NSEvent.ModifierFlags) {
        self.locationInView = locationInView
        self.buttonNumber = buttonNumber
        self.modifiers = modifiers
    }
}

/// Basic event target for the custom responder chain.
public protocol FGKEventTarget: AnyObject {
    /// Handle an event. Return true if the event was consumed.
    func handle(event: FGKEvent) -> Bool
}

/// Node in the FountainGUIKit view hierarchy.
///
/// This is separate from NSView so that event routing and instrument identity
/// remain independent from AppKit's responder chain.
public final class FGKNode {
    public weak var parent: FGKNode?
    public var children: [FGKNode] = []

    /// Optional instrument identity (e.g. MIDI 2.0 instrument id).
    public var instrumentId: String?

    /// Event sink for this node.
    public weak var target: FGKEventTarget?

    public init(instrumentId: String? = nil, target: FGKEventTarget? = nil) {
        self.instrumentId = instrumentId
        self.target = target
    }

    public func addChild(_ node: FGKNode) {
        children.append(node)
        node.parent = self
    }

    /// Bubble an event from this node up through its parents until handled.
    @discardableResult
    public func bubble(event: FGKEvent) -> Bool {
        var node: FGKNode? = self
        while let current = node {
            if let handled = current.target?.handle(event: event), handled {
                return true
            }
            node = current.parent
        }
        return false
    }
}

/// Root NSView hosting a FountainGUIKit hierarchy.
///
/// Apps embed this view in their own windowing system. Internally we map
/// NSEvent instances into FGKEvent values and dispatch via the FGKNode tree
/// instead of using AppKit's responder chain.
open class FGKRootView: NSView {
    public let rootNode: FGKNode

    public init(frame: NSRect, rootNode: FGKNode) {
        self.rootNode = rootNode
        super.init(frame: frame)
        acceptsFirstResponder = true
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override var acceptsFirstResponder: Bool {
        get { true }
        set { }
    }

    // MARK: - Event mapping

    open override func keyDown(with event: NSEvent) {
        let e = FGKKeyEvent(
            characters: event.characters ?? "",
            keyCode: event.keyCode,
            modifiers: event.modifierFlags
        )
        _ = rootNode.bubble(event: .keyDown(e))
    }

    open override func keyUp(with event: NSEvent) {
        let e = FGKKeyEvent(
            characters: event.characters ?? "",
            keyCode: event.keyCode,
            modifiers: event.modifierFlags
        )
        _ = rootNode.bubble(event: .keyUp(e))
    }

    open override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let e = FGKMouseEvent(
            locationInView: p,
            buttonNumber: Int(event.buttonNumber),
            modifiers: event.modifierFlags
        )
        _ = rootNode.bubble(event: .mouseDown(e))
    }

    open override func mouseUp(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let e = FGKMouseEvent(
            locationInView: p,
            buttonNumber: Int(event.buttonNumber),
            modifiers: event.modifierFlags
        )
        _ = rootNode.bubble(event: .mouseUp(e))
    }

    open override func mouseMoved(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let e = FGKMouseEvent(
            locationInView: p,
            buttonNumber: Int(event.buttonNumber),
            modifiers: event.modifierFlags
        )
        _ = rootNode.bubble(event: .mouseMoved(e))
    }
}
