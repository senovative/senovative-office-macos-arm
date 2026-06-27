import Foundation
import Testing
@testable import SenovativeKit

@Test func docxFileTypeIsRegistered() {
    #expect(OfficeFileType.docx.filenameExtension == "docx")
    #expect(OfficeFileType.docx.contentTypeIdentifier == "org.openxmlformats.wordprocessingml.document")
    #expect(OfficeFileType.docx.kind == .write)
}

@Test func wordRoundTripPreservesFormattedRuns() throws {
    let model = WriteDocumentModel(title: "Sample", paragraphs: [
        WriteParagraph(runs: [
            WriteRun(text: "Hello ", bold: true),
            WriteRun(text: "world", italic: true, underline: true),
        ]),
        WriteParagraph(),
        WriteParagraph(runs: [WriteRun(text: "Plain line")]),
    ])

    let data = try OOXMLEngine.writeWord(model: model)
    let parsed = try OOXMLEngine.readWord(from: data)

    #expect(parsed.paragraphs.count == 3)

    let first = parsed.paragraphs[0].runs
    #expect(first.count == 2)
    #expect(first[0].text == "Hello ")
    #expect(first[0].bold)
    #expect(!first[0].italic)
    #expect(first[1].text == "world")
    #expect(first[1].italic)
    #expect(first[1].underline)
    #expect(!first[1].bold)

    #expect(parsed.paragraphs[1].runs.isEmpty)
    #expect(parsed.paragraphs[2].plainText == "Plain line")
}

@Test func wordRoundTripEscapesSpecialCharacters() throws {
    let model = WriteDocumentModel(
        title: "Escaping",
        paragraphs: [WriteParagraph(runs: [WriteRun(text: "a < b & c > d")])]
    )

    let data = try OOXMLEngine.writeWord(model: model)
    let parsed = try OOXMLEngine.readWord(from: data)

    #expect(parsed.plainText == "a < b & c > d")
}

@Test func parserIgnoresParagraphMarkRunProperties() throws {
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <w:body>
        <w:p>
          <w:pPr><w:rPr><w:b/></w:rPr></w:pPr>
          <w:r><w:t>not bold</w:t></w:r>
        </w:p>
      </w:body>
    </w:document>
    """
    let paragraphs = try WordprocessingMLParser().parseParagraphs(data: Data(xml.utf8))

    #expect(paragraphs.count == 1)
    #expect(paragraphs[0].runs.count == 1)
    #expect(paragraphs[0].runs[0].text == "not bold")
    #expect(!paragraphs[0].runs[0].bold)
}

@Test func wordRoundTripPreservesRichRunFormatting() throws {
    let model = WriteDocumentModel(title: "Rich Runs", paragraphs: [
        WriteParagraph(runs: [
            WriteRun(
                text: "Styled",
                bold: true,
                italic: true,
                underline: true,
                fontFamily: "Helvetica",
                fontSize: 18,
                textColorHex: "336699",
                highlightColorHex: "FFF2CC",
                verticalAlignment: .superscript
            ),
            WriteRun(
                text: " low",
                fontFamily: "Times New Roman",
                fontSize: 11,
                textColorHex: "990000",
                verticalAlignment: .subscripted
            ),
        ]),
    ])

    let data = try OOXMLEngine.writeWord(model: model)
    let parsed = try OOXMLEngine.readWord(from: data)
    let runs = parsed.paragraphs[0].runs

    #expect(runs[0].fontFamily == "Helvetica")
    #expect(runs[0].fontSize == 18)
    #expect(runs[0].textColorHex == "336699")
    #expect(runs[0].highlightColorHex == "FFF2CC")
    #expect(runs[0].verticalAlignment == .superscript)
    #expect(runs[1].fontFamily == "Times New Roman")
    #expect(runs[1].fontSize == 11)
    #expect(runs[1].textColorHex == "990000")
    #expect(runs[1].verticalAlignment == .subscripted)
}

@Test func wordRoundTripPreservesParagraphFormattingAndLists() throws {
    let model = WriteDocumentModel(title: "Paragraphs", paragraphs: [
        WriteParagraph(
            runs: [WriteRun(text: "Centered")],
            alignment: .center,
            lineSpacing: 18,
            spacingBefore: 6,
            spacingAfter: 12,
            leftIndent: 24,
            firstLineIndent: 12
        ),
        WriteParagraph(
            runs: [WriteRun(text: "Bullet")],
            list: WriteListStyle(kind: .bullet)
        ),
        WriteParagraph(
            runs: [WriteRun(text: "Number")],
            alignment: .right,
            list: WriteListStyle(kind: .numbered)
        ),
    ])

    let data = try OOXMLEngine.writeWord(model: model)
    let parsed = try OOXMLEngine.readWord(from: data)

    #expect(parsed.paragraphs[0].alignment == .center)
    #expect(parsed.paragraphs[0].lineSpacing == 18)
    #expect(parsed.paragraphs[0].spacingBefore == 6)
    #expect(parsed.paragraphs[0].spacingAfter == 12)
    #expect(parsed.paragraphs[0].leftIndent == 24)
    #expect(parsed.paragraphs[0].firstLineIndent == 12)
    #expect(parsed.paragraphs[1].list == WriteListStyle(kind: .bullet))
    #expect(parsed.paragraphs[2].alignment == .right)
    #expect(parsed.paragraphs[2].list == WriteListStyle(kind: .numbered))
}

@Test func wordRoundTripPreservesHyperlinks() throws {
    let model = WriteDocumentModel(title: "Links", paragraphs: [
        WriteParagraph(runs: [
            WriteRun(text: "Visit "),
            WriteRun(text: "Senovative", bold: true, linkURL: "https://senovative.io"),
            WriteRun(text: " now"),
        ]),
    ])

    let data = try OOXMLEngine.writeWord(model: model)
    let parsed = try OOXMLEngine.readWord(from: data)
    let runs = parsed.paragraphs[0].runs

    #expect(runs.count == 3)
    #expect(runs[1].text == "Senovative")
    #expect(runs[1].bold)
    #expect(runs[1].linkURL == "https://senovative.io")
    #expect(runs[0].linkURL == nil)
    #expect(runs[2].linkURL == nil)
}

@Test func wordRoundTripPreservesTabs() throws {
    let model = WriteDocumentModel(title: "Tabs", paragraphs: [
        WriteParagraph(runs: [WriteRun(text: "Name\tValue")]),
    ])

    let data = try OOXMLEngine.writeWord(model: model)
    let parsed = try OOXMLEngine.readWord(from: data)

    #expect(parsed.paragraphs[0].runs[0].text == "Name\tValue")
}

@Test func wordRoundTripPreservesTables() throws {
    let table = WriteTable(rows: [
        WriteTableRow(cells: [
            WriteTableCell(paragraphs: [WriteParagraph(runs: [WriteRun(text: "A1")])]),
            WriteTableCell(paragraphs: [WriteParagraph(runs: [WriteRun(text: "B1", bold: true)])]),
        ]),
        WriteTableRow(cells: [
            WriteTableCell(paragraphs: [WriteParagraph(runs: [WriteRun(text: "A2")])]),
            WriteTableCell(paragraphs: [WriteParagraph(runs: [WriteRun(text: "B2")])]),
        ]),
    ])
    let model = WriteDocumentModel(title: "Grid", blocks: [
        .paragraph(WriteParagraph(runs: [WriteRun(text: "Before")])),
        .table(table),
        .paragraph(WriteParagraph(runs: [WriteRun(text: "After")])),
    ])

    let data = try OOXMLEngine.writeWord(model: model)
    let parsed = try OOXMLEngine.readWord(from: data)

    #expect(parsed.blocks.count == 3)
    guard case let .paragraph(before) = parsed.blocks[0] else { Issue.record("expected paragraph"); return }
    #expect(before.plainText == "Before")

    guard case let .table(parsedTable) = parsed.blocks[1] else { Issue.record("expected table"); return }
    #expect(parsedTable.rows.count == 2)
    #expect(parsedTable.columnCount == 2)
    #expect(parsedTable.rows[0].cells[0].plainText == "A1")
    #expect(parsedTable.rows[0].cells[1].plainText == "B1")
    #expect(parsedTable.rows[0].cells[1].paragraphs[0].runs[0].bold)
    #expect(parsedTable.rows[1].cells[1].plainText == "B2")

    guard case let .paragraph(after) = parsed.blocks[2] else { Issue.record("expected paragraph"); return }
    #expect(after.plainText == "After")
}

// A minimal valid 1x1 PNG.
private let onePixelPNG = Data([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
])

@Test func wordRoundTripPreservesInlineImage() throws {
    let image = WriteImage(data: onePixelPNG, fileExtension: "png", width: 120, height: 90)
    let model = WriteDocumentModel(title: "Picture", paragraphs: [
        WriteParagraph(runs: [WriteRun(text: "Logo: "), WriteRun(text: "", image: image)]),
    ])

    let data = try OOXMLEngine.writeWord(model: model)
    let parsed = try OOXMLEngine.readWord(from: data)
    let runs = parsed.paragraphs[0].runs

    let pictureRun = try #require(runs.first { $0.image != nil })
    let parsedImage = try #require(pictureRun.image)
    #expect(parsedImage.data == onePixelPNG)
    #expect(parsedImage.fileExtension == "png")
    #expect(Int(parsedImage.width.rounded()) == 120)
    #expect(Int(parsedImage.height.rounded()) == 90)
}

@Test func wordRoundTripPreservesShape() throws {
    let shape = WriteShape(kind: .oval, width: 80, height: 60, fillColorHex: "FF8800")
    let model = WriteDocumentModel(title: "Shape", paragraphs: [
        WriteParagraph(runs: [WriteRun(text: "", shape: shape)]),
    ])

    let data = try OOXMLEngine.writeWord(model: model)
    let parsed = try OOXMLEngine.readWord(from: data)

    let shapeRun = try #require(parsed.paragraphs[0].runs.first { $0.shape != nil })
    let parsedShape = try #require(shapeRun.shape)
    #expect(parsedShape.kind == .oval)
    #expect(Int(parsedShape.width.rounded()) == 80)
    #expect(Int(parsedShape.height.rounded()) == 60)
    #expect(parsedShape.fillColorHex == "FF8800")
}

@Test func ooxmlRoundTripPreservesUnknownPartsAndPackageRelationships() throws {
    let base = try OOXMLEngine.writeWord(model: WriteDocumentModel(title: "Base", paragraphs: [
        WriteParagraph(runs: [WriteRun(text: "Keep known body")]),
    ]))

    let source = try OOXMLArchive(data: base)
    let archive = try OOXMLArchive(mode: .create)
    for path in source.partPaths {
        if let data = try source.readPart(path: path), path != "[Content_Types].xml", path != "_rels/.rels" {
            try archive.writePart(path: path, data: data)
        }
    }

    let contentTypes = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
        <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
        <Default Extension="xml" ContentType="application/xml"/>
        <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
        <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
        <Override PartName="/docProps/core.xml" ContentType="application/vnd.openxmlformats-package.core-properties+xml"/>
    </Types>
    """
    let rootRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
        <Relationship Id="rIdCore" Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="docProps/core.xml"/>
    </Relationships>
    """
    let styles = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <w:style w:type="paragraph" w:styleId="CustomStyle"/>
    </w:styles>
    """
    let core = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <cp:coreProperties xmlns:cp="http://schemas.openxmlformats.org/package/2006/metadata/core-properties"/>
    """

    try archive.writePart(path: "[Content_Types].xml", data: Data(contentTypes.utf8))
    try archive.writePart(path: "_rels/.rels", data: Data(rootRels.utf8))
    try archive.writePart(path: "word/styles.xml", data: Data(styles.utf8))
    try archive.writePart(path: "docProps/core.xml", data: Data(core.utf8))

    var model = try OOXMLEngine.readWord(from: archive.data)
    model.blocks = [.paragraph(WriteParagraph(runs: [WriteRun(text: "Edited body")]))]
    let saved = try OOXMLEngine.writeWord(model: model)
    let savedArchive = try OOXMLArchive(data: saved)

    #expect(try savedArchive.readPart(path: "word/styles.xml") == Data(styles.utf8))
    #expect(try savedArchive.readPart(path: "docProps/core.xml") == Data(core.utf8))

    let savedContentTypesData = try #require(try savedArchive.readPart(path: "[Content_Types].xml"))
    let savedContentTypes = String(data: savedContentTypesData, encoding: .utf8)
    #expect(savedContentTypes?.contains("/word/styles.xml") == true)
    #expect(savedContentTypes?.contains("/docProps/core.xml") == true)

    let savedRootRelsData = try #require(try savedArchive.readPart(path: "_rels/.rels"))
    let savedRootRels = String(data: savedRootRelsData, encoding: .utf8)
    #expect(savedRootRels?.contains("rIdCore") == true)
    #expect(savedRootRels?.contains("docProps/core.xml") == true)

    let reparsed = try OOXMLEngine.readWord(from: saved)
    #expect(reparsed.plainText == "Edited body")
}

@Test func ooxmlRoundTripPreservesUnknownDocumentRelationships() throws {
    let base = try OOXMLEngine.writeWord(model: WriteDocumentModel(title: "Base", paragraphs: [
        WriteParagraph(runs: [WriteRun(text: "Has rels")]),
    ]))
    let source = try OOXMLArchive(data: base)
    let archive = try OOXMLArchive(mode: .create)
    for path in source.partPaths {
        if let data = try source.readPart(path: path), path != "word/_rels/document.xml.rels" {
            try archive.writePart(path: path, data: data)
        }
    }

    let documentRels = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        <Relationship Id="rIdUnknownChart" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart" Target="charts/chart1.xml"/>
    </Relationships>
    """
    try archive.writePart(path: "word/_rels/document.xml.rels", data: Data(documentRels.utf8))
    try archive.writePart(path: "word/charts/chart1.xml", data: Data("<c:chart/>".utf8))

    var model = try OOXMLEngine.readWord(from: archive.data)
    model.blocks = [
        .paragraph(WriteParagraph(runs: [
            WriteRun(text: "Chart rel plus "),
            WriteRun(text: "link", linkURL: "https://example.com"),
        ])),
    ]
    let saved = try OOXMLEngine.writeWord(model: model)
    let savedArchive = try OOXMLArchive(data: saved)

    #expect(try savedArchive.readPart(path: "word/charts/chart1.xml") == Data("<c:chart/>".utf8))

    let savedRelsData = try #require(try savedArchive.readPart(path: "word/_rels/document.xml.rels"))
    let savedRels = String(data: savedRelsData, encoding: .utf8)
    #expect(savedRels?.contains("rIdUnknownChart") == true)
    #expect(savedRels?.contains("charts/chart1.xml") == true)
    #expect(savedRels?.contains("https://example.com") == true)
}

@Test func cfbWriterRoundTripsStreams() throws {
    let wordData = Data((0..<100).map { UInt8($0 % 256) })
    let tableData = Data("piece-table-bytes".utf8)
    let container = try CFBWriter.write(streams: [
        CFBStream(name: "WordDocument", data: wordData),
        CFBStream(name: "1Table", data: tableData),
    ])

    let archive = try CFBArchive(data: container)
    let readWord = try archive.readStream(named: "WordDocument")
    let readTable = try archive.readStream(named: "1Table")

    // Streams are padded; the original content is preserved as a prefix.
    #expect(readWord.prefix(wordData.count) == wordData)
    #expect(readTable.prefix(tableData.count) == tableData)
}

@Test func docRoundTripPreservesTextFormattingAndAlignment() throws {
    let model = WriteDocumentModel(title: "Legacy", paragraphs: [
        WriteParagraph(runs: [
            WriteRun(text: "Hello "),
            WriteRun(text: "bold", bold: true),
            WriteRun(text: " and "),
            WriteRun(text: "italic", italic: true),
        ]),
        WriteParagraph(runs: [WriteRun(text: "Centered")], alignment: .center),
        WriteParagraph(runs: [WriteRun(text: "Right side")], alignment: .right),
    ])

    let data = try MSDocWriter.writeDoc(model: model)
    let parsed = try MSDocParser(archive: try CFBArchive(data: data)).parse()

    #expect(parsed.paragraphs.count == 3)
    #expect(parsed.paragraphs[0].plainText == "Hello bold and italic")
    #expect(parsed.paragraphs[1].plainText == "Centered")
    #expect(parsed.paragraphs[1].alignment == .center)
    #expect(parsed.paragraphs[2].plainText == "Right side")
    #expect(parsed.paragraphs[2].alignment == .right)

    let firstRuns = parsed.paragraphs[0].runs
    #expect(firstRuns.first { $0.bold }?.text == "bold")
    #expect(firstRuns.first { $0.italic }?.text == "italic")
}

@Test func docRoundTripHandlesPlainSingleParagraph() throws {
    let model = WriteDocumentModel(title: "Plain", paragraphs: [
        WriteParagraph(runs: [WriteRun(text: "Just text")]),
    ])
    let data = try MSDocWriter.writeDoc(model: model)
    let parsed = try MSDocParser(archive: try CFBArchive(data: data)).parse()

    #expect(parsed.paragraphs.first?.plainText == "Just text")
}

@Test func documentStatisticsIncludeParagraphsAndTables() {
    let model = WriteDocumentModel(title: "Stats", blocks: [
        .paragraph(WriteParagraph(runs: [WriteRun(text: "Hello world")])),
        .table(WriteTable(rows: [
            WriteTableRow(cells: [
                WriteTableCell(paragraphs: [WriteParagraph(runs: [WriteRun(text: "One cell")])]),
                WriteTableCell(paragraphs: [WriteParagraph(runs: [WriteRun(text: "Two")])]),
            ]),
        ])),
        .paragraph(WriteParagraph(runs: [WriteRun(text: "Final line")]))
    ])

    #expect(model.fullPlainText == "Hello world\nOne cell\tTwo\nFinal line")
    #expect(model.statistics.wordCount == 7)
    #expect(model.statistics.characterCount == 35)
    #expect(model.statistics.characterCountExcludingWhitespace == 29)
    #expect(model.statistics.paragraphCount == 4)
    #expect(model.statistics.tableCount == 1)
}

@Test func namedStylesApplyParagraphAndRunFormatting() {
    let paragraph = WriteParagraph(runs: [WriteRun(text: "Section")], list: WriteListStyle(kind: .bullet))
    let heading = WriteNamedStyle.heading1.applying(to: paragraph)

    #expect(heading.list == nil)
    #expect(heading.spacingBefore == 18)
    #expect(heading.spacingAfter == 8)
    #expect(heading.runs.first?.bold == true)
    #expect(heading.runs.first?.fontSize == 22)

    let quote = WriteNamedStyle.quote.applying(to: paragraph)
    #expect(quote.leftIndent == 36)
    #expect(quote.runs.first?.italic == true)
    #expect(quote.runs.first?.textColorHex == "555555")
}

@Test func documentTemplatesProvideUsableStartingContent() {
    #expect(WriteDocumentTemplate.allCases.count == 4)
    #expect(WriteDocumentTemplate.report.model.statistics.wordCount > 10)
    #expect(WriteDocumentTemplate.meetingNotes.model.paragraphs.contains { $0.list?.kind == .numbered })
    #expect(WriteDocumentTemplate.blank.model.paragraphs.count == 1)
}
