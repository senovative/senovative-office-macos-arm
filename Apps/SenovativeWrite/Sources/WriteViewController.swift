import AppKit
import SwiftUI
import SenovativeKit
import SenovativeUI

@MainActor
final class WriteViewController: NSViewController {
    private let document: WriteDocument

    init(document: WriteDocument) {
        self.document = document
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        let hostingView = NSHostingView(rootView: WriteDocumentView(state: document.state))
        view = hostingView
    }
}

private struct WriteDocumentView: View {
    @ObservedObject var state: WriteDocumentState

    var body: some View {
        VStack(spacing: 0) {
            RibbonShell {
                RibbonIconButton("Bold", systemImage: "bold") {
                    NSApplication.shared.sendAction(Selector(("toggleBoldface:")), to: nil, from: nil)
                }
                RibbonIconButton("Italic", systemImage: "italic") {
                    NSApplication.shared.sendAction(Selector(("toggleItalics:")), to: nil, from: nil)
                }
                RibbonIconButton("Underline", systemImage: "underline") {
                    NSApplication.shared.sendAction(Selector(("toggleUnderline:")), to: nil, from: nil)
                }
            }

            HSplitView {
                DocumentCanvas(state: state)
                    .frame(minWidth: 640, maxWidth: .infinity, maxHeight: .infinity)

                InspectorPlaceholder("Format")
            }

            statusBar
        }
        .background(SenovativeTheme.canvasBackground)
    }

    private var statusBar: some View {
        HStack {
            StatusPill(LocalizedStringKey(state.statusText))
            Spacer()
            Text("DOCX")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(SenovativeTheme.chromeBackground)
        .overlay(alignment: .top) {
            SenovativeTheme.divider.frame(height: 1)
        }
    }
}

/// TextKit 2 editing surface bridged into SwiftUI. The document model is the
/// source of truth on load; while editing, the text view is the source of truth
/// and pushes changes back into the model on every edit.
private struct DocumentCanvas: NSViewRepresentable {
    @ObservedObject var state: WriteDocumentState

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        // Force a TextKit 2 (NSTextLayoutManager) backing store.
        let textView = NSTextView(usingTextLayoutManager: true)
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFontPanel = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .labelColor
        textView.font = WriteAttributedStringBridge.defaultFont
        textView.textContainerInset = NSSize(width: 48, height: 48)
        textView.delegate = context.coordinator

        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.loadFromModel()
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.reloadIfExternallyChanged()
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        private let state: WriteDocumentState
        weak var textView: NSTextView?
        private var lastLoadToken = -1
        private var isLoading = false

        init(state: WriteDocumentState) {
            self.state = state
        }

        /// Render the current model into the text view (used on first load and
        /// whenever the document is replaced from disk).
        func loadFromModel() {
            guard let textView, let storage = textView.textStorage else { return }
            isLoading = true
            storage.setAttributedString(WriteAttributedStringBridge.attributedString(from: state.model))
            textView.typingAttributes = WriteAttributedStringBridge.defaultTypingAttributes
            lastLoadToken = state.loadToken
            isLoading = false
        }

        func reloadIfExternallyChanged() {
            if state.loadToken != lastLoadToken {
                loadFromModel()
            }
        }

        func textDidChange(_ notification: Notification) {
            guard !isLoading, let storage = textView?.textStorage else { return }
            let model = WriteAttributedStringBridge.model(from: storage, title: state.model.title)
            state.model = model
            state.document?.updateChangeCount(.changeDone)
        }
    }
}

/// Bridges the formatted document model to/from `NSAttributedString` for the
/// editor. Bold/italic are carried by the font's traits; underline by
/// `.underlineStyle`.
private enum WriteAttributedStringBridge {
    static let defaultFontSize: CGFloat = 15
    static var defaultFont: NSFont { .systemFont(ofSize: defaultFontSize) }

    static var defaultTypingAttributes: [NSAttributedString.Key: Any] {
        [.font: defaultFont, .foregroundColor: NSColor.labelColor]
    }

    static func attributedString(from model: WriteDocumentModel) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for (index, paragraph) in model.paragraphs.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "\n", attributes: defaultTypingAttributes))
            }
            for run in paragraph.runs {
                result.append(NSAttributedString(string: run.text, attributes: attributes(for: run)))
            }
        }
        return result
    }

    static func model(from attributed: NSAttributedString, title: String) -> WriteDocumentModel {
        var paragraphs: [WriteParagraph] = []
        var currentRuns: [WriteRun] = []

        let fullRange = NSRange(location: 0, length: attributed.length)
        attributed.enumerateAttributes(in: fullRange, options: []) { attrs, range, _ in
            let substring = (attributed.string as NSString).substring(with: range)
            let bold = isBold(attrs)
            let italic = isItalic(attrs)
            let underline = isUnderlined(attrs)

            let segments = substring.components(separatedBy: "\n")
            for (offset, segment) in segments.enumerated() {
                if offset > 0 {
                    paragraphs.append(WriteParagraph(runs: currentRuns))
                    currentRuns = []
                }
                if !segment.isEmpty {
                    currentRuns.append(
                        WriteRun(text: segment, bold: bold, italic: italic, underline: underline)
                    )
                }
            }
        }
        paragraphs.append(WriteParagraph(runs: currentRuns))

        return WriteDocumentModel(title: title, paragraphs: paragraphs)
    }

    private static func attributes(for run: WriteRun) -> [NSAttributedString.Key: Any] {
        let manager = NSFontManager.shared
        var font = defaultFont
        if run.bold { font = manager.convert(font, toHaveTrait: .boldFontMask) }
        if run.italic { font = manager.convert(font, toHaveTrait: .italicFontMask) }

        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
        ]
        if run.underline {
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        return attrs
    }

    private static func isBold(_ attrs: [NSAttributedString.Key: Any]) -> Bool {
        guard let font = attrs[.font] as? NSFont else { return false }
        return NSFontManager.shared.traits(of: font).contains(.boldFontMask)
    }

    private static func isItalic(_ attrs: [NSAttributedString.Key: Any]) -> Bool {
        guard let font = attrs[.font] as? NSFont else { return false }
        return NSFontManager.shared.traits(of: font).contains(.italicFontMask)
    }

    private static func isUnderlined(_ attrs: [NSAttributedString.Key: Any]) -> Bool {
        guard let raw = attrs[.underlineStyle] as? Int else { return false }
        return raw != 0
    }
}
