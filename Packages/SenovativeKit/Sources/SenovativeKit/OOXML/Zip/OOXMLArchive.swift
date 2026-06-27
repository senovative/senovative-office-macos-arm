import Foundation
import ZIPFoundation

public enum OOXMLArchiveError: Error {
    case invalidArchive
    case partNotFound(String)
    case writeFailed(String)
}

public class OOXMLArchive {
    private var archive: Archive
    
    public init(data: Data) throws {
        self.archive = try Archive(data: data, accessMode: .read)
    }
    
    public init(mode: Archive.AccessMode) throws {
        self.archive = try Archive(accessMode: mode)
    }
    
    public var data: Data {
        return archive.data ?? Data()
    }

    public var partPaths: [String] {
        archive.map(\.path)
    }

    public func readAllParts(maxPartSize: Int = 50 * 1024 * 1024) throws -> [String: Data] {
        var parts: [String: Data] = [:]
        for entry in archive where entry.type == .file {
            if entry.uncompressedSize > maxPartSize {
                throw SenovativeDocumentError.fileCorrupted("OOXML part too large: \(entry.path)")
            }
            parts[entry.path] = try readPart(path: entry.path)
        }
        return parts
    }
    
    public func readPart(path: String) throws -> Data? {
        guard let entry = archive[path] else { return nil }
        var partData = Data()
        _ = try archive.extract(entry, skipCRC32: false, progress: nil) { data in
            partData.append(data)
        }
        return partData
    }
    
    public func writePart(path: String, data: Data) throws {
        try archive.addEntry(with: path, type: .file, uncompressedSize: Int64(data.count), provider: { position, size in
            return data.subdata(in: Int(position)..<Int(position + Int64(size)))
        })
    }
}
