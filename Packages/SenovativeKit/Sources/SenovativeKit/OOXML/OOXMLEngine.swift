import Foundation

public enum OOXMLEngine {
    public static func readWord(from data: Data) throws -> WriteDocumentModel {
        guard data.count <= OOXMLSafetyLimits.maxPackageSize else {
            throw SenovativeDocumentError.fileCorrupted("DOCX package is too large")
        }

        let archive = try OOXMLArchive(data: data)
        let originalParts = try archive.readAllParts(maxPartSize: OOXMLSafetyLimits.maxPartSize)

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

        return WriteDocumentModel(
            title: "Parsed Document",
            blocks: result.blocks,
            section: section,
            sourcePackage: OOXMLPackageSnapshot(parts: originalParts)
        )
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
        let generatedPaths = generatedPartPaths(
            needsNumbering: needsNumbering,
            hasHeader: hasHeader,
            hasFooter: hasFooter,
            imageRelations: imageRelations
        )

        if let sourcePackage = model.sourcePackage {
            try copyPreservedParts(from: sourcePackage, to: archive, excluding: generatedPaths)
        }

        let generatedContentTypes = WordprocessingMLWriter.contentTypes(
            includeNumbering: needsNumbering,
            hasHeader: hasHeader,
            hasFooter: hasFooter,
            imageExtensions: imageExtensions
        )
        let generatedRootRels = WordprocessingMLWriter.rootRels()
        let generatedDocumentRels = WordprocessingMLWriter.documentRels(
            includeNumbering: needsNumbering,
            hasHeader: hasHeader,
            hasFooter: hasFooter,
            linkRelations: linkRelations,
            imageRelations: imageRelations
        )

        let contentTypes = mergeContentTypes(
            source: model.sourcePackage?.parts["[Content_Types].xml"],
            generated: generatedContentTypes
        )
        let rootRels = mergeRelationships(
            source: model.sourcePackage?.parts["_rels/.rels"],
            generated: generatedRootRels
        )
        let documentRels = mergeRelationships(
            source: model.sourcePackage?.parts["word/_rels/document.xml.rels"],
            generated: generatedDocumentRels
        )

        try archive.writePart(path: "[Content_Types].xml", data: contentTypes)
        try archive.writePart(path: "_rels/.rels", data: rootRels)
        try archive.writePart(path: "word/_rels/document.xml.rels", data: documentRels)

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

    private static func generatedPartPaths(
        needsNumbering: Bool,
        hasHeader: Bool,
        hasFooter: Bool,
        imageRelations: [ImageRelation]
    ) -> Set<String> {
        var paths: Set<String> = [
            "[Content_Types].xml",
            "_rels/.rels",
            "word/_rels/document.xml.rels",
            "word/document.xml",
        ]
        if needsNumbering {
            paths.insert("word/numbering.xml")
        }
        if hasHeader {
            paths.insert("word/header1.xml")
        }
        if hasFooter {
            paths.insert("word/footer1.xml")
        }
        for relation in imageRelations {
            paths.insert("word/\(relation.partName)")
        }
        return paths
    }

    private static func copyPreservedParts(
        from snapshot: OOXMLPackageSnapshot,
        to archive: OOXMLArchive,
        excluding generatedPaths: Set<String>
    ) throws {
        for (path, data) in snapshot.parts where !generatedPaths.contains(path) {
            try archive.writePart(path: path, data: data)
        }
    }

    private static func mergeContentTypes(source: Data?, generated: Data) -> Data {
        guard
            let source,
            var sourceXML = String(data: source, encoding: .utf8),
            let generatedXML = String(data: generated, encoding: .utf8)
        else {
            return generated
        }

        for defaultEntry in xmlLines(named: "Default", in: generatedXML) {
            guard let ext = xmlAttribute("Extension", in: defaultEntry) else { continue }
            if !sourceXML.contains("Extension=\"\(ext)\"") {
                sourceXML = insertXMLLine(defaultEntry, beforeClosingTag: "</Types>", in: sourceXML)
            }
        }

        for overrideEntry in xmlLines(named: "Override", in: generatedXML) {
            guard let partName = xmlAttribute("PartName", in: overrideEntry) else { continue }
            if !sourceXML.contains("PartName=\"\(partName)\"") {
                sourceXML = insertXMLLine(overrideEntry, beforeClosingTag: "</Types>", in: sourceXML)
            }
        }

        return Data(sourceXML.utf8)
    }

    private static func mergeRelationships(source: Data?, generated: Data) -> Data {
        guard
            let source,
            let sourceRelationships = RelationshipListParser().parse(data: source),
            let generatedRelationships = RelationshipListParser().parse(data: generated)
        else {
            return generated
        }

        let generatedIds = Set(generatedRelationships.map(\.id))
        let merged = sourceRelationships.filter { !generatedIds.contains($0.id) } + generatedRelationships
        var xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
        """
        for relationship in merged {
            xml += "\n    \(relationship.xmlElement)"
        }
        xml += "\n</Relationships>"

        return Data(xml.utf8)
    }

    private static func xmlLines(named name: String, in xml: String) -> [String] {
        xml.split(separator: "\n").compactMap { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.hasPrefix("<\(name) ") ? trimmed : nil
        }
    }

    private static func xmlAttribute(_ name: String, in element: String) -> String? {
        let pattern = "\(name)=\""
        guard let start = element.range(of: pattern) else { return nil }
        let valueStart = start.upperBound
        guard let end = element[valueStart...].firstIndex(of: "\"") else { return nil }
        return String(element[valueStart..<end])
    }

    private static func insertXMLLine(_ line: String, beforeClosingTag closingTag: String, in xml: String) -> String {
        guard let range = xml.range(of: closingTag, options: .backwards) else {
            return xml + "\n" + line
        }
        var result = xml
        result.insert(contentsOf: "    \(line)\n", at: range.lowerBound)
        return result
    }
}

private enum OOXMLSafetyLimits {
    static let maxPackageSize = 200 * 1024 * 1024
    static let maxPartSize = 50 * 1024 * 1024
}

private struct RelationshipEntry: Equatable {
    var id: String
    var type: String
    var target: String
    var targetMode: String?

    var xmlElement: String {
        var attributes = "Id=\"\(escape(id))\" Type=\"\(escape(type))\" Target=\"\(escape(target))\""
        if let targetMode {
            attributes += " TargetMode=\"\(escape(targetMode))\""
        }
        return "<Relationship \(attributes)/>"
    }

    private func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

private final class RelationshipListParser: NSObject, XMLParserDelegate {
    private var relationships: [RelationshipEntry] = []

    func parse(data: Data) -> [RelationshipEntry]? {
        relationships = []
        let parser = XMLParser(data: data)
        parser.delegate = self
        return parser.parse() ? relationships : nil
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        guard elementName.hasSuffix("Relationship") || elementName == "Relationship" else { return }
        guard
            let id = attributeDict["Id"],
            let type = attributeDict["Type"],
            let target = attributeDict["Target"]
        else {
            return
        }
        relationships.append(
            RelationshipEntry(
                id: id,
                type: type,
                target: target,
                targetMode: attributeDict["TargetMode"]
            )
        )
    }
}
