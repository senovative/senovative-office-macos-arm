import AppKit
import SenovativeKit

final class WriteDocumentState: ObservableObject {
    @Published var model: WriteDocumentModel
    @Published var statusText: String

    /// Bumped every time the model is replaced by an external load (open/new) so
    /// the editor knows to reload its content instead of treating it as user input.
    @Published private(set) var loadToken: Int = 0

    /// Owning document, used to flag the change count when the editor mutates the model.
    weak var document: WriteDocument?

    init(model: WriteDocumentModel = .empty, statusText: String = String(localized: "Ready")) {
        self.model = model
        self.statusText = statusText
    }

    /// Replace the document contents from disk/new. Triggers an editor reload.
    func loadModel(_ model: WriteDocumentModel, status: String) {
        self.model = model
        self.statusText = status
        loadToken += 1
    }
}
