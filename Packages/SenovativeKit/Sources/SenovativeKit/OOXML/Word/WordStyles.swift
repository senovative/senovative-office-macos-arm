import Foundation

/// Document-level run defaults resolved from `word/styles.xml` (`<w:docDefaults>`)
/// with theme font tokens already resolved to concrete typeface names.
///
/// Word applies these defaults to any run that does not specify its own font,
/// size, or color. Without them, body text parsed from a real `.docx` carries
/// `nil` font/size and renders with the app's fallback instead of the typeface
/// the document was authored in.
struct WriteDocumentDefaults: Equatable {
    var fontFamily: String?
    var fontSize: Double?
    var textColorHex: String?

    static let none = WriteDocumentDefaults()

    var isEmpty: Bool { self == .none }
}

/// Extracts the major/minor latin typefaces from `word/theme/theme1.xml`.
///
/// `<w:rFonts w:asciiTheme="minorHAnsi"/>` references a theme slot rather than a
/// literal name; the concrete name lives in the theme's `<a:fontScheme>`.
final class ThemeFontParser: NSObject, XMLParserDelegate {
    private(set) var majorLatin: String?
    private(set) var minorLatin: String?

    private var inMajorFont = false
    private var inMinorFont = false

    func parse(data: Data) -> (major: String?, minor: String?) {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return (majorLatin, minorLatin)
    }

    /// Resolves a theme font token (e.g. `minorHAnsi`) to a concrete typeface.
    func resolve(token: String) -> String? {
        token.hasPrefix("major") ? majorLatin : minorLatin
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch localName(elementName) {
        case "majorFont":
            inMajorFont = true
        case "minorFont":
            inMinorFont = true
        case "latin":
            let typeface = attributeDict["typeface"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let typeface, !typeface.isEmpty else { return }
            if inMajorFont, majorLatin == nil { majorLatin = typeface }
            if inMinorFont, minorLatin == nil { minorLatin = typeface }
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch localName(elementName) {
        case "majorFont":
            inMajorFont = false
        case "minorFont":
            inMinorFont = false
        default:
            break
        }
    }

    private func localName(_ name: String) -> Substring {
        if let colon = name.firstIndex(of: ":") {
            return name[name.index(after: colon)...]
        }
        return name[...]
    }
}

/// Extracts `<w:docDefaults><w:rPrDefault>` run defaults from `word/styles.xml`.
/// Theme font tokens are resolved lazily via the supplied `themeFonts`.
final class StylesDefaultsParser: NSObject, XMLParserDelegate {
    private let themeFonts: ThemeFontParser?

    private var inDocDefaults = false
    private var inRunDefault = false

    private var fontFamily: String?
    private var fontSize: Double?
    private var textColorHex: String?

    init(themeFonts: ThemeFontParser? = nil) {
        self.themeFonts = themeFonts
    }

    func parse(data: Data) -> WriteDocumentDefaults {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return WriteDocumentDefaults(
            fontFamily: fontFamily,
            fontSize: fontSize,
            textColorHex: textColorHex
        )
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch localName(elementName) {
        case "docDefaults":
            inDocDefaults = true
        case "rPrDefault":
            if inDocDefaults { inRunDefault = true }
        case "rFonts":
            guard inRunDefault, fontFamily == nil else { return }
            if let literal = attr(attributeDict, "ascii") ?? attr(attributeDict, "hAnsi") ?? attr(attributeDict, "cs") {
                fontFamily = literal
            } else if let token = attr(attributeDict, "asciiTheme") ?? attr(attributeDict, "hAnsiTheme") ?? attr(attributeDict, "cstheme") {
                fontFamily = themeFonts?.resolve(token: token)
            }
        case "sz":
            guard inRunDefault, fontSize == nil, let value = attr(attributeDict, "val"), let half = Double(value) else { return }
            fontSize = half / 2.0
        case "color":
            guard inRunDefault, textColorHex == nil, let value = attr(attributeDict, "val"), value != "auto" else { return }
            textColorHex = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch localName(elementName) {
        case "docDefaults":
            inDocDefaults = false
        case "rPrDefault":
            inRunDefault = false
        default:
            break
        }
    }

    private func localName(_ name: String) -> Substring {
        if let colon = name.firstIndex(of: ":") {
            return name[name.index(after: colon)...]
        }
        return name[...]
    }

    private func attr(_ attributes: [String: String], _ local: String) -> String? {
        attributes["w:\(local)"] ?? attributes[local]
    }
}

extension WriteDocumentDefaults {
    /// Fills any unset font/size/color on a run with the document defaults.
    /// Explicit run formatting always wins.
    func applied(to run: WriteRun) -> WriteRun {
        var run = run
        if run.fontFamily == nil { run.fontFamily = fontFamily }
        if run.fontSize == nil { run.fontSize = fontSize }
        if run.textColorHex == nil { run.textColorHex = textColorHex }
        return run
    }

    /// Returns the blocks with document defaults applied to every run, including
    /// runs inside table cells.
    func applied(to blocks: [WriteBlock]) -> [WriteBlock] {
        guard !isEmpty else { return blocks }
        return blocks.map { block in
            switch block {
            case let .paragraph(paragraph):
                return .paragraph(applied(to: paragraph))
            case let .table(table):
                let rows = table.rows.map { row in
                    WriteTableRow(cells: row.cells.map { cell in
                        WriteTableCell(paragraphs: cell.paragraphs.map(applied(to:)))
                    })
                }
                return .table(WriteTable(rows: rows))
            }
        }
    }

    func applied(to paragraph: WriteParagraph) -> WriteParagraph {
        var paragraph = paragraph
        paragraph.runs = paragraph.runs.map(applied(to:))
        return paragraph
    }
}
