import Foundation

/// Parses the body of `word/document.xml` into paragraphs and formatted runs.
///
/// Scope (Fase 1.c): paragraphs (`<w:p>`), runs (`<w:r>`), text (`<w:t>`) and the
/// three character toggles inside a run's `<w:rPr>` — bold (`<w:b>`), italic
/// (`<w:i>`) and underline (`<w:u>`). Run properties on the paragraph mark
/// (`<w:pPr><w:rPr>`) are intentionally ignored.
final class WordprocessingMLParser: NSObject, XMLParserDelegate {
    private var paragraphs: [WriteParagraph] = []
    private var currentRuns: [WriteRun] = []

    private var inRun = false
    private var inParagraphProperties = false
    private var inNumberingProperties = false
    private var inRunProperties = false
    private var inText = false

    private var runText = ""
    private var runBold = false
    private var runItalic = false
    private var runUnderline = false
    private var runFontFamily: String?
    private var runFontSize: Double?
    private var runTextColorHex: String?
    private var runHighlightColorHex: String?
    private var runVerticalAlignment: WriteVerticalAlignment = .baseline

    private var paragraphAlignment: WriteParagraphAlignment = .left
    private var paragraphLineSpacing: Double?
    private var paragraphSpacingBefore: Double?
    private var paragraphSpacingAfter: Double?
    private var paragraphLeftIndent: Double?
    private var paragraphFirstLineIndent: Double?
    private var paragraphListLevel: Int?
    private var paragraphNumberingId: Int?

    func parse(data: Data) throws -> [WriteParagraph] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw SenovativeDocumentError.fileCorrupted("XML parsing failed")
        }
        return paragraphs
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch local(elementName) {
        case "p":
            currentRuns = []
            paragraphAlignment = .left
            paragraphLineSpacing = nil
            paragraphSpacingBefore = nil
            paragraphSpacingAfter = nil
            paragraphLeftIndent = nil
            paragraphFirstLineIndent = nil
            paragraphListLevel = nil
            paragraphNumberingId = nil
        case "pPr":
            inParagraphProperties = true
        case "jc":
            if inParagraphProperties {
                paragraphAlignment = alignment(from: attribute(attributeDict, "val"))
            }
        case "spacing":
            if inParagraphProperties {
                paragraphLineSpacing = points(fromTwips: attribute(attributeDict, "line"))
                paragraphSpacingBefore = points(fromTwips: attribute(attributeDict, "before"))
                paragraphSpacingAfter = points(fromTwips: attribute(attributeDict, "after"))
            }
        case "ind":
            if inParagraphProperties {
                paragraphLeftIndent = points(fromTwips: attribute(attributeDict, "left"))
                paragraphFirstLineIndent = points(fromTwips: attribute(attributeDict, "firstLine"))
                if paragraphFirstLineIndent == nil, let hanging = points(fromTwips: attribute(attributeDict, "hanging")) {
                    paragraphFirstLineIndent = -hanging
                }
            }
        case "numPr":
            if inParagraphProperties { inNumberingProperties = true }
        case "ilvl":
            if inNumberingProperties { paragraphListLevel = intValue(attribute(attributeDict, "val")) }
        case "numId":
            if inNumberingProperties { paragraphNumberingId = intValue(attribute(attributeDict, "val")) }
        case "r":
            inRun = true
            runText = ""
            runBold = false
            runItalic = false
            runUnderline = false
            runFontFamily = nil
            runFontSize = nil
            runTextColorHex = nil
            runHighlightColorHex = nil
            runVerticalAlignment = .baseline
        case "rPr":
            if inRun { inRunProperties = true }
        case "b":
            if inRun && inRunProperties { runBold = isOn(attributeDict) }
        case "i":
            if inRun && inRunProperties { runItalic = isOn(attributeDict) }
        case "u":
            if inRun && inRunProperties { runUnderline = isUnderlineOn(attributeDict) }
        case "rFonts":
            if inRun && inRunProperties {
                runFontFamily = attribute(attributeDict, "ascii")
                    ?? attribute(attributeDict, "hAnsi")
                    ?? attribute(attributeDict, "cs")
            }
        case "sz":
            if inRun && inRunProperties, let value = doubleValue(attribute(attributeDict, "val")) {
                runFontSize = value / 2.0
            }
        case "color":
            if inRun && inRunProperties {
                runTextColorHex = normalizedHex(attribute(attributeDict, "val"))
            }
        case "shd":
            if inRun && inRunProperties {
                runHighlightColorHex = normalizedHex(attribute(attributeDict, "fill"))
            }
        case "vertAlign":
            if inRun && inRunProperties {
                runVerticalAlignment = verticalAlignment(from: attribute(attributeDict, "val"))
            }
        case "t":
            if inRun { inText = true }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inText { runText += string }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        switch local(elementName) {
        case "t":
            inText = false
        case "numPr":
            inNumberingProperties = false
        case "pPr":
            inParagraphProperties = false
        case "rPr":
            inRunProperties = false
        case "r":
            if inRun, !runText.isEmpty {
                currentRuns.append(
                    WriteRun(
                        text: runText,
                        bold: runBold,
                        italic: runItalic,
                        underline: runUnderline,
                        fontFamily: runFontFamily,
                        fontSize: runFontSize,
                        textColorHex: runTextColorHex,
                        highlightColorHex: runHighlightColorHex,
                        verticalAlignment: runVerticalAlignment
                    )
                )
            }
            inRun = false
        case "p":
            paragraphs.append(
                WriteParagraph(
                    runs: currentRuns,
                    alignment: paragraphAlignment,
                    lineSpacing: paragraphLineSpacing,
                    spacingBefore: paragraphSpacingBefore,
                    spacingAfter: paragraphSpacingAfter,
                    leftIndent: paragraphLeftIndent,
                    firstLineIndent: paragraphFirstLineIndent,
                    list: listStyle(numberingId: paragraphNumberingId, level: paragraphListLevel)
                )
            )
            currentRuns = []
        default:
            break
        }
    }

    /// Strips a namespace prefix (`w:p` -> `p`) so both prefixed and bare tags match.
    private func local(_ elementName: String) -> Substring {
        if let colon = elementName.firstIndex(of: ":") {
            return elementName[elementName.index(after: colon)...]
        }
        return elementName[...]
    }

    /// A boolean toggle (`<w:b/>`) is on unless explicitly disabled via `w:val`.
    private func isOn(_ attributes: [String: String]) -> Bool {
        guard let value = attribute(attributes, "val") else { return true }
        return !(value == "false" || value == "0" || value == "off")
    }

    /// Underline carries a style in `w:val`; only `"none"` means no underline.
    private func isUnderlineOn(_ attributes: [String: String]) -> Bool {
        guard let value = attribute(attributes, "val") else { return true }
        return value != "none"
    }

    private func attribute(_ attributes: [String: String], _ localName: String) -> String? {
        attributes["w:\(localName)"] ?? attributes[localName]
    }

    private func doubleValue(_ value: String?) -> Double? {
        guard let value else { return nil }
        return Double(value)
    }

    private func intValue(_ value: String?) -> Int? {
        guard let value else { return nil }
        return Int(value)
    }

    private func points(fromTwips value: String?) -> Double? {
        guard let value = doubleValue(value) else { return nil }
        return value / 20.0
    }

    private func normalizedHex(_ value: String?) -> String? {
        guard let value, value != "auto" else { return nil }
        return value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private func alignment(from value: String?) -> WriteParagraphAlignment {
        switch value {
        case "center":
            .center
        case "right", "end":
            .right
        case "both", "distribute", "justified":
            .justified
        default:
            .left
        }
    }

    private func verticalAlignment(from value: String?) -> WriteVerticalAlignment {
        switch value {
        case "superscript":
            .superscript
        case "subscript":
            .subscripted
        default:
            .baseline
        }
    }

    private func listStyle(numberingId: Int?, level: Int?) -> WriteListStyle? {
        guard let numberingId else { return nil }
        let kind: WriteListKind = numberingId == 1 ? .bullet : .numbered
        return WriteListStyle(kind: kind, level: level ?? 0)
    }
}

enum WordprocessingMLWriter {
    static func contentTypes(includeNumbering: Bool) -> Data {
        let numberingOverride = includeNumbering
            ? "\n    <Override PartName=\"/word/numbering.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml\"/>"
            : ""
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>\(numberingOverride)
        </Types>
        """
        return Data(xml.utf8)
    }

    static func rootRels() -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        </Relationships>
        """
        return Data(xml.utf8)
    }

    static func documentRels(includeNumbering: Bool) -> Data {
        let numberingRelationship = includeNumbering
            ? "\n    <Relationship Id=\"rIdNumbering\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering\" Target=\"numbering.xml\"/>"
            : ""
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\(numberingRelationship)
        </Relationships>
        """
        return Data(xml.utf8)
    }

    static func document(paragraphs: [WriteParagraph]) -> Data {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:body>
        """

        for paragraph in paragraphs {
            xml += "\n        <w:p>"
            xml += paragraphProperties(for: paragraph)
            for run in paragraph.runs {
                xml += "\n            <w:r>"
                xml += runProperties(for: run)
                xml += "\n                <w:t xml:space=\"preserve\">\(escape(run.text))</w:t>"
                xml += "\n            </w:r>"
            }
            xml += "\n        </w:p>"
        }

        xml += """

            </w:body>
        </w:document>
        """
        return Data(xml.utf8)
    }

    static func numbering() -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:numbering xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:abstractNum w:abstractNumId="1">
                <w:lvl w:ilvl="0">
                    <w:start w:val="1"/>
                    <w:numFmt w:val="bullet"/>
                    <w:lvlText w:val="•"/>
                    <w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr>
                </w:lvl>
            </w:abstractNum>
            <w:abstractNum w:abstractNumId="2">
                <w:lvl w:ilvl="0">
                    <w:start w:val="1"/>
                    <w:numFmt w:val="decimal"/>
                    <w:lvlText w:val="%1."/>
                    <w:pPr><w:ind w:left="720" w:hanging="360"/></w:pPr>
                </w:lvl>
            </w:abstractNum>
            <w:num w:numId="1"><w:abstractNumId w:val="1"/></w:num>
            <w:num w:numId="2"><w:abstractNumId w:val="2"/></w:num>
        </w:numbering>
        """
        return Data(xml.utf8)
    }

    static func needsNumbering(_ paragraphs: [WriteParagraph]) -> Bool {
        paragraphs.contains { $0.list != nil }
    }

    private static func paragraphProperties(for paragraph: WriteParagraph) -> String {
        let parts = paragraphPropertyParts(for: paragraph)
        guard !parts.isEmpty else { return "" }
        return "\n            <w:pPr>\(parts.joined())</w:pPr>"
    }

    private static func paragraphPropertyParts(for paragraph: WriteParagraph) -> [String] {
        var parts: [String] = []

        if paragraph.alignment != .left {
            parts.append("<w:jc w:val=\"\(alignmentValue(paragraph.alignment))\"/>")
        }

        var spacingAttributes: [String] = []
        if let lineSpacing = paragraph.lineSpacing {
            spacingAttributes.append("w:line=\"\(twips(lineSpacing))\"")
            spacingAttributes.append("w:lineRule=\"exact\"")
        }
        if let spacingBefore = paragraph.spacingBefore {
            spacingAttributes.append("w:before=\"\(twips(spacingBefore))\"")
        }
        if let spacingAfter = paragraph.spacingAfter {
            spacingAttributes.append("w:after=\"\(twips(spacingAfter))\"")
        }
        if !spacingAttributes.isEmpty {
            parts.append("<w:spacing \(spacingAttributes.joined(separator: " "))/>\n")
        }

        var indentAttributes: [String] = []
        if let leftIndent = paragraph.leftIndent {
            indentAttributes.append("w:left=\"\(twips(leftIndent))\"")
        }
        if let firstLineIndent = paragraph.firstLineIndent {
            if firstLineIndent < 0 {
                indentAttributes.append("w:hanging=\"\(twips(abs(firstLineIndent)))\"")
            } else {
                indentAttributes.append("w:firstLine=\"\(twips(firstLineIndent))\"")
            }
        }
        if !indentAttributes.isEmpty {
            parts.append("<w:ind \(indentAttributes.joined(separator: " "))/>\n")
        }

        if let list = paragraph.list {
            let numId = list.kind == .bullet ? 1 : 2
            parts.append("<w:numPr><w:ilvl w:val=\"\(list.level)\"/><w:numId w:val=\"\(numId)\"/></w:numPr>")
        }

        return parts
    }

    private static func runProperties(for run: WriteRun) -> String {
        let parts = runPropertyParts(for: run)
        guard !parts.isEmpty else { return "" }
        var rpr = "\n                <w:rPr>"
        rpr += parts.joined()
        rpr += "</w:rPr>"
        return rpr
    }

    private static func runPropertyParts(for run: WriteRun) -> [String] {
        var parts: [String] = []
        if let fontFamily = run.fontFamily {
            let escaped = escapeAttribute(fontFamily)
            parts.append("<w:rFonts w:ascii=\"\(escaped)\" w:hAnsi=\"\(escaped)\"/>")
        }
        if let fontSize = run.fontSize {
            parts.append("<w:sz w:val=\"\(halfPoints(fontSize))\"/>")
        }
        if let textColorHex = sanitizedHex(run.textColorHex) {
            parts.append("<w:color w:val=\"\(textColorHex)\"/>")
        }
        if let highlightColorHex = sanitizedHex(run.highlightColorHex) {
            parts.append("<w:shd w:val=\"clear\" w:color=\"auto\" w:fill=\"\(highlightColorHex)\"/>")
        }
        if run.bold { parts.append("<w:b/>") }
        if run.italic { parts.append("<w:i/>") }
        if run.underline { parts.append("<w:u w:val=\"single\"/>") }
        switch run.verticalAlignment {
        case .baseline:
            break
        case .superscript:
            parts.append("<w:vertAlign w:val=\"superscript\"/>")
        case .subscripted:
            parts.append("<w:vertAlign w:val=\"subscript\"/>")
        }
        return parts
    }

    private static func alignmentValue(_ alignment: WriteParagraphAlignment) -> String {
        switch alignment {
        case .left:
            "left"
        case .center:
            "center"
        case .right:
            "right"
        case .justified:
            "both"
        }
    }

    private static func halfPoints(_ points: Double) -> Int {
        Int((points * 2.0).rounded())
    }

    private static func twips(_ points: Double) -> Int {
        Int((points * 20.0).rounded())
    }

    private static func sanitizedHex(_ value: String?) -> String? {
        guard let value else { return nil }
        let hex = value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard hex.count == 6, hex.allSatisfy({ $0.isHexDigit }) else { return nil }
        return hex
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func escapeAttribute(_ text: String) -> String {
        escape(text)
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
