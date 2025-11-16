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

/// Canonical value types for instrument properties.
public enum FGKPropertyValue: Equatable {
    case bool(Bool)
    case int(Int)
    case float(Double)
}

/// Descriptor for a single instrument property.
public enum FGKPropertyKind: Equatable {
    case bool(default: Bool)
    case int(min: Int, max: Int, default: Int)
    case float(min: Double, max: Double, default: Double)
}

public struct FGKPropertyDescriptor: Equatable {
    public let name: String
    public let kind: FGKPropertyKind

    public init(name: String, kind: FGKPropertyKind) {
        self.name = name
        self.kind = kind
    }
}

/// Target that can apply property changes by name.
public protocol FGKPropertyConsumer: AnyObject {
    func setProperty(_ name: String, value: FGKPropertyValue)
}

/// Minimal instrument sink interface compatible with MetalViewKit renderers.
///
/// Types such as `MetalSceneRenderer` can conform to this protocol in consumers
/// so that FountainGUIKit can forward higher‑level events without depending on
/// MetalViewKit directly.
public protocol FGKInstrumentSink: AnyObject {
    func vendorEvent(topic: String, data: Any?)
}

/// Node in the FountainGUIKit view hierarchy.
///
/// This is separate from NSView so that event routing and instrument identity
/// remain independent from AppKit's responder chain.
public final class FGKNode {
    public weak var parent: FGKNode?
    public var children: [FGKNode] = []

    /// Optional frame for this node in the root view's coordinate space.
    public var frame: NSRect

    /// Optional property schema for this node when it acts as an instrument.
    public var properties: [FGKPropertyDescriptor]

    /// Optional instrument identity (e.g. MIDI 2.0 instrument id).
    public var instrumentId: String?

    /// Event sink for this node.
    public weak var target: FGKEventTarget?

    public init(instrumentId: String? = nil,
                frame: NSRect = .zero,
                properties: [FGKPropertyDescriptor] = [],
                target: FGKEventTarget? = nil) {
        self.frame = frame
        self.properties = properties
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

    /// Perform a hit test starting from this node.
    ///
    /// Traverses children in reverse order (last added considered frontmost) and
    /// returns the deepest node whose frame contains the given point. Returns
    /// nil when no node claims the point.
    public func hitTest(_ point: NSPoint) -> FGKNode? {
        for child in children.reversed() {
            if let hit = child.hitTest(point) {
                return hit
            }
        }
        if frame.contains(point) {
            return self
        }
        return nil
    }

    /// Apply a property change to this node's target when supported.
    ///
    /// This is the local counterpart to CI/PE SET operations in a MIDI 2.0
    /// environment; consumers can bridge CI/PE payloads into calls here.
    @discardableResult
    public func setProperty(_ name: String, value: FGKPropertyValue) -> Bool {
        guard let consumer = target as? FGKPropertyConsumer else { return false }
        consumer.setProperty(name, value: value)
        return true
    }
}

/// Default event target that forwards FGK events to an instrument sink.
///
/// This is the glue between the FGK node graph and an underlying renderer or
/// instrument implementation (for example a MetalViewKit scene renderer).
public final class FGKInstrumentAdapter: FGKEventTarget {
    public weak var sink: FGKInstrumentSink?

    public init(sink: FGKInstrumentSink?) {
        self.sink = sink
    }

    public func handle(event: FGKEvent) -> Bool {
        guard let sink else { return false }
        switch event {
        case .keyDown(let key):
            sink.vendorEvent(topic: "fgk.keyDown", data: key)
            return true
        case .keyUp(let key):
            sink.vendorEvent(topic: "fgk.keyUp", data: key)
            return true
        case .mouseDown(let mouse):
            sink.vendorEvent(topic: "fgk.mouseDown", data: mouse)
            return true
        case .mouseUp(let mouse):
            sink.vendorEvent(topic: "fgk.mouseUp", data: mouse)
            return true
        case .mouseMoved(let mouse):
            sink.vendorEvent(topic: "fgk.mouseMoved", data: mouse)
            return true
        }
    }
}

public extension FGKNode {
    /// Attach an instrument sink to this node via a default adapter.
    ///
    /// The adapter becomes this node's event target and forwards FGK events
    /// as vendor events to the sink. Consumers can use this with a conforming
    /// MetalViewKit renderer to bind UI events to instrument behaviour.
    @discardableResult
    func attachInstrument(sink: FGKInstrumentSink?) -> FGKInstrumentAdapter {
        let adapter = FGKInstrumentAdapter(sink: sink)
        self.target = adapter
        return adapter
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
        let targetNode = rootNode.hitTest(p) ?? rootNode
        _ = targetNode.bubble(event: .mouseDown(e))
    }

    open override func mouseUp(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let e = FGKMouseEvent(
            locationInView: p,
            buttonNumber: Int(event.buttonNumber),
            modifiers: event.modifierFlags
        )
        let targetNode = rootNode.hitTest(p) ?? rootNode
        _ = targetNode.bubble(event: .mouseUp(e))
    }

    open override func mouseMoved(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let e = FGKMouseEvent(
            locationInView: p,
            buttonNumber: Int(event.buttonNumber),
            modifiers: event.modifierFlags
        )
        let targetNode = rootNode.hitTest(p) ?? rootNode
        _ = targetNode.bubble(event: .mouseMoved(e))
    }
}
