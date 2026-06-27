import Foundation

public enum OOXMLEngine {
    public static func readWord(from data: Data) throws -> WriteDocumentModel {
        let archive = try OOXMLArchive(data: data)
        
        guard let documentData = try archive.readPart(path: "word/document.xml") else {
            throw SenovativeDocumentError.fileCorrupted("Missing word/document.xml")
        }
        
        let parser = WordprocessingMLParser()
        let paragraphs = try parser.parse(data: documentData)

        return WriteDocumentModel(title: "Parsed Document", paragraphs: paragraphs)
    }

    public static func writeWord(model: WriteDocumentModel) throws -> Data {
        let archive = try OOXMLArchive(mode: .create)

        try archive.writePart(path: "[Content_Types].xml", data: WordprocessingMLWriter.contentTypes())
        try archive.writePart(path: "_rels/.rels", data: WordprocessingMLWriter.rootRels())

        let documentXml = WordprocessingMLWriter.document(paragraphs: model.paragraphs)
        try archive.writePart(path: "word/document.xml", data: documentXml)
        
        return archive.data
    }
}
