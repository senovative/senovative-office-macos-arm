import AppKit
import SwiftUI
import UniformTypeIdentifiers
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
                RibbonIconButton("Insert Link", systemImage: "link") {
                    NSApplication.shared.sendAction(#selector(RichTextView.insertHyperlink(_:)), to: nil, from: nil)
                }
                RibbonIconButton("Insert Table", systemImage: "tablecells") {
                    NSApplication.shared.sendAction(#selector(RichTextView.insertTableObject(_:)), to: nil, from: nil)
                }
                RibbonIconButton("Insert Image", systemImage: "photo") {
                    NSApplication.shared.sendAction(#selector(RichTextView.insertImageObject(_:)), to: nil, from: nil)
                }
                RibbonIconButton("Insert Shape", systemImage: "square.on.circle") {
                    NSApplication.shared.sendAction(#selector(RichTextView.insertShapeObject(_:)), to: nil, from: nil)
                }
                Menu {
                    Button("Title") { NSApplication.shared.sendAction(#selector(RichTextView.applyTitleStyle(_:)), to: nil, from: nil) }
                    Button("Heading 1") { NSApplication.shared.sendAction(#selector(RichTextView.applyHeading1Style(_:)), to: nil, from: nil) }
                    Button("Heading 2") { NSApplication.shared.sendAction(#selector(RichTextView.applyHeading2Style(_:)), to: nil, from: nil) }
                    Button("Body") { NSApplication.shared.sendAction(#selector(RichTextView.applyBodyStyle(_:)), to: nil, from: nil) }
                    Button("Quote") { NSApplication.shared.sendAction(#selector(RichTextView.applyQuoteStyle(_:)), to: nil, from: nil) }
                } label: {
                    Label("Styles", systemImage: "textformat.size")
                        .labelStyle(.iconOnly)
                }
                .menuStyle(.borderlessButton)
                .help("Styles")
                Menu {
                    Button("Blank Document") { NSApplication.shared.sendAction(#selector(RichTextView.applyBlankTemplate(_:)), to: nil, from: nil) }
                    Button("Business Letter") { NSApplication.shared.sendAction(#selector(RichTextView.applyBusinessLetterTemplate(_:)), to: nil, from: nil) }
                    Button("Report") { NSApplication.shared.sendAction(#selector(RichTextView.applyReportTemplate(_:)), to: nil, from: nil) }
                    Button("Meeting Notes") { NSApplication.shared.sendAction(#selector(RichTextView.applyMeetingNotesTemplate(_:)), to: nil, from: nil) }
                } label: {
                    Label("Templates", systemImage: "doc.on.doc")
                        .labelStyle(.iconOnly)
                }
                .menuStyle(.borderlessButton)
                .help("Templates")
                RibbonIconButton("Find", systemImage: "magnifyingglass") {
                    NSApplication.shared.sendAction(#selector(RichTextView.showFindReplacePanel(_:)), to: nil, from: nil)
                }
                RibbonIconButton("Export PDF", systemImage: "doc.richtext") {
                    NSApplication.shared.sendAction(#selector(RichTextView.exportPDF(_:)), to: nil, from: nil)
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
        let stats = state.model.statistics
        return HStack {
            StatusPill(LocalizedStringKey(state.statusText))
            Spacer()
            Text("\(stats.wordCount) words • \(stats.characterCount) chars")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
                .frame(height: 14)
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
        textView.isContinuousSpellCheckingEnabled = true
        textView.isGrammarCheckingEnabled = true
        textView.isAutomaticSpellingCorrectionEnabled = true
        textView.usesAdaptiveColorMappingForDarkAppearance = false
        textView.drawsBackground = true
        textView.backgroundColor = .white
        textView.textColor = .black
        textView.insertionPointColor = .black
        textView.font = WriteAttributedStringBridge.defaultFont
        textView.delegate = context.coordinator

        let pageSize = state.model.section.pageSize
        let margins = state.model.section.margins
        let pageGap: CGFloat = 40

        textView.textContainerInset = .zero

        let textWidth = pageSize.width - margins.left - margins.right
        textView.minSize = NSSize(width: textWidth, height: pageSize.height)
        textView.maxSize = NSSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.frame = NSRect(x: 0, y: 0, width: textWidth, height: pageSize.height)
        textView.textContainer?.size = NSSize(width: textWidth, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true

        // Transparent background, PageContainerView will draw the pages
        textView.drawsBackground = false
        textView.backgroundColor = .clear

        // Add exclusion paths for gaps between pages (including top and bottom margins)
        var paths: [NSBezierPath] = []
        for i in 1...500 {
            let gapY = CGFloat(i) * pageSize.height + CGFloat(i - 1) * pageGap - margins.bottom - margins.top
            let gapHeight = margins.bottom + pageGap + margins.top
            let gapRect = NSRect(x: 0, y: gapY, width: textWidth, height: gapHeight)
            paths.append(NSBezierPath(rect: gapRect))
        }
        textView.textContainer?.exclusionPaths = paths

        let nsPageSize = NSSize(width: pageSize.width, height: pageSize.height)
        let containerView = PageContainerView(textView: textView, pageSize: nsPageSize, margins: margins, pageGap: pageGap)
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
            let model = WriteAttributedStringBridge.model(from: storage, previousModel: state.model)
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
        [.font: defaultFont, .foregroundColor: NSColor.black]
    }

    static func attributedString(from model: WriteDocumentModel) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for block in model.blocks {
            switch block {
            case let .paragraph(paragraph):
                appendParagraph(paragraph, tableBlock: nil, into: result)
            case let .table(table):
                appendTable(table, into: result)
            }
        }
        // Drop the trailing newline contributed by the final paragraph so the
        // text view does not show a spurious empty line.
        if result.length > 0 {
            result.deleteCharacters(in: NSRange(location: result.length - 1, length: 1))
        }
        return result
    }

    /// Builds a standalone table fragment (used by "Insert Table").
    static func tableAttributedString(_ table: WriteTable) -> NSAttributedString {
        let result = NSMutableAttributedString()
        appendTable(table, into: result)
        return result
    }

    private static func appendParagraph(_ paragraph: WriteParagraph, tableBlock: NSTextTableBlock?, into result: NSMutableAttributedString) {
        let style = paragraphStyle(for: paragraph, tableBlock: tableBlock)
        for run in paragraph.runs {
            if let attachment = attachment(for: run) {
                let attr = NSMutableAttributedString(attributedString: NSAttributedString(attachment: attachment))
                attr.addAttributes([.paragraphStyle: style], range: NSRange(location: 0, length: attr.length))
                result.append(attr)
                continue
            }
            var text = run.text
            if run.isPageBreak { text = "\u{000C}" + text }
            if text.isEmpty { continue }
            var attrs = attributes(for: run)
            attrs[.paragraphStyle] = style
            result.append(NSAttributedString(string: text, attributes: attrs))
        }
        // The trailing newline terminates the paragraph and carries its style
        // (including table membership), so TextKit keeps cells grouped.
        var newlineAttrs = defaultTypingAttributes
        newlineAttrs[.paragraphStyle] = style
        result.append(NSAttributedString(string: "\n", attributes: newlineAttrs))
    }

    private static func appendTable(_ table: WriteTable, into result: NSMutableAttributedString) {
        let columns = max(1, table.columnCount)
        let nsTable = NSTextTable()
        nsTable.numberOfColumns = columns
        for (rowIndex, row) in table.rows.enumerated() {
            for (columnIndex, cell) in row.cells.enumerated() {
                let block = NSTextTableBlock(
                    table: nsTable,
                    startingRow: rowIndex,
                    rowSpan: 1,
                    startingColumn: columnIndex,
                    columnSpan: 1
                )
                block.setBorderColor(.separatorColor)
                block.setWidth(1, type: .absoluteValueType, for: .border)
                block.setWidth(4, type: .absoluteValueType, for: .padding)
                for paragraph in cell.paragraphs {
                    appendParagraph(paragraph, tableBlock: block, into: result)
                }
            }
        }
    }

    static func model(from attributed: NSAttributedString, previousModel: WriteDocumentModel) -> WriteDocumentModel {
        if attributed.length == 0 {
            return WriteDocumentModel(
                title: previousModel.title,
                paragraphs: [WriteParagraph()],
                section: previousModel.section,
                sourcePackage: previousModel.sourcePackage
            )
        }

        // 1. Split into paragraph entries, capturing table membership.
        let string = attributed.string as NSString
        var entries: [(paragraph: WriteParagraph, block: NSTextTableBlock?)] = []
        var start = 0
        while start <= attributed.length {
            let searchRange = NSRange(location: start, length: attributed.length - start)
            let newline = string.range(of: "\n", options: [], range: searchRange)
            let end = newline.location == NSNotFound ? attributed.length : newline.location
            let range = NSRange(location: start, length: end - start)
            let style = paragraphStyle(from: attributed, range: range, fallbackLocation: end)
            entries.append((paragraph(from: attributed, range: range, style: style), tableBlock(in: style)))

            if newline.location == NSNotFound { break }
            start = newline.location + 1
            if start == attributed.length {
                entries.append((WriteParagraph(), nil))
                break
            }
        }

        // 2. Group consecutive table-cell paragraphs back into tables.
        var blocks: [WriteBlock] = []
        var accumulator: WriteTableAccumulator?
        func flush() {
            if let accumulator { blocks.append(.table(accumulator.build())) }
            accumulator = nil
        }
        for entry in entries {
            if let block = entry.block {
                if accumulator == nil || accumulator?.table !== block.table {
                    flush()
                    accumulator = WriteTableAccumulator(table: block.table)
                }
                accumulator?.add(entry.paragraph, block: block)
            } else {
                flush()
                blocks.append(.paragraph(entry.paragraph))
            }
        }
        flush()

        if blocks.isEmpty { blocks = [.paragraph(WriteParagraph())] }
        return WriteDocumentModel(
            title: previousModel.title,
            blocks: blocks,
            section: previousModel.section,
            sourcePackage: previousModel.sourcePackage
        )
    }

    private static func tableBlock(in style: NSParagraphStyle) -> NSTextTableBlock? {
        style.textBlocks.compactMap { $0 as? NSTextTableBlock }.first
    }

    private static func paragraph(from attributed: NSAttributedString, range: NSRange, style paragraphStyle: NSParagraphStyle) -> WriteParagraph {
        var runs: [WriteRun] = []
        if range.length > 0 {
            attributed.enumerateAttributes(in: range, options: []) { attrs, runRange, _ in
                if let attachment = attrs[.attachment] as? NSTextAttachment {
                    if let imageAttachment = attachment as? WriteImageAttachment {
                        runs.append(WriteRun(text: "", image: imageAttachment.writeImage))
                    } else if let shapeAttachment = attachment as? WriteShapeAttachment {
                        runs.append(WriteRun(text: "", shape: shapeAttachment.writeShape))
                    }
                    return
                }

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
                        isPageBreak: isPageBreak,
                        linkURL: linkURL(attrs)
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

    private static func paragraphStyle(from attributed: NSAttributedString, range: NSRange, fallbackLocation: Int) -> NSParagraphStyle {
        guard attributed.length > 0 else { return NSParagraphStyle.default }
        // For empty paragraphs read the terminating newline's style; otherwise
        // read the paragraph's first character.
        let location = range.length > 0 ? range.location : min(fallbackLocation, attributed.length - 1)
        return attributed.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle
            ?? NSParagraphStyle.default
    }

    private static func attributes(for run: WriteRun) -> [NSAttributedString.Key: Any] {
        let manager = NSFontManager.shared
        let baseFont = NSFont(name: run.fontFamily ?? defaultFont.fontName, size: CGFloat(run.fontSize ?? defaultFontSize)) ?? defaultFont
        var font = baseFont
        if run.bold { font = manager.convert(font, toHaveTrait: .boldFontMask) }
        if run.italic { font = manager.convert(font, toHaveTrait: .italicFontMask) }

        var attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: nsColor(hex: run.textColorHex) ?? NSColor.black,
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
        if let link = run.linkURL {
            attrs[.link] = URL(string: link) ?? link
            attrs[.foregroundColor] = NSColor.linkColor
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        return attrs
    }

    private static func paragraphStyle(for paragraph: WriteParagraph, tableBlock: NSTextTableBlock? = nil) -> NSParagraphStyle {
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
        if let tableBlock { style.textBlocks = [tableBlock] }
        return style
    }

    private static func linkURL(_ attrs: [NSAttributedString.Key: Any]) -> String? {
        if let url = attrs[.link] as? URL { return url.absoluteString }
        if let string = attrs[.link] as? String, !string.isEmpty { return string }
        return nil
    }

    private static func attachment(for run: WriteRun) -> NSTextAttachment? {
        if let image = run.image { return WriteImageAttachment(writeImage: image) }
        if let shape = run.shape { return WriteShapeAttachment(writeShape: shape) }
        return nil
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

/// Regroups consecutive table-cell paragraphs (keyed by their `NSTextTableBlock`
/// position) back into a `WriteTable` during model reconstruction.
private final class WriteTableAccumulator {
    let table: NSTextTable
    private var grid: [String: [WriteParagraph]] = [:]
    private var maxRow = -1
    private var maxColumn = -1

    init(table: NSTextTable) {
        self.table = table
    }

    func add(_ paragraph: WriteParagraph, block: NSTextTableBlock) {
        let key = "\(block.startingRow)-\(block.startingColumn)"
        grid[key, default: []].append(paragraph)
        maxRow = max(maxRow, block.startingRow)
        maxColumn = max(maxColumn, block.startingColumn)
    }

    func build() -> WriteTable {
        guard maxRow >= 0, maxColumn >= 0 else { return WriteTable(rows: []) }
        var rows: [WriteTableRow] = []
        for row in 0...maxRow {
            var cells: [WriteTableCell] = []
            for column in 0...maxColumn {
                let paragraphs = grid["\(row)-\(column)"] ?? [WriteParagraph()]
                cells.append(WriteTableCell(paragraphs: paragraphs))
            }
            rows.append(WriteTableRow(cells: cells))
        }
        return WriteTable(rows: rows)
    }
}

/// An `NSTextAttachment` that carries the original `WriteImage` so the exact
/// bytes survive an editing session (rather than being re-encoded).
private final class WriteImageAttachment: NSTextAttachment {
    let writeImage: WriteImage

    init(writeImage: WriteImage) {
        self.writeImage = writeImage
        super.init(data: nil, ofType: nil)
        image = NSImage(data: writeImage.data)
        bounds = CGRect(x: 0, y: 0, width: writeImage.width, height: writeImage.height)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}

/// An `NSTextAttachment` that draws a basic shape and carries its `WriteShape`.
private final class WriteShapeAttachment: NSTextAttachment {
    let writeShape: WriteShape

    init(writeShape: WriteShape) {
        self.writeShape = writeShape
        super.init(data: nil, ofType: nil)
        image = WriteShapeAttachment.render(writeShape)
        bounds = CGRect(x: 0, y: 0, width: writeShape.width, height: writeShape.height)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private static func render(_ shape: WriteShape) -> NSImage {
        let size = NSSize(width: max(1, shape.width), height: max(1, shape.height))
        let image = NSImage(size: size)
        image.lockFocus()
        let rect = NSRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
        let path = shape.kind == .oval ? NSBezierPath(ovalIn: rect) : NSBezierPath(rect: rect)
        let fill = color(hex: shape.fillColorHex) ?? NSColor.systemBlue.withAlphaComponent(0.3)
        fill.setFill()
        path.fill()
        NSColor.separatorColor.setStroke()
        path.lineWidth = 1
        path.stroke()
        image.unlockFocus()
        return image
    }

    private static func color(hex: String?) -> NSColor? {
        guard let hex, hex.count == 6, let value = Int(hex, radix: 16) else { return nil }
        return NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255.0,
            green: CGFloat((value >> 8) & 0xFF) / 255.0,
            blue: CGFloat(value & 0xFF) / 255.0,
            alpha: 1
        )
    }
}

final class RichTextView: NSTextView {
    fileprivate var currentFindString = ""
    fileprivate var currentReplaceString = ""
    private var findReplaceController: FindReplacePanelController?

    @objc func showFindReplacePanel(_ sender: Any?) {
        if currentFindString.isEmpty, selectedRange().length > 0 {
            currentFindString = selectedString() ?? ""
        }
        if findReplaceController == nil {
            findReplaceController = FindReplacePanelController(textView: self)
        }
        findReplaceController?.refreshFields()
        findReplaceController?.showWindow(sender)
        findReplaceController?.window?.makeKeyAndOrderFront(sender)
    }

    @objc func findNext(_ sender: Any?) {
        guard ensureFindString(sender) else { return }
        selectMatch(for: currentFindString, backwards: false)
    }

    @objc func findPrevious(_ sender: Any?) {
        guard ensureFindString(sender) else { return }
        selectMatch(for: currentFindString, backwards: true)
    }

    @objc func replaceSelectionOrNext(_ sender: Any?) {
        guard ensureFindString(sender) else { return }
        let targetRange: NSRange
        if selectedRangeMatches(currentFindString) {
            targetRange = selectedRange()
        } else if let found = selectMatch(for: currentFindString, backwards: false) {
            targetRange = found
        } else {
            return
        }
        replace(range: targetRange, with: currentReplaceString)
    }

    @objc func replaceAllMatches(_ sender: Any?) {
        guard ensureFindString(sender), let storage = textStorage else { return }
        let text = storage.string as NSString
        var matches: [NSRange] = []
        var cursor = 0
        while cursor < text.length {
            let range = NSRange(location: cursor, length: text.length - cursor)
            let found = text.range(of: currentFindString, options: [.caseInsensitive], range: range)
            if found.location == NSNotFound { break }
            matches.append(found)
            cursor = max(found.location + found.length, cursor + 1)
        }
        guard !matches.isEmpty else {
            NSSound.beep()
            return
        }

        let fullRange = NSRange(location: 0, length: text.length)
        guard shouldChangeText(in: fullRange, replacementString: nil) else { return }
        storage.beginEditing()
        for match in matches.reversed() {
            storage.replaceCharacters(in: match, with: currentReplaceString)
        }
        storage.endEditing()
        setSelectedRange(NSRange(location: 0, length: 0))
        didChangeText()
    }

    @objc func exportPDF(_ sender: Any?) {
        guard let sourceView = pdfSourceView else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        let baseName = window?.representedURL?.deletingPathExtension().lastPathComponent
            ?? String(localized: "Untitled")
        panel.nameFieldStringValue = "\(baseName).pdf"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        sourceView.layoutSubtreeIfNeeded()
        let pdfData = sourceView.dataWithPDF(inside: sourceView.bounds)
        do {
            try pdfData.write(to: url, options: .atomic)
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = String(localized: "Could not export PDF")
            alert.runModal()
        }
    }

    @objc func printDocumentView(_ sender: Any?) {
        guard let sourceView = pdfSourceView else { return }
        sourceView.layoutSubtreeIfNeeded()
        NSPrintOperation(view: sourceView).run()
    }

    @objc func applyTitleStyle(_ sender: Any?) {
        applyNamedStyle(.title)
    }

    @objc func applyHeading1Style(_ sender: Any?) {
        applyNamedStyle(.heading1)
    }

    @objc func applyHeading2Style(_ sender: Any?) {
        applyNamedStyle(.heading2)
    }

    @objc func applyBodyStyle(_ sender: Any?) {
        applyNamedStyle(.body)
    }

    @objc func applyQuoteStyle(_ sender: Any?) {
        applyNamedStyle(.quote)
    }

    @objc func applyBlankTemplate(_ sender: Any?) {
        applyTemplate(.blank)
    }

    @objc func applyBusinessLetterTemplate(_ sender: Any?) {
        applyTemplate(.businessLetter)
    }

    @objc func applyReportTemplate(_ sender: Any?) {
        applyTemplate(.report)
    }

    @objc func applyMeetingNotesTemplate(_ sender: Any?) {
        applyTemplate(.meetingNotes)
    }

    @objc func insertImageObject(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.png, .jpeg, .gif, .bmp, .tiff]
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url), let nsImage = NSImage(data: data) else { return }

        let maxWidth: CGFloat = 400
        var size = nsImage.size
        if size.width <= 0 || size.height <= 0 { size = NSSize(width: 200, height: 150) }
        if size.width > maxWidth {
            size = NSSize(width: maxWidth, height: size.height * (maxWidth / size.width))
        }
        let ext = url.pathExtension.isEmpty ? "png" : url.pathExtension
        let image = WriteImage(data: data, fileExtension: ext, width: Double(size.width), height: Double(size.height))
        insertAttachment(WriteImageAttachment(writeImage: image))
    }

    @objc func insertShapeObject(_ sender: Any?) {
        let shape = WriteShape(kind: .rectangle, width: 120, height: 80, fillColorHex: "4A90D9")
        insertAttachment(WriteShapeAttachment(writeShape: shape))
    }

    private func insertAttachment(_ attachment: NSTextAttachment) {
        guard let storage = textStorage else { return }
        let fragment = NSMutableAttributedString(attributedString: NSAttributedString(attachment: attachment))
        fragment.addAttributes([.font: NSFont.systemFont(ofSize: 15)], range: NSRange(location: 0, length: fragment.length))
        let range = selectedRange()
        guard shouldChangeText(in: range, replacementString: fragment.string) else { return }
        storage.replaceCharacters(in: range, with: fragment)
        didChangeText()
    }

    @objc func insertHyperlink(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = String(localized: "Insert Link")
        alert.informativeText = String(localized: "Enter the destination URL")
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        field.placeholderString = "https://"
        alert.accessoryView = field
        alert.addButton(withTitle: String(localized: "Insert"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let urlString = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty, let storage = textStorage else { return }

        let range = selectedRange()
        if range.length > 0 {
            guard shouldChangeText(in: range, replacementString: nil) else { return }
            storage.addAttribute(.link, value: URL(string: urlString) ?? urlString, range: range)
            storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            storage.addAttribute(.foregroundColor, value: NSColor.linkColor, range: range)
            didChangeText()
        } else {
            let attrs: [NSAttributedString.Key: Any] = [
                .link: URL(string: urlString) ?? urlString,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: NSColor.linkColor,
                .font: NSFont.systemFont(ofSize: 15),
            ]
            let link = NSAttributedString(string: urlString, attributes: attrs)
            guard shouldChangeText(in: range, replacementString: link.string) else { return }
            storage.replaceCharacters(in: range, with: link)
            didChangeText()
        }
    }

    @objc func insertTableObject(_ sender: Any?) {
        let cells = (0..<2).map { _ in WriteTableCell() }
        let rows = (0..<2).map { _ in WriteTableRow(cells: cells) }
        let table = WriteTable(rows: rows)
        let fragment = WriteAttributedStringBridge.tableAttributedString(table)
        guard let storage = textStorage else { return }
        let range = selectedRange()
        guard shouldChangeText(in: range, replacementString: fragment.string) else { return }
        storage.replaceCharacters(in: range, with: fragment)
        didChangeText()
    }

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

    private func applyNamedStyle(_ style: WriteNamedStyle) {
        guard let storage = textStorage else { return }
        let selected = selectedRange()
        let text = storage.string as NSString
        let targetRange = text.paragraphRange(for: selected.length > 0 ? selected : NSRange(location: min(selected.location, storage.length), length: 0))
        guard targetRange.length > 0 else { return }
        guard shouldChangeText(in: targetRange, replacementString: nil) else { return }

        storage.beginEditing()
        applyCharacterStyle(style, range: targetRange, storage: storage)
        text.enumerateSubstrings(in: targetRange, options: [.byParagraphs, .substringNotRequired]) { _, range, _, _ in
            self.applyParagraphStyle(style, range: range, storage: storage)
        }
        storage.endEditing()
        didChangeText()
    }

    private func applyCharacterStyle(_ style: WriteNamedStyle, range: NSRange, storage: NSTextStorage) {
        let spec = characterStyleSpec(style)
        var fontRuns: [(NSFont, NSRange)] = []
        storage.enumerateAttribute(.font, in: range, options: []) { value, runRange, _ in
            let baseFont = value as? NSFont ?? WriteAttributedStringBridge.defaultFont
            var font = NSFontManager.shared.convert(baseFont, toSize: spec.size ?? baseFont.pointSize)
            if spec.bold { font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask) }
            if !spec.bold { font = NSFontManager.shared.convert(font, toNotHaveTrait: .boldFontMask) }
            if spec.italic { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
            if !spec.italic { font = NSFontManager.shared.convert(font, toNotHaveTrait: .italicFontMask) }
            fontRuns.append((font, runRange))
        }
        for (font, runRange) in fontRuns {
            storage.addAttribute(.font, value: font, range: runRange)
        }

        storage.removeAttribute(.underlineStyle, range: range)
        storage.removeAttribute(.backgroundColor, range: range)
        storage.removeAttribute(.superscript, range: range)
        if let color = spec.color {
            storage.addAttribute(.foregroundColor, value: color, range: range)
        } else {
            storage.addAttribute(.foregroundColor, value: NSColor.black, range: range)
        }
    }

    private func applyParagraphStyle(_ style: WriteNamedStyle, range: NSRange, storage: NSTextStorage) {
        guard range.location < storage.length else { return }
        let currentStyle = (storage.attribute(.paragraphStyle, at: range.location, effectiveRange: nil) as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle
            ?? NSMutableParagraphStyle()

        let tableBlocks = currentStyle.textBlocks
        currentStyle.textLists = []
        switch style {
        case .title:
            currentStyle.alignment = .center
            currentStyle.paragraphSpacingBefore = 0
            currentStyle.paragraphSpacing = 18
            currentStyle.headIndent = 0
            currentStyle.firstLineHeadIndent = 0
        case .heading1:
            currentStyle.alignment = .left
            currentStyle.paragraphSpacingBefore = 18
            currentStyle.paragraphSpacing = 8
            currentStyle.headIndent = 0
            currentStyle.firstLineHeadIndent = 0
        case .heading2:
            currentStyle.alignment = .left
            currentStyle.paragraphSpacingBefore = 14
            currentStyle.paragraphSpacing = 6
            currentStyle.headIndent = 0
            currentStyle.firstLineHeadIndent = 0
        case .body:
            currentStyle.alignment = .left
            currentStyle.lineSpacing = 0
            currentStyle.paragraphSpacingBefore = 0
            currentStyle.paragraphSpacing = 8
            currentStyle.headIndent = 0
            currentStyle.firstLineHeadIndent = 0
        case .quote:
            currentStyle.alignment = .left
            currentStyle.paragraphSpacingBefore = 8
            currentStyle.paragraphSpacing = 8
            currentStyle.headIndent = 36
            currentStyle.firstLineHeadIndent = 0
        }
        currentStyle.textBlocks = tableBlocks
        storage.addAttribute(.paragraphStyle, value: currentStyle, range: range)
    }

    private func characterStyleSpec(_ style: WriteNamedStyle) -> (size: CGFloat?, bold: Bool, italic: Bool, color: NSColor?) {
        let titleBlue = NSColor(srgbRed: 0x17/255.0, green: 0x36/255.0, blue: 0x5D/255.0, alpha: 1.0)
        let headingBlue = NSColor(srgbRed: 0x36/255.0, green: 0x5F/255.0, blue: 0x91/255.0, alpha: 1.0)
        switch style {
        case .title:
            return (28, true, false, titleBlue)
        case .heading1:
            return (22, true, false, headingBlue)
        case .heading2:
            return (17, true, false, headingBlue)
        case .body:
            return (15, false, false, nil)
        case .quote:
            return (15, false, true, NSColor.darkGray)
        }
    }

    private func applyTemplate(_ template: WriteDocumentTemplate) {
        guard let storage = textStorage else { return }
        let fullRange = NSRange(location: 0, length: storage.length)
        let attributed = WriteAttributedStringBridge.attributedString(from: template.model)
        guard shouldChangeText(in: fullRange, replacementString: attributed.string) else { return }
        storage.setAttributedString(attributed)
        setSelectedRange(NSRange(location: 0, length: 0))
        didChangeText()
    }

    private var pdfSourceView: NSView? {
        var view: NSView? = self
        while let current = view {
            if current is PageContainerView { return current }
            view = current.superview
        }
        return self
    }

    private func ensureFindString(_ sender: Any?) -> Bool {
        if currentFindString.isEmpty {
            showFindReplacePanel(sender)
            return false
        }
        return true
    }

    @discardableResult
    private func selectMatch(for query: String, backwards: Bool) -> NSRange? {
        guard !query.isEmpty, let storage = textStorage else { return nil }
        let text = storage.string as NSString
        guard text.length > 0 else { return nil }

        let selected = selectedRange()
        let found: NSRange
        if backwards {
            let end = min(selected.location, text.length)
            found = find(query, in: text, range: NSRange(location: 0, length: end), backwards: true)
                ?? find(query, in: text, range: NSRange(location: 0, length: text.length), backwards: true)
                ?? NSRange(location: NSNotFound, length: 0)
        } else {
            let start = min(selected.location + selected.length, text.length)
            found = find(query, in: text, range: NSRange(location: start, length: text.length - start), backwards: false)
                ?? find(query, in: text, range: NSRange(location: 0, length: start), backwards: false)
                ?? NSRange(location: NSNotFound, length: 0)
        }

        guard found.location != NSNotFound else {
            NSSound.beep()
            return nil
        }
        setSelectedRange(found)
        scrollRangeToVisible(found)
        return found
    }

    private func find(_ query: String, in text: NSString, range: NSRange, backwards: Bool) -> NSRange? {
        guard range.length > 0 else { return nil }
        var options: NSString.CompareOptions = [.caseInsensitive]
        if backwards { options.insert(.backwards) }
        let found = text.range(of: query, options: options, range: range)
        return found.location == NSNotFound ? nil : found
    }

    private func selectedRangeMatches(_ query: String) -> Bool {
        guard let selected = selectedString(), !query.isEmpty else { return false }
        return selected.range(of: query, options: [.caseInsensitive]) != nil && selected.count == query.count
    }

    private func selectedString() -> String? {
        guard let storage = textStorage else { return nil }
        let range = selectedRange()
        guard range.length > 0, NSMaxRange(range) <= storage.length else { return nil }
        return (storage.string as NSString).substring(with: range)
    }

    @discardableResult
    private func replace(range: NSRange, with replacement: String) -> Bool {
        guard let storage = textStorage else { return false }
        guard shouldChangeText(in: range, replacementString: replacement) else { return false }
        storage.replaceCharacters(in: range, with: replacement)
        setSelectedRange(NSRange(location: range.location, length: (replacement as NSString).length))
        didChangeText()
        return true
    }
}

private final class FindReplacePanelController: NSWindowController {
    private weak var textView: RichTextView?
    private let findField = NSTextField(frame: NSRect(x: 92, y: 106, width: 280, height: 24))
    private let replaceField = NSTextField(frame: NSRect(x: 92, y: 70, width: 280, height: 24))

    init(textView: RichTextView) {
        self.textView = textView
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 150),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = String(localized: "Find & Replace")
        panel.isReleasedWhenClosed = false

        let content = NSView(frame: panel.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 460, height: 150))
        panel.contentView = content

        let findLabel = NSTextField(labelWithString: String(localized: "Find"))
        findLabel.frame = NSRect(x: 20, y: 109, width: 60, height: 18)
        content.addSubview(findLabel)
        content.addSubview(findField)

        let replaceLabel = NSTextField(labelWithString: String(localized: "Replace"))
        replaceLabel.frame = NSRect(x: 20, y: 73, width: 66, height: 18)
        content.addSubview(replaceLabel)
        content.addSubview(replaceField)

        super.init(window: panel)

        addButton(String(localized: "Next"), frame: NSRect(x: 384, y: 104, width: 60, height: 28), action: #selector(next(_:)), to: content)
        addButton(String(localized: "Previous"), frame: NSRect(x: 384, y: 70, width: 60, height: 28), action: #selector(previous(_:)), to: content)
        addButton(String(localized: "Replace"), frame: NSRect(x: 192, y: 24, width: 84, height: 28), action: #selector(replace(_:)), to: content)
        addButton(String(localized: "Replace All"), frame: NSRect(x: 288, y: 24, width: 96, height: 28), action: #selector(replaceAll(_:)), to: content)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func refreshFields() {
        findField.stringValue = textView?.currentFindString ?? ""
        replaceField.stringValue = textView?.currentReplaceString ?? ""
    }

    private func syncFields() {
        textView?.currentFindString = findField.stringValue
        textView?.currentReplaceString = replaceField.stringValue
    }

    private func addButton(_ title: String, frame: NSRect, action: Selector, to content: NSView) {
        let button = NSButton(frame: frame)
        button.title = title
        button.bezelStyle = .rounded
        button.target = self
        button.action = action
        content.addSubview(button)
    }

    @objc private func next(_ sender: Any?) {
        syncFields()
        textView?.findNext(sender)
    }

    @objc private func previous(_ sender: Any?) {
        syncFields()
        textView?.findPrevious(sender)
    }

    @objc private func replace(_ sender: Any?) {
        syncFields()
        textView?.replaceSelectionOrNext(sender)
    }

    @objc private func replaceAll(_ sender: Any?) {
        syncFields()
        textView?.replaceAllMatches(sender)
    }
}

private final class PageContainerView: NSView {
    let textView: NSTextView
    let pageSize: NSSize
    let margins: WriteEdgeInsets
    let pageGap: CGFloat
    let horizontalPadding: CGFloat = 40
    let verticalPadding: CGFloat = 40

    init(textView: NSTextView, pageSize: NSSize, margins: WriteEdgeInsets, pageGap: CGFloat) {
        self.textView = textView
        self.pageSize = pageSize
        self.margins = margins
        self.pageGap = pageGap
        super.init(frame: .zero)
        addSubview(textView)
        
        textView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(textViewFrameChanged), name: NSView.frameDidChangeNotification, object: textView)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func textViewFrameChanged() {
        let minWidth = pageSize.width + horizontalPadding * 2
        let minHeight = textView.frame.maxY + verticalPadding + CGFloat(margins.bottom)
        
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
        let pageX = max(horizontalPadding, (bounds.width - pageSize.width) / 2)
        textView.frame.origin = NSPoint(x: pageX + CGFloat(margins.left), y: verticalPadding + CGFloat(margins.top))
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
                NSColor.white.setFill()
                pageRect.fill()
                NSGraphicsContext.restoreGraphicsState()
                
                NSColor.separatorColor.setStroke()
                pageRect.frame(withWidth: 1)
            }
        }
    }
}
