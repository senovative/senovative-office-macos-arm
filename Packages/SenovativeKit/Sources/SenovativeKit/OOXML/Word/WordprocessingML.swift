import Foundation

/// Parses the body of `word/document.xml` into block-level content
/// (paragraphs and tables) plus formatted runs.
///
/// Scope: paragraphs (`<w:p>`), tables (`<w:tbl>`/`<w:tr>`/`<w:tc>`), runs
/// (`<w:r>`), text (`<w:t>`), tabs (`<w:tab>`), page breaks (`<w:br type=page>`),
/// hyperlinks (`<w:hyperlink r:id>`), the character toggles inside a run's
/// `<w:rPr>` (bold/italic/underline, fonts, size, color, highlight, vertAlign),
/// and paragraph properties (`<w:jc>`, `<w:spacing>`, `<w:ind>`, `<w:numPr>`).
/// Section properties (`<w:sectPr>`) are read for page size and margins.
final class WordprocessingMLParser: NSObject, XMLParserDelegate {
    private var blocks: [WriteBlock] = []
    private var currentRuns: [WriteRun] = []
    private var section = WriteDocumentSection()

    /// Resolves a hyperlink relationship id (`r:id`) to its external target URL.
    private let hyperlinkResolver: (String) -> String?
    /// Resolves an image relationship id (`r:embed`) to its bytes and extension.
    private let imageResolver: (String) -> (data: Data, fileExtension: String)?

    // Table assembly state (single level of nesting).
    private var inTable = false
    private var inCell = false
    private var tableRows: [WriteTableRow] = []
    private var currentRowCells: [WriteTableCell] = []
    private var currentCellParagraphs: [WriteParagraph] = []

    // Hyperlink state.
    private var currentLinkURL: String?

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
    private var runIsPageBreak = false
    private var runImage: WriteImage?
    private var runShape: WriteShape?

    // Drawing (`<w:drawing>`) assembly state.
    private var inDrawing = false
    private var drawingCx: Double?
    private var drawingCy: Double?
    private var drawingBlipRelId: String?
    private var drawingPreset: String?
    private var drawingFillHex: String?

    private var paragraphAlignment: WriteParagraphAlignment = .left
    private var paragraphLineSpacing: Double?
    private var paragraphSpacingBefore: Double?
    private var paragraphSpacingAfter: Double?
    private var paragraphLeftIndent: Double?
    private var paragraphFirstLineIndent: Double?
    private var paragraphListLevel: Int?
    private var paragraphNumberingId: Int?
    private var paragraphPageBreakBefore = false

    init(
        hyperlinkResolver: @escaping (String) -> String? = { _ in nil },
        imageResolver: @escaping (String) -> (data: Data, fileExtension: String)? = { _ in nil }
    ) {
        self.hyperlinkResolver = hyperlinkResolver
        self.imageResolver = imageResolver
    }

    func parse(data: Data) throws -> (blocks: [WriteBlock], section: WriteDocumentSection) {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw SenovativeDocumentError.fileCorrupted("XML parsing failed")
        }
        return (blocks, section)
    }

    /// Convenience for parts that only carry paragraphs (headers/footers).
    func parseParagraphs(data: Data) throws -> [WriteParagraph] {
        try parse(data: data).blocks.compactMap { block in
            if case let .paragraph(paragraph) = block { return paragraph }
            return nil
        }
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch local(elementName) {
        case "tbl":
            inTable = true
            tableRows = []
        case "tr":
            if inTable { currentRowCells = [] }
        case "tc":
            if inTable {
                inCell = true
                currentCellParagraphs = []
            }
        case "hyperlink":
            if let relId = attributeDict["r:id"] {
                currentLinkURL = hyperlinkResolver(relId)
            }
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
            paragraphPageBreakBefore = false
        case "pPr":
            inParagraphProperties = true
        case "jc":
            if inParagraphProperties {
                paragraphAlignment = alignment(from: attribute(attributeDict, "val"))
            }
        case "pageBreakBefore":
            if inParagraphProperties {
                paragraphPageBreakBefore = isOn(attributeDict)
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
            runIsPageBreak = false
            runImage = nil
            runShape = nil
        case "drawing":
            if inRun {
                inDrawing = true
                drawingCx = nil
                drawingCy = nil
                drawingBlipRelId = nil
                drawingPreset = nil
                drawingFillHex = nil
            }
        case "extent":
            if inDrawing {
                drawingCx = points(fromEmu: attributeDict["cx"])
                drawingCy = points(fromEmu: attributeDict["cy"])
            }
        case "blip":
            if inDrawing, let embed = attributeDict["r:embed"] ?? attributeDict["embed"] {
                drawingBlipRelId = embed
            }
        case "prstGeom":
            if inDrawing { drawingPreset = attributeDict["prst"] }
        case "srgbClr":
            if inDrawing, drawingFillHex == nil {
                drawingFillHex = normalizedHex(attributeDict["val"])
            }
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
        case "tab":
            if inRun { runText += "\t" }
        case "br":
            if inRun, attribute(attributeDict, "type") == "page" {
                runIsPageBreak = true
            }
        case "t":
            if inRun { inText = true }
        case "pgSz":
            if let w = points(fromTwips: attribute(attributeDict, "w")),
               let h = points(fromTwips: attribute(attributeDict, "h")) {
                section.pageSize = WritePageSize(width: w, height: h)
            }
        case "pgMar":
            if let top = points(fromTwips: attribute(attributeDict, "top")),
               let left = points(fromTwips: attribute(attributeDict, "left")),
               let bottom = points(fromTwips: attribute(attributeDict, "bottom")),
               let right = points(fromTwips: attribute(attributeDict, "right")) {
                section.margins = WriteEdgeInsets(top: top, left: left, bottom: bottom, right: right)
            }
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
        case "hyperlink":
            currentLinkURL = nil
        case "drawing":
            if inDrawing {
                let width = drawingCx ?? 0
                let height = drawingCy ?? 0
                if let relId = drawingBlipRelId, let resolved = imageResolver(relId) {
                    runImage = WriteImage(
                        data: resolved.data,
                        fileExtension: resolved.fileExtension,
                        width: width,
                        height: height
                    )
                } else if let preset = drawingPreset {
                    runShape = WriteShape(
                        kind: preset == "ellipse" ? .oval : .rectangle,
                        width: width,
                        height: height,
                        fillColorHex: drawingFillHex
                    )
                }
                inDrawing = false
            }
        case "r":
            if inRun, !runText.isEmpty || runIsPageBreak || runImage != nil || runShape != nil {
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
                        verticalAlignment: runVerticalAlignment,
                        isPageBreak: runIsPageBreak,
                        linkURL: currentLinkURL,
                        image: runImage,
                        shape: runShape
                    )
                )
            }
            inRun = false
        case "p":
            let paragraph = WriteParagraph(
                runs: currentRuns,
                alignment: paragraphAlignment,
                lineSpacing: paragraphLineSpacing,
                spacingBefore: paragraphSpacingBefore,
                spacingAfter: paragraphSpacingAfter,
                leftIndent: paragraphLeftIndent,
                firstLineIndent: paragraphFirstLineIndent,
                list: listStyle(numberingId: paragraphNumberingId, level: paragraphListLevel),
                pageBreakBefore: paragraphPageBreakBefore
            )
            if inCell {
                currentCellParagraphs.append(paragraph)
            } else {
                blocks.append(.paragraph(paragraph))
            }
            currentRuns = []
        case "tc":
            if inTable {
                currentRowCells.append(WriteTableCell(paragraphs: currentCellParagraphs))
                currentCellParagraphs = []
                inCell = false
            }
        case "tr":
            if inTable {
                currentRowCells.removeAll { $0.paragraphs.isEmpty }
                tableRows.append(WriteTableRow(cells: currentRowCells))
                currentRowCells = []
            }
        case "tbl":
            blocks.append(.table(WriteTable(rows: tableRows)))
            tableRows = []
            inTable = false
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

    /// English Metric Units -> points (914400 EMU = 1 inch = 72 pt).
    private func points(fromEmu value: String?) -> Double? {
        guard let value = doubleValue(value) else { return nil }
        return value / 12700.0
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

/// Parses `word/_rels/document.xml.rels` into an id -> target map.
final class RelationshipParser: NSObject, XMLParserDelegate {
    private var relationships: [String: String] = [:]

    func parse(data: Data) -> [String: String] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return relationships
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName.hasSuffix("Relationship") || elementName == "Relationship" else { return }
        if let id = attributeDict["Id"], let target = attributeDict["Target"] {
            relationships[id] = target
        }
    }
}

/// A picture part to be written into the archive, with its relationship id.
struct ImageRelation {
    let image: WriteImage
    let relId: String
    let partName: String
}

/// Accumulates pictures encountered while serializing and hands out unique
/// `<wp:docPr>` ids for every drawing (picture or shape).
final class DrawingContext {
    var images: [ImageRelation] = []
    private var nextDrawingId = 1

    func makeDrawingId() -> Int {
        defer { nextDrawingId += 1 }
        return nextDrawingId
    }
}

enum WordprocessingMLWriter {
    static func contentTypes(
        includeNumbering: Bool,
        hasHeader: Bool,
        hasFooter: Bool,
        imageExtensions: Set<String> = []
    ) -> Data {
        let imageDefaults = imageExtensions.sorted().map { ext in
            "\n    <Default Extension=\"\(ext)\" ContentType=\"\(imageContentType(for: ext))\"/>"
        }.joined()
        let numberingOverride = includeNumbering
            ? "\n    <Override PartName=\"/word/numbering.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.numbering+xml\"/>"
            : ""
        let headerOverride = hasHeader
            ? "\n    <Override PartName=\"/word/header1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.header+xml\"/>"
            : ""
        let footerOverride = hasFooter
            ? "\n    <Override PartName=\"/word/footer1.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.footer+xml\"/>"
            : ""
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>\(imageDefaults)
            <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>\(numberingOverride)\(headerOverride)\(footerOverride)
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

    static func documentRels(
        includeNumbering: Bool,
        hasHeader: Bool,
        hasFooter: Bool,
        linkRelations: [(url: String, relId: String)] = [],
        imageRelations: [ImageRelation] = []
    ) -> Data {
        var relationships = ""
        for relation in imageRelations {
            relationships += "\n    <Relationship Id=\"\(relation.relId)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/image\" Target=\"\(relation.partName)\"/>"
        }
        if includeNumbering {
            relationships += "\n    <Relationship Id=\"rIdNumbering\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering\" Target=\"numbering.xml\"/>"
        }
        if hasHeader {
            relationships += "\n    <Relationship Id=\"rIdHeader1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/header\" Target=\"header1.xml\"/>"
        }
        if hasFooter {
            relationships += "\n    <Relationship Id=\"rIdFooter1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/footer\" Target=\"footer1.xml\"/>"
        }
        for relation in linkRelations {
            relationships += "\n    <Relationship Id=\"\(relation.relId)\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink\" Target=\"\(escapeAttribute(relation.url))\" TargetMode=\"External\"/>"
        }
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">\(relationships)
        </Relationships>
        """
        return Data(xml.utf8)
    }

    /// Serializes the document body and returns the XML plus the pictures that
    /// must be written into the archive (with their relationship ids).
    static func document(
        blocks: [WriteBlock],
        section: WriteDocumentSection,
        linkRelations: [(url: String, relId: String)] = []
    ) -> (xml: Data, images: [ImageRelation]) {
        let links = Dictionary(linkRelations.map { ($0.url, $0.relId) }, uniquingKeysWith: { first, _ in first })
        let context = DrawingContext()
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture" xmlns:wps="http://schemas.microsoft.com/office/word/2010/wordprocessingShape">
            <w:body>
        """

        xml += writeBlocks(blocks, links: links, context: context)
        xml += sectionProperties(for: section)

        xml += """

            </w:body>
        </w:document>
        """
        return (Data(xml.utf8), context.images)
    }

    static func header(paragraphs: [WriteParagraph]) -> Data {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:hdr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        """
        xml += writeParagraphs(paragraphs, context: DrawingContext())
        xml += "\n</w:hdr>"
        return Data(xml.utf8)
    }

    static func footer(paragraphs: [WriteParagraph]) -> Data {
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:ftr xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
        """
        xml += writeParagraphs(paragraphs, context: DrawingContext())
        xml += "\n</w:ftr>"
        return Data(xml.utf8)
    }

    private static func writeBlocks(_ blocks: [WriteBlock], links: [String: String], context: DrawingContext) -> String {
        var xml = ""
        for block in blocks {
            switch block {
            case let .paragraph(paragraph):
                xml += writeParagraph(paragraph, links: links, context: context)
            case let .table(table):
                xml += writeTable(table, links: links, context: context)
            }
        }
        return xml
    }

    private static func writeParagraphs(_ paragraphs: [WriteParagraph], links: [String: String] = [:], context: DrawingContext) -> String {
        paragraphs.map { writeParagraph($0, links: links, context: context) }.joined()
    }

    private static func writeParagraph(_ paragraph: WriteParagraph, links: [String: String], context: DrawingContext) -> String {
        var xml = "\n        <w:p>"
        xml += paragraphProperties(for: paragraph)
        for run in paragraph.runs {
            let runXML = "\n            <w:r>\(runInner(run, context: context))\n            </w:r>"
            if let url = run.linkURL, let relId = links[url] {
                xml += "\n            <w:hyperlink r:id=\"\(relId)\">\(runXML)\n            </w:hyperlink>"
            } else {
                xml += runXML
            }
        }
        xml += "\n        </w:p>"
        return xml
    }

    private static func writeTable(_ table: WriteTable, links: [String: String], context: DrawingContext) -> String {
        let columns = max(1, table.columnCount)
        let usableWidth = 9360 // ~6.5in in twips
        let colWidth = usableWidth / columns

        var grid = ""
        for _ in 0..<columns {
            grid += "\n                <w:gridCol w:w=\"\(colWidth)\"/>"
        }

        var xml = """

                <w:tbl>
                    <w:tblPr>
                        <w:tblW w:w="0" w:type="auto"/>
                        <w:tblBorders>
                            <w:top w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                            <w:left w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                            <w:bottom w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                            <w:right w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                            <w:insideH w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                            <w:insideV w:val="single" w:sz="4" w:space="0" w:color="auto"/>
                        </w:tblBorders>
                    </w:tblPr>
                    <w:tblGrid>\(grid)
                    </w:tblGrid>
        """

        for row in table.rows {
            xml += "\n                <w:tr>"
            for cell in row.cells {
                xml += "\n                    <w:tc>"
                xml += "\n                        <w:tcPr><w:tcW w:w=\"\(colWidth)\" w:type=\"dxa\"/></w:tcPr>"
                xml += writeParagraphs(cell.paragraphs, links: links, context: context)
                xml += "\n                    </w:tc>"
            }
            xml += "\n                </w:tr>"
        }

        xml += "\n                </w:tbl>"
        return xml
    }

    /// Inner content of a `<w:r>`: run properties, drawings, page break, and text split on tabs.
    private static func runInner(_ run: WriteRun, context: DrawingContext) -> String {
        var inner = runProperties(for: run)

        if let image = run.image {
            let id = context.makeDrawingId()
            let ext = normalizedExtension(image.fileExtension)
            let index = context.images.count + 1
            let relId = "rIdImg\(index)"
            let partName = "media/image\(index).\(ext)"
            context.images.append(ImageRelation(image: image, relId: relId, partName: partName))
            inner += imageDrawing(image, relId: relId, docPrId: id)
            return inner
        }

        if let shape = run.shape {
            let id = context.makeDrawingId()
            inner += shapeDrawing(shape, docPrId: id)
            return inner
        }

        if run.isPageBreak {
            inner += "\n                <w:br w:type=\"page\"/>"
        }
        let segments = run.text.components(separatedBy: "\t")
        for (index, segment) in segments.enumerated() {
            if index > 0 {
                inner += "\n                <w:tab/>"
            }
            if !segment.isEmpty {
                inner += "\n                <w:t xml:space=\"preserve\">\(escape(segment))</w:t>"
            }
        }
        return inner
    }

    private static func imageDrawing(_ image: WriteImage, relId: String, docPrId: Int) -> String {
        let cx = emu(image.width)
        let cy = emu(image.height)
        return """

                <w:drawing>
                    <wp:inline distT="0" distB="0" distL="0" distR="0">
                        <wp:extent cx="\(cx)" cy="\(cy)"/>
                        <wp:docPr id="\(docPrId)" name="Picture \(docPrId)"/>
                        <a:graphic>
                            <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                                <pic:pic>
                                    <pic:nvPicPr><pic:cNvPr id="\(docPrId)" name="image\(docPrId)"/><pic:cNvPicPr/></pic:nvPicPr>
                                    <pic:blipFill><a:blip r:embed="\(relId)"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill>
                                    <pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="\(cx)" cy="\(cy)"/></a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>
                                </pic:pic>
                            </a:graphicData>
                        </a:graphic>
                    </wp:inline>
                </w:drawing>
        """
    }

    private static func shapeDrawing(_ shape: WriteShape, docPrId: Int) -> String {
        let cx = emu(shape.width)
        let cy = emu(shape.height)
        let preset = shape.kind == .oval ? "ellipse" : "rect"
        let fill: String
        if let hex = sanitizedHex(shape.fillColorHex) {
            fill = "<a:solidFill><a:srgbClr val=\"\(hex)\"/></a:solidFill>"
        } else {
            fill = ""
        }
        return """

                <w:drawing>
                    <wp:inline distT="0" distB="0" distL="0" distR="0">
                        <wp:extent cx="\(cx)" cy="\(cy)"/>
                        <wp:docPr id="\(docPrId)" name="Shape \(docPrId)"/>
                        <a:graphic>
                            <a:graphicData uri="http://schemas.microsoft.com/office/word/2010/wordprocessingShape">
                                <wps:wsp>
                                    <wps:spPr>
                                        <a:xfrm><a:off x="0" y="0"/><a:ext cx="\(cx)" cy="\(cy)"/></a:xfrm>
                                        <a:prstGeom prst="\(preset)"><a:avLst/></a:prstGeom>
                                        \(fill)
                                    </wps:spPr>
                                    <wps:bodyPr/>
                                </wps:wsp>
                            </a:graphicData>
                        </a:graphic>
                    </wp:inline>
                </w:drawing>
        """
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

    static func needsNumbering(_ blocks: [WriteBlock]) -> Bool {
        blocks.contains { block in
            switch block {
            case let .paragraph(paragraph):
                return paragraph.list != nil
            case let .table(table):
                return table.rows.contains { row in
                    row.cells.contains { cell in
                        cell.paragraphs.contains { $0.list != nil }
                    }
                }
            }
        }
    }

    /// Collects the distinct external hyperlink targets in document order and
    /// assigns each a relationship id.
    static func hyperlinkRelations(in blocks: [WriteBlock]) -> [(url: String, relId: String)] {
        var urls: [String] = []
        func collect(_ paragraphs: [WriteParagraph]) {
            for paragraph in paragraphs {
                for run in paragraph.runs {
                    if let url = run.linkURL, !urls.contains(url) {
                        urls.append(url)
                    }
                }
            }
        }
        for block in blocks {
            switch block {
            case let .paragraph(paragraph):
                collect([paragraph])
            case let .table(table):
                for row in table.rows {
                    for cell in row.cells {
                        collect(cell.paragraphs)
                    }
                }
            }
        }
        return urls.enumerated().map { (url: $1, relId: "rIdLink\($0 + 1)") }
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

        if paragraph.pageBreakBefore {
            parts.append("<w:pageBreakBefore/>")
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
            parts.append("<w:spacing \(spacingAttributes.joined(separator: " "))/>")
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
            parts.append("<w:ind \(indentAttributes.joined(separator: " "))/>")
        }

        if let list = paragraph.list {
            let numId = list.kind == .bullet ? 1 : 2
            parts.append("<w:numPr><w:ilvl w:val=\"\(list.level)\"/><w:numId w:val=\"\(numId)\"/></w:numPr>")
        }

        return parts
    }

    private static func sectionProperties(for section: WriteDocumentSection) -> String {
        let w = twips(section.pageSize.width)
        let h = twips(section.pageSize.height)
        let top = twips(section.margins.top)
        let left = twips(section.margins.left)
        let bottom = twips(section.margins.bottom)
        let right = twips(section.margins.right)

        let headerRef = !section.header.isEmpty ? "\n                    <w:headerReference w:type=\"default\" r:id=\"rIdHeader1\"/>" : ""
        let footerRef = !section.footer.isEmpty ? "\n                    <w:footerReference w:type=\"default\" r:id=\"rIdFooter1\"/>" : ""

        return """

                <w:sectPr>\(headerRef)\(footerRef)
                    <w:pgSz w:w="\(w)" w:h="\(h)"/>
                    <w:pgMar w:top="\(top)" w:right="\(right)" w:bottom="\(bottom)" w:left="\(left)" w:header="720" w:footer="720" w:gutter="0"/>
                </w:sectPr>
        """
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

    /// points -> English Metric Units (72 pt = 914400 EMU).
    private static func emu(_ points: Double) -> Int {
        Int((points * 12700.0).rounded())
    }

    static func normalizedExtension(_ ext: String) -> String {
        let lower = ext.lowercased()
        return lower == "jpg" ? "jpeg" : lower
    }

    private static func imageContentType(for ext: String) -> String {
        switch ext.lowercased() {
        case "png": "image/png"
        case "jpg", "jpeg": "image/jpeg"
        case "gif": "image/gif"
        case "bmp": "image/bmp"
        case "tif", "tiff": "image/tiff"
        default: "application/octet-stream"
        }
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
