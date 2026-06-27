import Foundation

/// A contiguous span of text sharing the same character formatting.
///
/// Maps to a WordprocessingML run (`<w:r>`): the optional `<w:rPr>` carries the
/// bold/italic/underline toggles, and `<w:t>` carries the literal text.
public struct WriteRun: Equatable, Sendable {
    public var text: String
    public var bold: Bool
    public var italic: Bool
    public var underline: Bool
    public var fontFamily: String?
    public var fontSize: Double?
    public var textColorHex: String?
    public var highlightColorHex: String?
    public var verticalAlignment: WriteVerticalAlignment
    public var isPageBreak: Bool
    /// External hyperlink target. When set, the run is wrapped in `<w:hyperlink>`.
    public var linkURL: String?
    /// Inline picture carried by this run (`<w:drawing>` + `a:blip`).
    public var image: WriteImage?
    /// Inline basic shape carried by this run (`<w:drawing>` + `wps:wsp`).
    public var shape: WriteShape?

    public init(
        text: String,
        bold: Bool = false,
        italic: Bool = false,
        underline: Bool = false,
        fontFamily: String? = nil,
        fontSize: Double? = nil,
        textColorHex: String? = nil,
        highlightColorHex: String? = nil,
        verticalAlignment: WriteVerticalAlignment = .baseline,
        isPageBreak: Bool = false,
        linkURL: String? = nil,
        image: WriteImage? = nil,
        shape: WriteShape? = nil
    ) {
        self.text = text
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.fontFamily = fontFamily
        self.fontSize = fontSize
        self.textColorHex = textColorHex
        self.highlightColorHex = highlightColorHex
        self.verticalAlignment = verticalAlignment
        self.isPageBreak = isPageBreak
        self.linkURL = linkURL
        self.image = image
        self.shape = shape
    }
}

/// An inline picture: the raw bytes, a file extension, and its display size in points.
public struct WriteImage: Equatable, Sendable {
    public var data: Data
    public var fileExtension: String
    public var width: Double
    public var height: Double

    public init(data: Data, fileExtension: String, width: Double, height: Double) {
        self.data = data
        self.fileExtension = fileExtension.lowercased()
        self.width = width
        self.height = height
    }
}

public enum WriteShapeKind: String, Equatable, Sendable {
    case rectangle
    case oval
}

/// A basic inline shape: a rectangle or oval with a size and optional fill color.
public struct WriteShape: Equatable, Sendable {
    public var kind: WriteShapeKind
    public var width: Double
    public var height: Double
    public var fillColorHex: String?

    public init(kind: WriteShapeKind, width: Double, height: Double, fillColorHex: String? = nil) {
        self.kind = kind
        self.width = width
        self.height = height
        self.fillColorHex = fillColorHex
    }
}

public enum WriteVerticalAlignment: String, Equatable, Sendable {
    case baseline
    case superscript
    case subscripted = "subscript"
}

/// A paragraph: an ordered list of runs. Maps to `<w:p>`.
public struct WriteParagraph: Equatable, Sendable {
    public var runs: [WriteRun]
    public var alignment: WriteParagraphAlignment
    public var lineSpacing: Double?
    public var spacingBefore: Double?
    public var spacingAfter: Double?
    public var leftIndent: Double?
    public var firstLineIndent: Double?
    public var list: WriteListStyle?
    public var pageBreakBefore: Bool

    public init(
        runs: [WriteRun] = [],
        alignment: WriteParagraphAlignment = .left,
        lineSpacing: Double? = nil,
        spacingBefore: Double? = nil,
        spacingAfter: Double? = nil,
        leftIndent: Double? = nil,
        firstLineIndent: Double? = nil,
        list: WriteListStyle? = nil,
        pageBreakBefore: Bool = false
    ) {
        self.runs = runs
        self.alignment = alignment
        self.lineSpacing = lineSpacing
        self.spacingBefore = spacingBefore
        self.spacingAfter = spacingAfter
        self.leftIndent = leftIndent
        self.firstLineIndent = firstLineIndent
        self.list = list
        self.pageBreakBefore = pageBreakBefore
    }

    /// Plain text of the paragraph with formatting flattened away.
    public var plainText: String {
        runs.map(\.text).joined()
    }
}

public enum WriteParagraphAlignment: String, Equatable, Sendable {
    case left
    case center
    case right
    case justified
}

public struct WriteListStyle: Equatable, Sendable {
    public var kind: WriteListKind
    public var level: Int

    public init(kind: WriteListKind, level: Int = 0) {
        self.kind = kind
        self.level = max(0, level)
    }
}

public enum WriteListKind: String, Equatable, Sendable {
    case bullet
    case numbered
}

/// A table cell holds a list of paragraphs. Maps to `<w:tc>`.
public struct WriteTableCell: Equatable, Sendable {
    public var paragraphs: [WriteParagraph]

    public init(paragraphs: [WriteParagraph] = [WriteParagraph()]) {
        self.paragraphs = paragraphs.isEmpty ? [WriteParagraph()] : paragraphs
    }

    public var plainText: String {
        paragraphs.map(\.plainText).joined(separator: "\n")
    }
}

/// A table row holds an ordered list of cells. Maps to `<w:tr>`.
public struct WriteTableRow: Equatable, Sendable {
    public var cells: [WriteTableCell]

    public init(cells: [WriteTableCell]) {
        self.cells = cells
    }
}

/// A table is a grid of rows. Maps to `<w:tbl>`.
public struct WriteTable: Equatable, Sendable {
    public var rows: [WriteTableRow]

    public init(rows: [WriteTableRow]) {
        self.rows = rows
    }

    /// Maximum cell count across rows — used as the column count.
    public var columnCount: Int {
        rows.map(\.cells.count).max() ?? 0
    }
}

/// A block-level element in the document body: either a paragraph or a table.
/// Maps to the children of `<w:body>` (`<w:p>` and `<w:tbl>`).
public enum WriteBlock: Equatable, Sendable {
    case paragraph(WriteParagraph)
    case table(WriteTable)
}

public struct WriteEdgeInsets: Equatable, Sendable {
    public var top: Double
    public var left: Double
    public var bottom: Double
    public var right: Double

    public init(top: Double = 0, left: Double = 0, bottom: Double = 0, right: Double = 0) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }
}

public struct WritePageSize: Equatable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double = 612, height: Double = 792) {
        self.width = width
        self.height = height
    }
}

public struct WriteDocumentSection: Equatable, Sendable {
    // Sizes in points
    public var pageSize: WritePageSize
    public var margins: WriteEdgeInsets
    public var header: [WriteParagraph]
    public var footer: [WriteParagraph]

    public init(
        pageSize: WritePageSize = WritePageSize(), // 8.5 x 11 inches
        margins: WriteEdgeInsets = WriteEdgeInsets(top: 72, left: 72, bottom: 72, right: 72),
        header: [WriteParagraph] = [],
        footer: [WriteParagraph] = []
    ) {
        self.pageSize = pageSize
        self.margins = margins
        self.header = header
        self.footer = footer
    }
}

/// Original OOXML package parts carried through editing so unsupported parts can
/// survive save operations instead of being silently dropped.
public struct OOXMLPackageSnapshot: Equatable, Sendable {
    public var parts: [String: Data]

    public init(parts: [String: Data] = [:]) {
        self.parts = parts
    }
}

public struct WriteDocumentModel: OfficeDocumentModel {
    public var title: String
    /// The document body in order: paragraphs and tables interleaved.
    public var blocks: [WriteBlock]
    public var section: WriteDocumentSection
    public var sourcePackage: OOXMLPackageSnapshot?

    public init(
        title: String,
        blocks: [WriteBlock],
        section: WriteDocumentSection = WriteDocumentSection(),
        sourcePackage: OOXMLPackageSnapshot? = nil
    ) {
        self.title = title
        self.blocks = blocks
        self.section = section
        self.sourcePackage = sourcePackage
    }

    /// Convenience for paragraph-only content (no tables).
    public init(
        title: String,
        paragraphs: [WriteParagraph],
        section: WriteDocumentSection = WriteDocumentSection(),
        sourcePackage: OOXMLPackageSnapshot? = nil
    ) {
        self.init(
            title: title,
            blocks: paragraphs.map(WriteBlock.paragraph),
            section: section,
            sourcePackage: sourcePackage
        )
    }

    /// Convenience for plain-text content: splits on newlines into single
    /// unformatted runs. Kept so callers that only have a `String` still work.
    public init(title: String, body: String) {
        let paragraphs = body
            .components(separatedBy: "\n")
            .map { line -> WriteParagraph in
                line.isEmpty ? WriteParagraph() : WriteParagraph(runs: [WriteRun(text: line)])
            }
        self.init(title: title, paragraphs: paragraphs)
    }

    /// Top-level paragraphs in order, skipping tables. Kept for callers that
    /// only deal with paragraph content (e.g. plain-text helpers).
    public var paragraphs: [WriteParagraph] {
        blocks.compactMap { block in
            if case let .paragraph(paragraph) = block { return paragraph }
            return nil
        }
    }

    /// Whole-document plain text, top-level paragraphs joined by newlines.
    public var plainText: String {
        paragraphs.map(\.plainText).joined(separator: "\n")
    }
}

public struct WriteDocumentStatistics: Equatable, Sendable {
    public var wordCount: Int
    public var characterCount: Int
    public var characterCountExcludingWhitespace: Int
    public var paragraphCount: Int
    public var tableCount: Int

    public init(
        wordCount: Int,
        characterCount: Int,
        characterCountExcludingWhitespace: Int,
        paragraphCount: Int,
        tableCount: Int
    ) {
        self.wordCount = wordCount
        self.characterCount = characterCount
        self.characterCountExcludingWhitespace = characterCountExcludingWhitespace
        self.paragraphCount = paragraphCount
        self.tableCount = tableCount
    }
}

public enum WriteNamedStyle: String, CaseIterable, Equatable, Sendable {
    case title
    case heading1
    case heading2
    case body
    case quote

    public var displayName: String {
        switch self {
        case .title:
            "Title"
        case .heading1:
            "Heading 1"
        case .heading2:
            "Heading 2"
        case .body:
            "Body"
        case .quote:
            "Quote"
        }
    }

    public func applying(to paragraph: WriteParagraph) -> WriteParagraph {
        var paragraph = paragraph
        paragraph.list = nil
        paragraph.pageBreakBefore = false

        switch self {
        case .title:
            paragraph.alignment = .center
            paragraph.spacingBefore = 0
            paragraph.spacingAfter = 18
            paragraph.leftIndent = nil
            paragraph.firstLineIndent = nil
            paragraph.runs = styledRuns(paragraph.runs, fontSize: 28, bold: true)
        case .heading1:
            paragraph.alignment = .left
            paragraph.spacingBefore = 18
            paragraph.spacingAfter = 8
            paragraph.leftIndent = nil
            paragraph.firstLineIndent = nil
            paragraph.runs = styledRuns(paragraph.runs, fontSize: 22, bold: true)
        case .heading2:
            paragraph.alignment = .left
            paragraph.spacingBefore = 14
            paragraph.spacingAfter = 6
            paragraph.leftIndent = nil
            paragraph.firstLineIndent = nil
            paragraph.runs = styledRuns(paragraph.runs, fontSize: 17, bold: true)
        case .body:
            paragraph.alignment = .left
            paragraph.lineSpacing = nil
            paragraph.spacingBefore = nil
            paragraph.spacingAfter = 8
            paragraph.leftIndent = nil
            paragraph.firstLineIndent = nil
            paragraph.runs = styledRuns(paragraph.runs, fontSize: 15)
        case .quote:
            paragraph.alignment = .left
            paragraph.spacingBefore = 8
            paragraph.spacingAfter = 8
            paragraph.leftIndent = 36
            paragraph.firstLineIndent = nil
            paragraph.runs = styledRuns(paragraph.runs, italic: true, textColorHex: "555555")
        }

        return paragraph
    }

    private func styledRuns(
        _ runs: [WriteRun],
        fontSize: Double? = nil,
        bold: Bool = false,
        italic: Bool = false,
        textColorHex: String? = nil
    ) -> [WriteRun] {
        let sourceRuns = runs.isEmpty ? [WriteRun(text: "")] : runs
        return sourceRuns.map { run in
            var run = run
            run.bold = bold
            run.italic = italic
            run.underline = false
            run.fontSize = fontSize
            run.textColorHex = textColorHex
            run.highlightColorHex = nil
            run.verticalAlignment = .baseline
            return run
        }
    }
}

public enum WriteDocumentTemplate: String, CaseIterable, Equatable, Sendable {
    case blank
    case businessLetter
    case report
    case meetingNotes

    public var displayName: String {
        switch self {
        case .blank:
            "Blank Document"
        case .businessLetter:
            "Business Letter"
        case .report:
            "Report"
        case .meetingNotes:
            "Meeting Notes"
        }
    }

    public var model: WriteDocumentModel {
        switch self {
        case .blank:
            return WriteDocumentModel.empty
        case .businessLetter:
            return WriteDocumentModel(title: displayName, paragraphs: [
                WriteParagraph(runs: [WriteRun(text: "Sender Name")]),
                WriteParagraph(runs: [WriteRun(text: "Company")]),
                WriteParagraph(runs: [WriteRun(text: "Address")]),
                WriteParagraph(),
                WriteParagraph(runs: [WriteRun(text: "Recipient Name")]),
                WriteParagraph(runs: [WriteRun(text: "Recipient Company")]),
                WriteParagraph(),
                WriteNamedStyle.heading1.applying(to: WriteParagraph(runs: [WriteRun(text: "Subject")])) ,
                WriteParagraph(runs: [WriteRun(text: "Dear Recipient,")]),
                WriteParagraph(runs: [WriteRun(text: "Write your message here.")]),
                WriteParagraph(runs: [WriteRun(text: "Sincerely,")]),
                WriteParagraph(runs: [WriteRun(text: "Sender Name")]),
            ])
        case .report:
            return WriteDocumentModel(title: displayName, paragraphs: [
                WriteNamedStyle.title.applying(to: WriteParagraph(runs: [WriteRun(text: "Report Title")])),
                WriteNamedStyle.body.applying(to: WriteParagraph(runs: [WriteRun(text: "Prepared by: Name")])),
                WriteNamedStyle.heading1.applying(to: WriteParagraph(runs: [WriteRun(text: "Executive Summary")])),
                WriteParagraph(runs: [WriteRun(text: "Summarize the key findings and recommendation.")]),
                WriteNamedStyle.heading1.applying(to: WriteParagraph(runs: [WriteRun(text: "Background")])),
                WriteParagraph(runs: [WriteRun(text: "Add context, scope, and assumptions.")]),
                WriteNamedStyle.heading1.applying(to: WriteParagraph(runs: [WriteRun(text: "Findings")])),
                WriteParagraph(runs: [WriteRun(text: "List important observations and evidence.")]),
                WriteNamedStyle.heading1.applying(to: WriteParagraph(runs: [WriteRun(text: "Next Steps")])),
                WriteParagraph(runs: [WriteRun(text: "Define owners and due dates.")]),
            ])
        case .meetingNotes:
            return WriteDocumentModel(title: displayName, paragraphs: [
                WriteNamedStyle.title.applying(to: WriteParagraph(runs: [WriteRun(text: "Meeting Notes")])),
                WriteParagraph(runs: [WriteRun(text: "Date:")]),
                WriteParagraph(runs: [WriteRun(text: "Attendees:")]),
                WriteNamedStyle.heading1.applying(to: WriteParagraph(runs: [WriteRun(text: "Agenda")])),
                WriteParagraph(runs: [WriteRun(text: "Agenda item")], list: WriteListStyle(kind: .bullet)),
                WriteNamedStyle.heading1.applying(to: WriteParagraph(runs: [WriteRun(text: "Decisions")])),
                WriteParagraph(runs: [WriteRun(text: "Decision")], list: WriteListStyle(kind: .bullet)),
                WriteNamedStyle.heading1.applying(to: WriteParagraph(runs: [WriteRun(text: "Action Items")])),
                WriteParagraph(runs: [WriteRun(text: "Owner - action item")], list: WriteListStyle(kind: .numbered)),
            ])
        }
    }
}

public extension WriteDocumentModel {
    /// Whole-document plain text, including table cells. Cells are tab-separated
    /// and rows/blocks are newline-separated so word count sees natural breaks.
    var fullPlainText: String {
        blocks.map { block -> String in
            switch block {
            case let .paragraph(paragraph):
                paragraph.plainText
            case let .table(table):
                table.rows.map { row in
                    row.cells.map(\.plainText).joined(separator: "\t")
                }.joined(separator: "\n")
            }
        }.joined(separator: "\n")
    }

    var statistics: WriteDocumentStatistics {
        let text = fullPlainText
        let wordCount = text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).count
        let characterCount = text.count
        let characterCountExcludingWhitespace = text.reduce(into: 0) { count, character in
            if !character.isWhitespace { count += 1 }
        }
        let paragraphCount = blocks.reduce(into: 0) { count, block in
            switch block {
            case .paragraph:
                count += 1
            case let .table(table):
                count += table.rows.reduce(0) { rowCount, row in
                    rowCount + row.cells.reduce(0) { cellCount, cell in
                        cellCount + cell.paragraphs.count
                    }
                }
            }
        }
        let tableCount = blocks.reduce(into: 0) { count, block in
            if case .table = block { count += 1 }
        }

        return WriteDocumentStatistics(
            wordCount: wordCount,
            characterCount: characterCount,
            characterCountExcludingWhitespace: characterCountExcludingWhitespace,
            paragraphCount: paragraphCount,
            tableCount: tableCount
        )
    }
}

public extension WriteDocumentModel {
    static let empty = WriteDocumentModel(
        title: String(localized: "Untitled"),
        paragraphs: [WriteParagraph()]
    )
}
