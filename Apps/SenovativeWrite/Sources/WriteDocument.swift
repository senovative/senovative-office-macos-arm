import AppKit
import SenovativeKit

@MainActor
final class WriteDocument: NSDocument {
    nonisolated(unsafe) let state = WriteDocumentState()

    override init() {
        super.init()
        hasUndoManager = true
        state.document = self
    }

    override class var autosavesInPlace: Bool {
        true
    }

    override func makeWindowControllers() {
        let controller = WriteWindowController(document: self)
        addWindowController(controller)
    }

    override func read(from data: Data, ofType typeName: String) throws {
        guard typeName == OfficeFileType.docx.contentTypeIdentifier else {
            throw SenovativeDocumentError.unsupportedFormat(typeName)
        }

        let parsed = try OOXMLEngine.readWord(from: data)
        let name = fileURL?.lastPathComponent ?? String(localized: "Document")
        var model = parsed
        model.title = name
        state.loadModel(model, status: String(localized: "Opened \(name)"))
    }

    override func data(ofType typeName: String) throws -> Data {
        guard typeName == OfficeFileType.docx.contentTypeIdentifier else {
            throw SenovativeDocumentError.unsupportedFormat(typeName)
        }

        return try OOXMLEngine.writeWord(model: state.model)
    }
}
