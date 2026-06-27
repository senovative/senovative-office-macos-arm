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
        isPageBreak: Bool = false
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

public struct WriteDocumentModel: OfficeDocumentModel {
    public var title: String
    public var paragraphs: [WriteParagraph]
    public var section: WriteDocumentSection

    public init(title: String, paragraphs: [WriteParagraph], section: WriteDocumentSection = WriteDocumentSection()) {
        self.title = title
        self.paragraphs = paragraphs
        self.section = section
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

    /// Whole-document plain text, paragraphs joined by newlines.
    public var plainText: String {
        paragraphs.map(\.plainText).joined(separator: "\n")
    }
}

public extension WriteDocumentModel {
    static let empty = WriteDocumentModel(
        title: String(localized: "Untitled"),
        paragraphs: [WriteParagraph()]
    )
}
