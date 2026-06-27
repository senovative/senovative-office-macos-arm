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
        let parsed: WriteDocumentModel
        if typeName == OfficeFileType.docx.contentTypeIdentifier {
            parsed = try OOXMLEngine.readWord(from: data)
        } else if typeName == OfficeFileType.doc.contentTypeIdentifier {
            let archive = try CFBArchive(data: data)
            let parser = try MSDocParser(archive: archive)
            parsed = try parser.parse()
        } else {
            throw SenovativeDocumentError.unsupportedFormat(typeName)
        }

        let name = fileURL?.lastPathComponent ?? String(localized: "Document")
        var model = parsed
        model.title = name
        state.loadModel(model, status: String(localized: "Opened \(name)"))
    }

    override func printDocument(_ sender: Any?) {
        guard let viewController = windowControllers.first?.contentViewController as? WriteViewController,
              let printable = viewController.printableView else {
            super.printDocument(sender)
            return
        }

        printable.layoutSubtreeIfNeeded()
        let info = (printInfo.copy() as? NSPrintInfo) ?? NSPrintInfo()
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isHorizontallyCentered = true
        info.isVerticallyCentered = false

        let operation = NSPrintOperation(view: printable, printInfo: info)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        if let window = viewController.view.window {
            operation.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
        } else {
            operation.run()
        }
    }

    override func data(ofType typeName: String) throws -> Data {
        if typeName == OfficeFileType.docx.contentTypeIdentifier {
            return try OOXMLEngine.writeWord(model: state.model)
        } else if typeName == OfficeFileType.doc.contentTypeIdentifier {
            return try MSDocWriter.writeDoc(model: state.model)
        } else {
            throw SenovativeDocumentError.unsupportedFormat(typeName)
        }
    }
}
