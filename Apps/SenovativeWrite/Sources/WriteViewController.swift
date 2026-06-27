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

    static func model(from attributed: NSAttributedString, title: String) -> WriteDocumentModel {
        if attributed.length == 0 {
            return WriteDocumentModel(title: title, paragraphs: [WriteParagraph()])
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
        return WriteDocumentModel(title: title, blocks: blocks)
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
            .foregroundColor: nsColor(hex: run.textColorHex) ?? NSColor.labelColor,
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

private final class RichTextView: NSTextView {
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
