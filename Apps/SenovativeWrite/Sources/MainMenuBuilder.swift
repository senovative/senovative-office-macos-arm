import AppKit
import SenovativeKit

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
        menu.addItem(templateMenu())
        menu.addItem(withTitle: String(localized: "Open..."), action: #selector(NSDocumentController.openDocument(_:)), keyEquivalent: "o")
        menu.addItem(openRecentMenu())
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Close"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        menu.addItem(withTitle: String(localized: "Save..."), action: #selector(NSDocument.save(_:)), keyEquivalent: "s")
        menu.addItem(withTitle: String(localized: "Save As..."), action: #selector(NSDocument.saveAs(_:)), keyEquivalent: "S")
        menu.addItem(withTitle: String(localized: "Duplicate"), action: #selector(NSDocument.duplicate(_:)), keyEquivalent: "")
        menu.addItem(withTitle: String(localized: "Rename..."), action: #selector(NSDocument.rename(_:)), keyEquivalent: "")
        menu.addItem(withTitle: String(localized: "Move To..."), action: #selector(NSDocument.move(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Revert To Saved"), action: #selector(NSDocument.revertToSaved(_:)), keyEquivalent: "")
        menu.addItem(withTitle: String(localized: "Browse All Versions..."), action: #selector(NSDocument.browseVersions(_:)), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Export PDF..."), action: #selector(RichTextView.exportPDF(_:)), keyEquivalent: "e").keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(withTitle: String(localized: "Print..."), action: #selector(RichTextView.printDocumentView(_:)), keyEquivalent: "p")
        item.submenu = menu
        return item
    }

    private static func templateMenu() -> NSMenuItem {
        let item = NSMenuItem(title: String(localized: "New From Template"), action: nil, keyEquivalent: "")
        let menu = NSMenu(title: String(localized: "New From Template"))
        let templates: [(String, Selector)] = [
            (String(localized: "Blank Document"), #selector(TemplateDocumentHandler.newBlankDocument(_:))),
            (String(localized: "Business Letter"), #selector(TemplateDocumentHandler.newBusinessLetter(_:))),
            (String(localized: "Report"), #selector(TemplateDocumentHandler.newReport(_:))),
            (String(localized: "Meeting Notes"), #selector(TemplateDocumentHandler.newMeetingNotes(_:))),
        ]
        for template in templates {
            let templateItem = NSMenuItem(title: template.0, action: template.1, keyEquivalent: "")
            templateItem.target = TemplateDocumentHandler.shared
            menu.addItem(templateItem)
        }
        item.submenu = menu
        return item
    }

    private static func openRecentMenu() -> NSMenuItem {
        let item = NSMenuItem(title: String(localized: "Open Recent"), action: nil, keyEquivalent: "")
        let menu = NSMenu(title: String(localized: "Open Recent"))
        menu.delegate = RecentDocumentMenuHandler.shared
        RecentDocumentMenuHandler.shared.rebuild(menu)
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
        menu.addItem(.separator())
        menu.addItem(findMenu())
        item.submenu = menu
        return item
    }

    private static func findMenu() -> NSMenuItem {
        let item = NSMenuItem(title: String(localized: "Find"), action: nil, keyEquivalent: "")
        let menu = NSMenu(title: String(localized: "Find"))
        menu.addItem(withTitle: String(localized: "Find & Replace..."), action: #selector(RichTextView.showFindReplacePanel(_:)), keyEquivalent: "f")
        menu.addItem(withTitle: String(localized: "Find Next"), action: #selector(RichTextView.findNext(_:)), keyEquivalent: "g")
        menu.addItem(withTitle: String(localized: "Find Previous"), action: #selector(RichTextView.findPrevious(_:)), keyEquivalent: "G")
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Replace"), action: #selector(RichTextView.replaceSelectionOrNext(_:)), keyEquivalent: "")
        menu.addItem(withTitle: String(localized: "Replace All"), action: #selector(RichTextView.replaceAllMatches(_:)), keyEquivalent: "")
        item.submenu = menu
        return item
    }

    private static func formatMenu() -> NSMenuItem {
        let item = NSMenuItem()
        let menu = NSMenu(title: String(localized: "Format"))
        menu.addItem(withTitle: String(localized: "Bold"), action: Selector(("toggleBoldface:")), keyEquivalent: "b")
        menu.addItem(withTitle: String(localized: "Italic"), action: Selector(("toggleItalics:")), keyEquivalent: "i")
        menu.addItem(withTitle: String(localized: "Underline"), action: Selector(("toggleUnderline:")), keyEquivalent: "u")
        menu.addItem(.separator())
        menu.addItem(styleMenu())
        menu.addItem(.separator())
        menu.addItem(withTitle: String(localized: "Check Spelling While Typing"), action: #selector(NSTextView.toggleContinuousSpellChecking(_:)), keyEquivalent: "")
        menu.addItem(withTitle: String(localized: "Check Grammar With Spelling"), action: #selector(NSTextView.toggleGrammarChecking(_:)), keyEquivalent: "")
        item.submenu = menu
        return item
    }

    private static func styleMenu() -> NSMenuItem {
        let item = NSMenuItem(title: String(localized: "Styles"), action: nil, keyEquivalent: "")
        let menu = NSMenu(title: String(localized: "Styles"))
        menu.addItem(withTitle: String(localized: "Title"), action: #selector(RichTextView.applyTitleStyle(_:)), keyEquivalent: "")
        menu.addItem(withTitle: String(localized: "Heading 1"), action: #selector(RichTextView.applyHeading1Style(_:)), keyEquivalent: "1").keyEquivalentModifierMask = [.command, .option]
        menu.addItem(withTitle: String(localized: "Heading 2"), action: #selector(RichTextView.applyHeading2Style(_:)), keyEquivalent: "2").keyEquivalentModifierMask = [.command, .option]
        menu.addItem(withTitle: String(localized: "Body"), action: #selector(RichTextView.applyBodyStyle(_:)), keyEquivalent: "0").keyEquivalentModifierMask = [.command, .option]
        menu.addItem(withTitle: String(localized: "Quote"), action: #selector(RichTextView.applyQuoteStyle(_:)), keyEquivalent: "")
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

@MainActor
private final class RecentDocumentMenuHandler: NSObject, NSMenuDelegate {
    static let shared = RecentDocumentMenuHandler()

    func menuNeedsUpdate(_ menu: NSMenu) {
        rebuild(menu)
    }

    func rebuild(_ menu: NSMenu) {
        menu.removeAllItems()
        let recentURLs = NSDocumentController.shared.recentDocumentURLs
        if recentURLs.isEmpty {
            let emptyItem = NSMenuItem(title: String(localized: "No Recent Documents"), action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for url in recentURLs {
                let recentItem = NSMenuItem(title: url.lastPathComponent, action: #selector(RecentDocumentMenuHandler.openRecentDocument(_:)), keyEquivalent: "")
                recentItem.target = RecentDocumentMenuHandler.shared
                recentItem.representedObject = url
                menu.addItem(recentItem)
            }
        }
        menu.addItem(.separator())
        let clearItem = NSMenuItem(title: String(localized: "Clear Menu"), action: #selector(RecentDocumentMenuHandler.clearRecentDocuments(_:)), keyEquivalent: "")
        clearItem.target = RecentDocumentMenuHandler.shared
        menu.addItem(clearItem)
    }

    @objc func openRecentDocument(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
    }

    @objc func clearRecentDocuments(_ sender: Any?) {
        NSDocumentController.shared.clearRecentDocuments(sender)
    }
}

@MainActor
private final class TemplateDocumentHandler: NSObject {
    static let shared = TemplateDocumentHandler()

    @objc func newBlankDocument(_ sender: Any?) {
        createDocument(from: .blank)
    }

    @objc func newBusinessLetter(_ sender: Any?) {
        createDocument(from: .businessLetter)
    }

    @objc func newReport(_ sender: Any?) {
        createDocument(from: .report)
    }

    @objc func newMeetingNotes(_ sender: Any?) {
        createDocument(from: .meetingNotes)
    }

    private func createDocument(from template: WriteDocumentTemplate) {
        do {
            guard let document = try NSDocumentController.shared.openUntitledDocumentAndDisplay(true) as? WriteDocument else { return }
            document.state.loadModel(template.model, status: String(localized: "Created \(template.displayName)"))
            document.updateChangeCount(.changeDone)
        } catch {
            NSAlert(error: error).runModal()
        }
    }
}
