import Foundation

public enum OOXMLEngine {
    public static func readWord(from data: Data) throws -> WriteDocumentModel {
        let archive = try OOXMLArchive(data: data)

        guard let documentData = try archive.readPart(path: "word/document.xml") else {
            throw SenovativeDocumentError.fileCorrupted("Missing word/document.xml")
        }

        // Resolve hyperlink (r:id) and image (r:embed) relationship ids.
        var relationships: [String: String] = [:]
        if let relsData = try? archive.readPart(path: "word/_rels/document.xml.rels") {
            relationships = RelationshipParser().parse(data: relsData)
        }
        let imageResolver: (String) -> (data: Data, fileExtension: String)? = { relId in
            guard let target = relationships[relId] else { return nil }
            let path = target.hasPrefix("/") ? String(target.dropFirst()) : "word/\(target)"
            guard let bytes = (try? archive.readPart(path: path)) ?? nil else { return nil }
            let ext = (target as NSString).pathExtension.lowercased()
            return (bytes, ext.isEmpty ? "png" : ext)
        }
        let parser = WordprocessingMLParser(
            hyperlinkResolver: { relationships[$0] },
            imageResolver: imageResolver
        )
        let result = try parser.parse(data: documentData)
        var section = result.section

        if let headerData = try? archive.readPart(path: "word/header1.xml") {
            section.header = try WordprocessingMLParser().parseParagraphs(data: headerData)
        }

        if let footerData = try? archive.readPart(path: "word/footer1.xml") {
            section.footer = try WordprocessingMLParser().parseParagraphs(data: footerData)
        }

        return WriteDocumentModel(title: "Parsed Document", blocks: result.blocks, section: section)
    }

    public static func writeWord(model: WriteDocumentModel) throws -> Data {
        let archive = try OOXMLArchive(mode: .create)

        let needsNumbering = WordprocessingMLWriter.needsNumbering(model.blocks)
        let hasHeader = !model.section.header.isEmpty
        let hasFooter = !model.section.footer.isEmpty
        let linkRelations = WordprocessingMLWriter.hyperlinkRelations(in: model.blocks)

        // Serialize the body first; it tells us which pictures need writing.
        let document = WordprocessingMLWriter.document(blocks: model.blocks, section: model.section, linkRelations: linkRelations)
        let imageRelations = document.images
        let imageExtensions = Set(imageRelations.map { ($0.partName as NSString).pathExtension })

        try archive.writePart(path: "[Content_Types].xml", data: WordprocessingMLWriter.contentTypes(includeNumbering: needsNumbering, hasHeader: hasHeader, hasFooter: hasFooter, imageExtensions: imageExtensions))
        try archive.writePart(path: "_rels/.rels", data: WordprocessingMLWriter.rootRels())
        try archive.writePart(path: "word/_rels/document.xml.rels", data: WordprocessingMLWriter.documentRels(includeNumbering: needsNumbering, hasHeader: hasHeader, hasFooter: hasFooter, linkRelations: linkRelations, imageRelations: imageRelations))

        if needsNumbering {
            try archive.writePart(path: "word/numbering.xml", data: WordprocessingMLWriter.numbering())
        }
        if hasHeader {
            try archive.writePart(path: "word/header1.xml", data: WordprocessingMLWriter.header(paragraphs: model.section.header))
        }
        if hasFooter {
            try archive.writePart(path: "word/footer1.xml", data: WordprocessingMLWriter.footer(paragraphs: model.section.footer))
        }

        for relation in imageRelations {
            try archive.writePart(path: "word/\(relation.partName)", data: relation.image.data)
        }

        try archive.writePart(path: "word/document.xml", data: document.xml)

        return archive.data
    }
}
