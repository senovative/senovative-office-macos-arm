import Foundation

public enum SenovativeDocumentError: LocalizedError, Sendable {
    case unsupportedFormat(String)
    case ooxmlEngineUnavailable
    case fileCorrupted(String)
    case printingUnavailable

    public var errorDescription: String? {
        switch self {
        case let .unsupportedFormat(type):
            "Unsupported document format: \(type)"
        case .ooxmlEngineUnavailable:
            "The OOXML read/write engine has not been implemented yet."
        case let .fileCorrupted(reason):
            "The document is corrupted: \(reason)"
        case .printingUnavailable:
            "The document view is not ready to print."
        }
    }
}
