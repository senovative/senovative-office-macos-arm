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

    public init(text: String, bold: Bool = false, italic: Bool = false, underline: Bool = false) {
        self.text = text
        self.bold = bold
        self.italic = italic
        self.underline = underline
    }
}

/// A paragraph: an ordered list of runs. Maps to `<w:p>`.
public struct WriteParagraph: Equatable, Sendable {
    public var runs: [WriteRun]

    public init(runs: [WriteRun] = []) {
        self.runs = runs
    }

    /// Plain text of the paragraph with formatting flattened away.
    public var plainText: String {
        runs.map(\.text).joined()
    }
}

public struct WriteDocumentModel: OfficeDocumentModel {
    public var title: String
    public var paragraphs: [WriteParagraph]

    public init(title: String, paragraphs: [WriteParagraph]) {
        self.title = title
        self.paragraphs = paragraphs
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
