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
    let result = try WordprocessingMLParser().parse(data: Data(xml.utf8))
    let paragraphs = result.paragraphs

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
