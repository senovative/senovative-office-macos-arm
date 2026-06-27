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
    let paragraphs = try WordprocessingMLParser().parse(data: Data(xml.utf8))

    #expect(paragraphs.count == 1)
    #expect(paragraphs[0].runs.count == 1)
    #expect(paragraphs[0].runs[0].text == "not bold")
    #expect(!paragraphs[0].runs[0].bold)
}
