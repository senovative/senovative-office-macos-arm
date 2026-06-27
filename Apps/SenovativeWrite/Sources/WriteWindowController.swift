import AppKit

@MainActor
final class WriteWindowController: NSWindowController, NSToolbarDelegate {
    enum ToolbarItem {
        static let new = NSToolbarItem.Identifier("SenovativeWrite.Toolbar.New")
        static let open = NSToolbarItem.Identifier("SenovativeWrite.Toolbar.Open")
        static let save = NSToolbarItem.Identifier("SenovativeWrite.Toolbar.Save")
        static let flexible = NSToolbarItem.Identifier.flexibleSpace
        static let inspector = NSToolbarItem.Identifier("SenovativeWrite.Toolbar.Inspector")
    }

    init(document: WriteDocument) {
        let viewController = WriteViewController(document: document)
        let window = NSWindow(contentViewController: viewController)
        window.title = String(localized: "Senovative Write")
        window.minSize = NSSize(width: 900, height: 620)
        window.setContentSize(NSSize(width: 1100, height: 760))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.toolbar = Self.makeToolbar(delegate: nil)

        super.init(window: window)
        window.toolbar?.delegate = self
        shouldCascadeWindows = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    private static func makeToolbar(delegate: NSToolbarDelegate?) -> NSToolbar {
        let toolbar = NSToolbar(identifier: "SenovativeWrite.Toolbar")
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = true
        toolbar.autosavesConfiguration = true
        toolbar.delegate = delegate
        return toolbar
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.new, .open, .save, ToolbarItem.flexible, .inspector]
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [.new, .open, .save, ToolbarItem.flexible, .inspector]
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        switch itemIdentifier {
        case ToolbarItem.new:
            return toolbarItem(
                identifier: itemIdentifier,
                label: String(localized: "New"),
                symbol: "doc.badge.plus",
                action: #selector(NSDocumentController.newDocument(_:))
            )
        case ToolbarItem.open:
            return toolbarItem(
                identifier: itemIdentifier,
                label: String(localized: "Open"),
                symbol: "folder",
                action: #selector(NSDocumentController.openDocument(_:))
            )
        case ToolbarItem.save:
            return toolbarItem(
                identifier: itemIdentifier,
                label: String(localized: "Save"),
                symbol: "square.and.arrow.down",
                action: #selector(NSDocument.save(_:))
            )
        case ToolbarItem.inspector:
            return toolbarItem(
                identifier: itemIdentifier,
                label: String(localized: "Inspector"),
                symbol: "sidebar.right",
                action: nil
            )
        default:
            return nil
        }
    }

    private func toolbarItem(identifier: NSToolbarItem.Identifier, label: String, symbol: String, action: Selector?) -> NSToolbarItem {
        let item = NSToolbarItem(itemIdentifier: identifier)
        item.label = label
        item.paletteLabel = label
        item.toolTip = label
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        item.target = nil
        item.action = action
        return item
    }
}

private extension NSToolbarItem.Identifier {
    static let new = WriteWindowController.ToolbarItem.new
    static let open = WriteWindowController.ToolbarItem.open
    static let save = WriteWindowController.ToolbarItem.save
    static let inspector = WriteWindowController.ToolbarItem.inspector
}
