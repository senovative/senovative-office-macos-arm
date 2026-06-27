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
    private var inRunProperties = false
    private var inText = false

    private var runText = ""
    private var runBold = false
    private var runItalic = false
    private var runUnderline = false

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
        case "r":
            inRun = true
            runText = ""
            runBold = false
            runItalic = false
            runUnderline = false
        case "rPr":
            if inRun { inRunProperties = true }
        case "b":
            if inRun && inRunProperties { runBold = isOn(attributeDict) }
        case "i":
            if inRun && inRunProperties { runItalic = isOn(attributeDict) }
        case "u":
            if inRun && inRunProperties { runUnderline = isUnderlineOn(attributeDict) }
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
        case "rPr":
            inRunProperties = false
        case "r":
            if inRun, !runText.isEmpty {
                currentRuns.append(
                    WriteRun(text: runText, bold: runBold, italic: runItalic, underline: runUnderline)
                )
            }
            inRun = false
        case "p":
            paragraphs.append(WriteParagraph(runs: currentRuns))
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
        guard let value = attributes["w:val"] ?? attributes["val"] else { return true }
        return !(value == "false" || value == "0" || value == "off")
    }

    /// Underline carries a style in `w:val`; only `"none"` means no underline.
    private func isUnderlineOn(_ attributes: [String: String]) -> Bool {
        guard let value = attributes["w:val"] ?? attributes["val"] else { return true }
        return value != "none"
    }
}

enum WordprocessingMLWriter {
    static func contentTypes() -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
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

    static func document(paragraphs: [WriteParagraph]) -> Data {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:body>
        """

        for paragraph in paragraphs {
            xml += "\n        <w:p>"
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

    private static func runProperties(for run: WriteRun) -> String {
        guard run.bold || run.italic || run.underline else { return "" }
        var rpr = "\n                <w:rPr>"
        if run.bold { rpr += "<w:b/>" }
        if run.italic { rpr += "<w:i/>" }
        if run.underline { rpr += "<w:u w:val=\"single\"/>" }
        rpr += "</w:rPr>"
        return rpr
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
