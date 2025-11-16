import AppKit
import FountainGUIKit

private final class DemoTarget: FGKEventTarget {
    func handle(event: FGKEvent) -> Bool {
        switch event {
        case .keyDown(let key):
            fputs("[FGKDemo] keyDown chars=\(key.characters) code=\(key.keyCode)\n", stderr)
        case .keyUp(let key):
            fputs("[FGKDemo] keyUp chars=\(key.characters) code=\(key.keyCode)\n", stderr)
        case .mouseDown(let mouse):
            fputs("[FGKDemo] mouseDown at=\(mouse.locationInView)\n", stderr)
        case .mouseUp(let mouse):
            fputs("[FGKDemo] mouseUp at=\(mouse.locationInView)\n", stderr)
        case .mouseMoved(let mouse):
            fputs("[FGKDemo] mouseMoved at=\(mouse.locationInView)\n", stderr)
        }
        return true
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    private var demoTarget: DemoTarget?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentSize = NSSize(width: 640, height: 400)
        let rootNode = FGKNode(
            instrumentId: "fountain.gui.demo.surface",
            frame: NSRect(origin: .zero, size: contentSize),
            properties: []
        )
        let target = DemoTarget()
        demoTarget = target
        rootNode.target = target

        let rootView = FGKRootView(
            frame: NSRect(origin: .zero, size: contentSize),
            rootNode: rootNode
        )
        rootView.wantsLayer = true
        rootView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let window = NSWindow(
            contentRect: rootView.frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "FountainGUIKit Demo"
        window.contentView = rootView
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }
}

@main
enum FountainGUIDemoMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
