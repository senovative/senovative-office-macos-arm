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
                RibbonIconButton("Fonts", systemImage: "textformat") {
                    NSFontManager.shared.orderFrontFontPanel(nil)
                }
                RibbonIconButton("Text Color", systemImage: "paintpalette") {
                    NSApplication.shared.orderFrontColorPanel(nil)
                }
                RibbonIconButton("Bold", systemImage: "bold") {
                    NSApplication.shared.sendAction(Selector(("toggleBoldface:")), to: nil, from: nil)
                }
                RibbonIconButton("Italic", systemImage: "italic") {
                    NSApplication.shared.sendAction(Selector(("toggleItalics:")), to: nil, from: nil)
                }
                RibbonIconButton("Underline", systemImage: "underline") {
                    NSApplication.shared.sendAction(Selector(("toggleUnderline:")), to: nil, from: nil)
                }
                RibbonIconButton("Highlight", systemImage: "highlighter") {
                    NSApplication.shared.sendAction(#selector(RichTextView.toggleHighlight(_:)), to: nil, from: nil)
                }
                RibbonIconButton("Align Left", systemImage: "text.alignleft") {
                    NSApplication.shared.sendAction(#selector(NSText.alignLeft(_:)), to: nil, from: nil)
                }
                RibbonIconButton("Align Center", systemImage: "text.aligncenter") {
                    NSApplication.shared.sendAction(#selector(NSText.alignCenter(_:)), to: nil, from: nil)
                }
                RibbonIconButton("Align Right", systemImage: "text.alignright") {
                    NSApplication.shared.sendAction(#selector(NSText.alignRight(_:)), to: nil, from: nil)
                }
                RibbonIconButton("Bullet List", systemImage: "list.bullet") {
                    NSApplication.shared.sendAction(#selector(RichTextView.toggleBulletList(_:)), to: nil, from: nil)
                }
                RibbonIconButton("Numbered List", systemImage: "list.number") {
                    NSApplication.shared.sendAction(#selector(RichTextView.toggleNumberedList(_:)), to: nil, from: nil)
                }
                RibbonIconButton("Superscript", systemImage: "textformat.superscript") {
                    NSApplication.shared.sendAction(#selector(RichTextView.toggleSuperscript(_:)), to: nil, from: nil)
                }
                RibbonIconButton("Subscript", systemImage: "textformat.subscript") {
                    NSApplication.shared.sendAction(#selector(RichTextView.toggleSubscript(_:)), to: nil, from: nil)
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
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = .underPageBackgroundColor
        scrollView.hasVerticalRuler = true
        scrollView.hasHorizontalRuler = true
        scrollView.rulersVisible = true

        // Force a TextKit 2 (NSTextLayoutManager) backing store.
        let textView = RichTextView(usingTextLayoutManager: true)
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = true
        textView.allowsUndo = true
        textView.usesFontPanel = true
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .labelColor
        textView.font = WriteAttributedStringBridge.defaultFont
        textView.delegate = context.coordinator

        let pageSize = state.model.section.pageSize
        let margins = state.model.section.margins
        let pageGap: CGFloat = 40

        textView.textContainerInset = NSSize(width: margins.left, height: margins.top)

        textView.minSize = NSSize(width: pageSize.width, height: pageSize.height)
        textView.maxSize = NSSize(width: pageSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.frame = NSRect(x: 0, y: 0, width: pageSize.width, height: pageSize.height)
        textView.textContainer?.size = NSSize(width: pageSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false

        // Transparent background, PageContainerView will draw the pages
        textView.drawsBackground = false
        textView.backgroundColor = .clear

        // Add exclusion paths for gaps between pages
        var paths: [NSBezierPath] = []
        for i in 1...500 {
            let gapRect = NSRect(x: 0, y: CGFloat(i) * pageSize.height + CGFloat(i - 1) * pageGap, width: pageSize.width, height: pageGap)
            paths.append(NSBezierPath(rect: gapRect))
        }
        textView.textContainer?.exclusionPaths = paths

        let nsPageSize = NSSize(width: pageSize.width, height: pageSize.height)
        let containerView = PageContainerView(textView: textView, pageSize: nsPageSize, pageGap: pageGap)
        scrollView.documentView = containerView
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
                result.append(NSAttributedString(string: "\n", attributes: paragraphAttributes(for: paragraph)))
            }
            for run in paragraph.runs {
                var text = run.text
                if run.isPageBreak { text = "\u{000C}" + text }
                if text.isEmpty { continue }
                result.append(NSAttributedString(string: text, attributes: attributes(for: run, paragraph: paragraph)))
            }
        }
        return result
    }

    static func model(from attributed: NSAttributedString, title: String) -> WriteDocumentModel {
        var paragraphs: [WriteParagraph] = []

        if attributed.length == 0 {
            return WriteDocumentModel(title: title, paragraphs: [WriteParagraph()])
        }

        let string = attributed.string as NSString
        var paragraphStart = 0
        while paragraphStart <= attributed.length {
            let searchRange = NSRange(location: paragraphStart, length: attributed.length - paragraphStart)
            let newline = string.range(of: "\n", options: [], range: searchRange)
            let paragraphEnd = newline.location == NSNotFound ? attributed.length : newline.location
            let paragraphRange = NSRange(location: paragraphStart, length: paragraphEnd - paragraphStart)
            paragraphs.append(paragraph(from: attributed, range: paragraphRange))

            if newline.location == NSNotFound {
                break
            }
            paragraphStart = newline.location + 1
            if paragraphStart == attributed.length {
                paragraphs.append(WriteParagraph())
                break
            }
        }

        return WriteDocumentModel(title: title, paragraphs: paragraphs)
    }

    private static func paragraph(from attributed: NSAttributedString, range: NSRange) -> WriteParagraph {
        let paragraphStyle = paragraphStyle(from: attributed, range: range)
        var runs: [WriteRun] = []
        if range.length > 0 {
            attributed.enumerateAttributes(in: range, options: []) { attrs, runRange, _ in
                let substring = (attributed.string as NSString).substring(with: runRange)
                guard !substring.isEmpty else { return }
                
                let isPageBreak = substring.contains("\u{000C}")
                let cleanedText = substring.replacingOccurrences(of: "\u{000C}", with: "")
                if cleanedText.isEmpty && !isPageBreak { return }
                
                runs.append(
                    WriteRun(
                        text: cleanedText,
                        bold: isBold(attrs),
                        italic: isItalic(attrs),
                        underline: isUnderlined(attrs),
                        fontFamily: fontFamily(attrs),
                        fontSize: fontSize(attrs),
                        textColorHex: colorHex(attrs[.foregroundColor] as? NSColor),
                        highlightColorHex: colorHex(attrs[.backgroundColor] as? NSColor),
                        verticalAlignment: verticalAlignment(attrs),
                        isPageBreak: isPageBreak
                    )
                )
            }
        }

        return WriteParagraph(
            runs: runs,
            alignment: alignment(paragraphStyle.alignment),
            lineSpacing: paragraphStyle.lineSpacing > 0 ? paragraphStyle.lineSpacing : nil,
            spacingBefore: paragraphStyle.paragraphSpacingBefore > 0 ? paragraphStyle.paragraphSpacingBefore : nil,
            spacingAfter: paragraphStyle.paragraphSpacing > 0 ? paragraphStyle.paragraphSpacing : nil,
            leftIndent: paragraphStyle.headIndent > 0 ? paragraphStyle.headIndent : nil,
            firstLineIndent: paragraphStyle.firstLineHeadIndent != 0 ? paragraphStyle.firstLineHeadIndent : nil,
            list: listStyle(paragraphStyle)
        )
    }

    private static func paragraphStyle(from attributed: NSAttributedString, range: NSRange) -> NSParagraphStyle {
        guard attributed.length > 0 else { return NSParagraphStyle.default }
        let location = min(range.location, attributed.length - 1)
        return attributed.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle
            ?? NSParagraphStyle.default
    }

    private static func attributes(for run: WriteRun, paragraph: WriteParagraph) -> [NSAttributedString.Key: Any] {
        let manager = NSFontManager.shared
        let baseFont = NSFont(name: run.fontFamily ?? defaultFont.fontName, size: CGFloat(run.fontSize ?? defaultFontSize)) ?? defaultFont
        var font = baseFont
        if run.bold { font = manager.convert(font, toHaveTrait: .boldFontMask) }
        if run.italic { font = manager.convert(font, toHaveTrait: .italicFontMask) }

        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: nsColor(hex: run.textColorHex) ?? NSColor.labelColor,
            .paragraphStyle: paragraphStyle(for: paragraph),
        ]
        if run.underline {
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if let highlight = nsColor(hex: run.highlightColorHex) {
            attrs[.backgroundColor] = highlight
        }
        switch run.verticalAlignment {
        case .baseline:
            break
        case .superscript:
            attrs[.superscript] = 1
        case .subscripted:
            attrs[.superscript] = -1
        }
        return attrs
    }

    private static func paragraphAttributes(for paragraph: WriteParagraph) -> [NSAttributedString.Key: Any] {
        var attrs = defaultTypingAttributes
        attrs[.paragraphStyle] = paragraphStyle(for: paragraph)
        return attrs
    }

    private static func paragraphStyle(for paragraph: WriteParagraph) -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = nsAlignment(paragraph.alignment)
        if let lineSpacing = paragraph.lineSpacing { style.lineSpacing = lineSpacing }
        if let spacingBefore = paragraph.spacingBefore { style.paragraphSpacingBefore = spacingBefore }
        if let spacingAfter = paragraph.spacingAfter { style.paragraphSpacing = spacingAfter }
        if let leftIndent = paragraph.leftIndent { style.headIndent = leftIndent }
        if let firstLineIndent = paragraph.firstLineIndent { style.firstLineHeadIndent = firstLineIndent }
        if let list = paragraph.list {
            style.textLists = [NSTextList(markerFormat: list.kind == .bullet ? .disc : .decimal, options: 0)]
            if style.headIndent == 0 { style.headIndent = 36 }
            if style.firstLineHeadIndent == 0 { style.firstLineHeadIndent = -18 }
        }
        return style
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

    private static func fontFamily(_ attrs: [NSAttributedString.Key: Any]) -> String? {
        guard let font = attrs[.font] as? NSFont else { return nil }
        return font.familyName
    }

    private static func fontSize(_ attrs: [NSAttributedString.Key: Any]) -> Double? {
        guard let font = attrs[.font] as? NSFont else { return nil }
        return Double(font.pointSize)
    }

    private static func verticalAlignment(_ attrs: [NSAttributedString.Key: Any]) -> WriteVerticalAlignment {
        let raw = attrs[.superscript] as? Int ?? 0
        if raw > 0 { return .superscript }
        if raw < 0 { return .subscripted }
        return .baseline
    }

    private static func alignment(_ alignment: NSTextAlignment) -> WriteParagraphAlignment {
        switch alignment {
        case .center:
            .center
        case .right:
            .right
        case .justified:
            .justified
        default:
            .left
        }
    }

    private static func nsAlignment(_ alignment: WriteParagraphAlignment) -> NSTextAlignment {
        switch alignment {
        case .left:
            .left
        case .center:
            .center
        case .right:
            .right
        case .justified:
            .justified
        }
    }

    private static func listStyle(_ paragraphStyle: NSParagraphStyle) -> WriteListStyle? {
        guard let textList = paragraphStyle.textLists.first else { return nil }
        let format = textList.markerFormat
        let kind: WriteListKind = format == .disc || format == .circle || format == .square ? .bullet : .numbered
        return WriteListStyle(kind: kind)
    }

    private static func colorHex(_ color: NSColor?) -> String? {
        guard
            let color = color?.usingColorSpace(.sRGB),
            color.alphaComponent > 0
        else {
            return nil
        }
        let red = Int((color.redComponent * 255).rounded())
        let green = Int((color.greenComponent * 255).rounded())
        let blue = Int((color.blueComponent * 255).rounded())
        return String(format: "%02X%02X%02X", red, green, blue)
    }

    private static func nsColor(hex: String?) -> NSColor? {
        guard let hex, hex.count == 6, let value = Int(hex, radix: 16) else { return nil }
        let red = CGFloat((value >> 16) & 0xFF) / 255.0
        let green = CGFloat((value >> 8) & 0xFF) / 255.0
        let blue = CGFloat(value & 0xFF) / 255.0
        return NSColor(srgbRed: red, green: green, blue: blue, alpha: 1)
    }
}

private final class RichTextView: NSTextView {
    @objc func toggleHighlight(_ sender: Any?) {
        let range = selectedRange()
        let targetRange = range.length > 0 ? range : NSRange(location: range.location, length: 0)
        let color = NSColor.systemYellow.withAlphaComponent(0.45)
        if targetRange.length > 0 {
            textStorage?.addAttribute(.backgroundColor, value: color, range: targetRange)
            didChangeText()
        } else {
            typingAttributes[.backgroundColor] = color
        }
    }

    @objc func toggleSuperscript(_ sender: Any?) {
        setSuperscript(1)
    }

    @objc func toggleSubscript(_ sender: Any?) {
        setSuperscript(-1)
    }

    @objc func toggleBulletList(_ sender: Any?) {
        applyList(.bullet)
    }

    @objc func toggleNumberedList(_ sender: Any?) {
        applyList(.numbered)
    }

    private func setSuperscript(_ value: Int) {
        let range = selectedRange()
        if range.length > 0 {
            textStorage?.addAttribute(.superscript, value: value, range: range)
            didChangeText()
        } else {
            typingAttributes[.superscript] = value
        }
    }

    private func applyList(_ kind: WriteListKind) {
        guard let storage = textStorage else { return }
        let selected = selectedRange()
        let fullText = storage.string as NSString
        let paragraphRange = fullText.paragraphRange(for: selected.length > 0 ? selected : NSRange(location: selected.location, length: 0))
        storage.beginEditing()
        fullText.enumerateSubstrings(in: paragraphRange, options: [.byParagraphs, .substringNotRequired]) { _, range, _, _ in
            let style = (storage.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
                ?? NSMutableParagraphStyle()
            style.textLists = [NSTextList(markerFormat: kind == .bullet ? .disc : .decimal, options: 0)]
            if style.headIndent == 0 { style.headIndent = 36 }
            if style.firstLineHeadIndent == 0 { style.firstLineHeadIndent = -18 }
            storage.addAttribute(.paragraphStyle, value: style, range: range)
        }
        storage.endEditing()
        didChangeText()
    }
}

private final class PageContainerView: NSView {
    let textView: NSTextView
    let pageSize: NSSize
    let pageGap: CGFloat
    let horizontalPadding: CGFloat = 40
    let verticalPadding: CGFloat = 40

    init(textView: NSTextView, pageSize: NSSize, pageGap: CGFloat) {
        self.textView = textView
        self.pageSize = pageSize
        self.pageGap = pageGap
        super.init(frame: .zero)
        addSubview(textView)
        
        textView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(textViewFrameChanged), name: NSView.frameDidChangeNotification, object: textView)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func textViewFrameChanged() {
        let minWidth = textView.frame.width + horizontalPadding * 2
        let minHeight = textView.frame.height + verticalPadding * 2
        
        let targetWidth = max(minWidth, superview?.frame.width ?? minWidth)
        let targetHeight = max(minHeight, superview?.frame.height ?? minHeight)
        
        if frame.size != NSSize(width: targetWidth, height: targetHeight) {
            setFrameSize(NSSize(width: targetWidth, height: targetHeight))
        }
        needsLayout = true
        needsDisplay = true
    }

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()
        textViewFrameChanged()
    }

    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        textViewFrameChanged()
    }

    override var isFlipped: Bool { true }

    override func layout() {
        super.layout()
        let x = max(horizontalPadding, (bounds.width - textView.frame.width) / 2)
        textView.frame.origin = NSPoint(x: x, y: verticalPadding)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        guard pageSize.height > 0 else { return }
        
        let totalHeight = textView.frame.height
        let pageTotal = pageSize.height + pageGap
        let numPages = max(1, Int(ceil(totalHeight / pageTotal)))
        
        let x = max(horizontalPadding, (bounds.width - pageSize.width) / 2)
        
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.15)
        shadow.shadowOffset = NSSize(width: 0, height: -2)
        shadow.shadowBlurRadius = 4

        for i in 0..<numPages {
            let pageRect = NSRect(
                x: x,
                y: verticalPadding + CGFloat(i) * pageTotal,
                width: pageSize.width,
                height: pageSize.height
            )
            if pageRect.intersects(dirtyRect) {
                NSGraphicsContext.saveGraphicsState()
                shadow.set()
                NSColor.textBackgroundColor.setFill()
                pageRect.fill()
                NSGraphicsContext.restoreGraphicsState()
                
                NSColor.separatorColor.setStroke()
                pageRect.frame(withWidth: 1)
            }
        }
    }
}
