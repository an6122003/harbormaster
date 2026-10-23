import AppKit
import SwiftUI

/// Drives `--snapshot <dir>`: walks through the main screens in demo mode, saves
/// a PNG of each, then quits. Captures only this app's own windows, so it needs
/// no Screen Recording permission — and, running on sample data, shows nothing
/// about the real machine.
@MainActor
enum SnapshotRunner {
    private static var hasRun = false

    private struct Shot {
        let name: String
        var settle: Double = 1.6
        let prepare: (PortListViewModel) -> Void
    }

    static func runIfRequested(viewModel: PortListViewModel) async {
        guard let directory = DemoMode.snapshotDirectory, !hasRun else { return }
        hasRun = true
        await run(viewModel: viewModel, into: directory)
        NSApp.terminate(nil)
    }

    private static func run(viewModel: PortListViewModel, into directory: URL) async {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        log("snapshot run → \(directory.path)", in: directory)

        guard let window = await findMainWindow() else {
            log("no main window found", in: directory)
            return
        }

        // Wide enough for the map's detail cards; centred, so on a smaller screen the
        // edges simply hang off it (the window's backing store is still captured in full).
        window.setContentSize(NSSize(width: 1560, height: 860))
        if let screen = window.screen ?? NSScreen.main {
            var frame = window.frame
            frame.origin.x = screen.frame.midX - frame.width / 2
            frame.origin.y = screen.visibleFrame.maxY - frame.height
            window.setFrame(frame, display: true)
            log("window \(window.frame.debugDescription) on screen visible \(screen.visibleFrame.debugDescription)", in: directory)
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        try? await Task.sleep(nanoseconds: 1_800_000_000)

        let storefront: Set<PortInfo.ID> = ["48211-3000"]
        let shots: [Shot] = [
            Shot(name: "overview-preview", settle: 2.8) { vm in
                vm.sidebarSection = .overview
                vm.mapViewMode = .networkMap
                vm.portsFilter = .all
                vm.requestedDetailTab = .preview
                vm.selectedPortIDs = storefront
            },
            Shot(name: "overview-details") { vm in vm.requestedDetailTab = .details },
            Shot(name: "overview-headers") { vm in vm.requestedDetailTab = .headers },
            Shot(name: "process-tree") { vm in vm.mapViewMode = .processTree },
            Shot(name: "connection-flow") { vm in vm.mapViewMode = .connectionFlow },
            Shot(name: "bulk-select") { vm in
                vm.mapViewMode = .networkMap
                vm.selectedPortIDs = ["48990-3001", "49102-4000", "50233-5173"]
            },
            Shot(name: "task-manager", settle: 3.2) { vm in
                vm.selectedPortIDs = []
                vm.sidebarSection = .taskManager
            },
            Shot(name: "processes") { vm in vm.sidebarSection = .processes },
            Shot(name: "alerts") { vm in vm.sidebarSection = .alerts },
            Shot(name: "history") { vm in vm.sidebarSection = .history },
            Shot(name: "ports") { vm in vm.sidebarSection = .ports },
        ]

        for shot in shots {
            shot.prepare(viewModel)
            try? await Task.sleep(nanoseconds: UInt64(shot.settle * 1_000_000_000))
            // Keystrokes aimed at another app can land in our search field while the
            // window is frontmost — never let that leak into a screenshot.
            viewModel.searchText = ""
            // Focus the list (if this screen has one) so its selection draws in the accent
            // colour, as it does while you're actually using the app.
            if let table = window.contentView.flatMap({ firstView(of: NSTableView.self, in: $0) }) {
                window.makeFirstResponder(table)
            } else {
                window.makeFirstResponder(nil)
            }
            try? await Task.sleep(nanoseconds: 350_000_000)
            save(capture(window), named: shot.name, in: directory)
        }

        viewModel.sidebarSection = .overview
        await menuBarShot(viewModel: viewModel, in: directory)
    }

    // MARK: - Menu bar dropdown

    /// The real dropdown is a transient panel owned by SwiftUI, which can't be opened
    /// programmatically — so host the same view in a panel of our own and capture that.
    private static func menuBarShot(viewModel: PortListViewModel, in directory: URL) async {
        let content = NSHostingView(rootView: MenuBarContentView().environmentObject(viewModel))
        content.frame = NSRect(x: 0, y: 0, width: 320, height: 600)
        let size = NSSize(width: 320, height: max(content.fittingSize.height, 200))

        let background = NSView(frame: NSRect(origin: .zero, size: size))
        background.wantsLayer = true
        background.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true
        content.frame = background.bounds
        content.autoresizingMask = [.width, .height]
        background.addSubview(content)

        let panel = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.contentView = background
        if let screen = NSScreen.main {
            panel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - size.width - 24,
                                         y: screen.visibleFrame.maxY - size.height - 12))
        }
        panel.orderFrontRegardless()
        try? await Task.sleep(nanoseconds: 1_800_000_000)
        save(capture(panel), named: "menu-bar", in: directory)
        panel.orderOut(nil)
    }

    // MARK: - Capture

    private static func firstView<T: NSView>(of type: T.Type, in view: NSView) -> T? {
        if let match = view as? T { return match }
        for subview in view.subviews {
            if let found = firstView(of: type, in: subview) { return found }
        }
        return nil
    }

    private static func findMainWindow() async -> NSWindow? {
        for _ in 0..<60 {
            if let window = NSApp.windows.first(where: { $0.title == "Port Manager" && $0.isVisible && $0.contentView != nil }) {
                return window
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return nil
    }

    /// `CGWindowListCreateImage` is flagged unavailable in recent SDKs (the replacement,
    /// ScreenCaptureKit, always asks for Screen Recording permission), but the symbol
    /// still exists and may still be used to capture a process's *own* windows.
    private static func capture(_ window: NSWindow) -> CGImage? {
        typealias CreateImage = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
        let optionIncludingWindow: UInt32 = 1 << 3
        let imageBestResolution: UInt32 = 1 << 3

        if let handle = dlopen(nil, RTLD_NOW), let symbol = dlsym(handle, "CGWindowListCreateImage") {
            let create = unsafeBitCast(symbol, to: CreateImage.self)
            if let image = create(.null, optionIncludingWindow, CGWindowID(window.windowNumber), imageBestResolution)?.takeRetainedValue() {
                return image
            }
        }

        guard let view = window.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return nil }
        view.cacheDisplay(in: view.bounds, to: rep)
        return rep.cgImage
    }

    private static func save(_ image: CGImage?, named name: String, in directory: URL) {
        guard let image,
              let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            log("FAILED  \(name)", in: directory)
            return
        }
        do {
            try data.write(to: directory.appendingPathComponent("\(name).png"))
            log("saved   \(name).png (\(image.width)×\(image.height))", in: directory)
        } catch {
            log("FAILED  \(name): \(error)", in: directory)
        }
    }

    private static func log(_ message: String, in directory: URL) {
        let line = message + "\n"
        let url = directory.appendingPathComponent("snapshot.log")
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(Data(line.utf8))
            try? handle.close()
        } else {
            try? Data(line.utf8).write(to: url)
        }
    }
}
