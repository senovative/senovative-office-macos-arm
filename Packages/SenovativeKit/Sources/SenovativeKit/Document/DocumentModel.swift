import Foundation

public protocol OfficeDocumentModel: Equatable, Sendable {
    var title: String { get set }
}

public enum OfficeDocumentKind: String, CaseIterable, Sendable {
    case write
    case slides
    case sheets
}

public struct OfficeFileType: Equatable, Sendable {
    public let filenameExtension: String
    public let contentTypeIdentifier: String
    public let kind: OfficeDocumentKind

    public init(filenameExtension: String, contentTypeIdentifier: String, kind: OfficeDocumentKind) {
        self.filenameExtension = filenameExtension
        self.contentTypeIdentifier = contentTypeIdentifier
        self.kind = kind
    }
}

public extension OfficeFileType {
    static let docx = OfficeFileType(
        filenameExtension: "docx",
        contentTypeIdentifier: "org.openxmlformats.wordprocessingml.document",
        kind: .write
    )
    
    static let doc = OfficeFileType(
        filenameExtension: "doc",
        contentTypeIdentifier: "com.microsoft.word.doc",
        kind: .write
    )
}
