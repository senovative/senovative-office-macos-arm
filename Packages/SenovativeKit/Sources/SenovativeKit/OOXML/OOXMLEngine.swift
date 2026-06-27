import Foundation

public enum OOXMLEngine {
    public static func readWord(from data: Data) throws -> WriteDocumentModel {
        let archive = try OOXMLArchive(data: data)
        
        guard let documentData = try archive.readPart(path: "word/document.xml") else {
            throw SenovativeDocumentError.fileCorrupted("Missing word/document.xml")
        }
        
        let parser = WordprocessingMLParser()
        let result = try parser.parse(data: documentData)
        var section = result.section
        
        if let headerData = try? archive.readPart(path: "word/header1.xml") {
            let headerResult = try WordprocessingMLParser().parse(data: headerData)
            section.header = headerResult.paragraphs
        }
        
        if let footerData = try? archive.readPart(path: "word/footer1.xml") {
            let footerResult = try WordprocessingMLParser().parse(data: footerData)
            section.footer = footerResult.paragraphs
        }
        
        return WriteDocumentModel(title: "Parsed Document", paragraphs: result.paragraphs, section: section)
    }

    public static func writeWord(model: WriteDocumentModel) throws -> Data {
        let archive = try OOXMLArchive(mode: .create)
        
        let needsNumbering = WordprocessingMLWriter.needsNumbering(model.paragraphs)
        let hasHeader = !model.section.header.isEmpty
        let hasFooter = !model.section.footer.isEmpty
        
        try archive.writePart(path: "[Content_Types].xml", data: WordprocessingMLWriter.contentTypes(includeNumbering: needsNumbering, hasHeader: hasHeader, hasFooter: hasFooter))
        try archive.writePart(path: "_rels/.rels", data: WordprocessingMLWriter.rootRels())
        try archive.writePart(path: "word/_rels/document.xml.rels", data: WordprocessingMLWriter.documentRels(includeNumbering: needsNumbering, hasHeader: hasHeader, hasFooter: hasFooter))
        
        if needsNumbering {
            try archive.writePart(path: "word/numbering.xml", data: WordprocessingMLWriter.numbering())
        }
        if hasHeader {
            try archive.writePart(path: "word/header1.xml", data: WordprocessingMLWriter.header(paragraphs: model.section.header))
        }
        if hasFooter {
            try archive.writePart(path: "word/footer1.xml", data: WordprocessingMLWriter.footer(paragraphs: model.section.footer))
        }
        
        let documentXml = WordprocessingMLWriter.document(paragraphs: model.paragraphs, section: model.section)
        try archive.writePart(path: "word/document.xml", data: documentXml)
        
        return archive.data
    }
}
