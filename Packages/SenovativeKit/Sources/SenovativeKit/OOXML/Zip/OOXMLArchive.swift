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
        guard let arch = Archive(data: data, accessMode: .read) else {
            throw OOXMLArchiveError.invalidArchive
        }
        self.archive = arch
    }
    
    public init(mode: Archive.AccessMode) throws {
        guard let arch = Archive(accessMode: mode) else {
            throw OOXMLArchiveError.invalidArchive
        }
        self.archive = arch
    }
    
    public var data: Data {
        return archive.data ?? Data()
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
