import AppKit

/// The app's "P" mark — a transparent-background glyph cropped from the source
/// icon (Resources/MenuBarIcon.png, copied into the bundle by build-app.sh).
/// Falls back to a generic SF Symbol if the bundled asset isn't found (e.g.
/// running via `swift run` in development rather than the packaged .app).
enum AppLogo {
    /// Raw loaded image at its native pixel size (~800pt as NSImage sees it —
    /// callers must resize before handing this to anything AppKit-bridged, since
    /// that's far too large for e.g. a status item).
    static let rawImage: NSImage = {
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSImage(systemSymbolName: "shippingbox.fill", accessibilityDescription: "Port Manager") ?? NSImage()
    }()

    /// A copy explicitly sized to a given point height (aspect ratio preserved),
    /// for AppKit-bridged contexts like MenuBarExtra's status item — SwiftUI's
    /// own `.resizable()`/`.aspectRatio()` modifiers don't reliably constrain
    /// size once bridged through to NSStatusItem.
    static func sized(toHeight height: CGFloat) -> NSImage {
        guard let copy = rawImage.copy() as? NSImage else { return rawImage }
        let nativeSize = rawImage.size
        let aspectRatio = nativeSize.height > 0 ? nativeSize.width / nativeSize.height : 1
        copy.size = NSSize(width: height * aspectRatio, height: height)
        return copy
    }
}
