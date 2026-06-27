import AppKit

@MainActor
enum MainMenuBuilder {
    static func install() {
        let mainMenu = NSMenu(title: "Main Menu")
        mainMenu.addItem(applicationMenu())
        mainMenu.addItem(fileMenu())
        mainMenu.addItem(editMenu())
        mainMenu.addItem(formatMenu())
        mainMenu.addItem(windowMenu())
        mainMenu.addItem(helpMenu())
        NSApplication.shared.mainMenu = mainMenu
    }

    private static func applicationMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: "Senovative Write")
        menu.addItem(withTitle: String(localized: "About Senovative Write"), action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Services"), action: nil, keyEquivalent: "").submenu = NSMenu(title: "Services")
        NSApplication.shared.servicesMenu = menu.items.last?.submenu
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Hide Senovative Write"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        menu.addItem(withTitle: String(localized: "Hide Others"), action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h").keyEquivalentModifierMask = [.command, .option]
        menu.addItem(withTitle: String(localized: "Show All"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Quit Senovative Write"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = menu
        return item
    }

    private static func fileMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: String(localized: "File"))
        menu.addItem(withTitle: String(localized: "New"), action: #selector(NSDocumentController.newDocument(_:)), keyEquivalent: "n")
        menu.addItem(withTitle: String(localized: "Open..."), action: #selector(NSDocumentController.openDocument(_:)), keyEquivalent: "o")
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        menu.addItem(withTitle: String(localized: "Save..."), action: #selector(NSDocument.save(_:)), keyEquivalent: "s")
        menu.addItem(withTitle: String(localized: "Save As..."), action: #selector(NSDocument.saveAs(_:)), keyEquivalent: "S")
        item.submenu = menu
        return item
    }

    private static func editMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: String(localized: "Edit"))
        menu.addItem(withTitle: String(localized: "Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        menu.addItem(withTitle: String(localized: "Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        menu.addItem(withTitle: String(localized: "Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        menu.addItem(withTitle: String(localized: "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        menu.addItem(withTitle: String(localized: "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        item.submenu = menu
        return item
    }

    private static func formatMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: String(localized: "Format"))
        menu.addItem(withTitle: String(localized: "Bold"), action: Selector(("toggleBoldface:")), keyEquivalent: "b")
        menu.addItem(withTitle: String(localized: "Italic"), action: Selector(("toggleItalics:")), keyEquivalent: "i")
        menu.addItem(withTitle: String(localized: "Underline"), action: Selector(("toggleUnderline:")), keyEquivalent: "u")
        item.submenu = menu
        return item
    }

    private static func windowMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: String(localized: "Window"))
        menu.addItem(withTitle: String(localized: "Minimize"), action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        menu.addItem(withTitle: String(localized: "Zoom"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        NSApplication.shared.windowsMenu = menu
        item.submenu = menu
        return item
    }

    private static func helpMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: String(localized: "Help"))
        menu.addItem(withTitle: String(localized: "Senovative Write Help"), action: nil, keyEquivalent: "?")
        NSApplication.shared.helpMenu = menu
        item.submenu = menu
        return item
    }
}
