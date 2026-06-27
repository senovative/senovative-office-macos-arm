import Foundation

/// A named stream to be written into a Compound File Binary container.
public struct CFBStream {
    public let name: String
    public let data: Data

    public init(name: String, data: Data) {
        self.name = name
        self.data = data
    }
}

/// Serializes streams into a [MS-CFB] compound file (512-byte sectors, major
/// version 3). To avoid the mini-FAT machinery every stream is stored as a
/// standard stream: stream data is padded so that its recorded size is at least
/// the mini-stream cutoff (4096) and a multiple of the sector size. The trailing
/// padding is slack that consumers ignore (the FIB/piece-table define the real
/// extents inside the WordDocument/Table streams).
public enum CFBWriter {
    private static let sectorSize = 512
    private static let miniStreamCutoff = 4096
    private static let freeSector: UInt32 = 0xFFFFFFFF
    private static let endOfChain: UInt32 = 0xFFFFFFFE
    private static let fatSector: UInt32 = 0xFFFFFFFD
    private static let noStream: UInt32 = 0xFFFFFFFF

    public static func write(streams: [CFBStream]) throws -> Data {
        // Pad each stream to a sector multiple of at least the cutoff so it is
        // classified as a standard stream by readers.
        let stored = streams.map { stream -> (name: String, data: Data) in
            var padded = stream.data
            let minLength = max(miniStreamCutoff, sectorSize)
            if padded.count < minLength {
                padded.append(Data(count: minLength - padded.count))
            }
            if padded.count % sectorSize != 0 {
                padded.append(Data(count: sectorSize - (padded.count % sectorSize)))
            }
            return (stream.name, padded)
        }
        // Directory entries: index 0 is the Root Entry, then streams ordered by
        // the CFB sort key so the sibling chain is a valid binary search tree.
        let orderedStreams = stored.sorted { cfbLess($0.name, $1.name) }

        let directoryEntryCount = orderedStreams.count + 1
        let directoryBytes = roundUp(directoryEntryCount * 128, to: sectorSize)
        let directorySectors = directoryBytes / sectorSize
        let streamSectorCounts = orderedStreams.map { $0.data.count / sectorSize }
        let totalDataSectors = directorySectors + streamSectorCounts.reduce(0, +)

        // FAT sector count depends on the total, which includes the FAT itself.
        var fatSectors = 1
        while true {
            let total = fatSectors + totalDataSectors
            let needed = roundUp(total, to: sectorSize / 4) / (sectorSize / 4)
            if needed <= fatSectors { break }
            fatSectors = needed
        }

        // Assign sector indices: [FAT][directory][streams...].
        let directoryStart = fatSectors
        var nextSector = directoryStart + directorySectors
        var streamStarts: [Int] = []
        for count in streamSectorCounts {
            streamStarts.append(count > 0 ? nextSector : Int(endOfChain))
            nextSector += count
        }
        let totalSectors = nextSector

        // Build the FAT.
        var fat = [UInt32](repeating: freeSector, count: fatSectors * (sectorSize / 4))
        for i in 0..<fatSectors { fat[i] = fatSector }
        chain(&fat, start: directoryStart, count: directorySectors)
        for (index, start) in streamStarts.enumerated() where streamSectorCounts[index] > 0 {
            chain(&fat, start: start, count: streamSectorCounts[index])
        }

        // Assemble the file: header + every sector.
        var file = Data(count: sectorSize * (1 + totalSectors))
        writeHeader(into: &file, fatSectors: fatSectors, directoryStart: directoryStart)

        // FAT sectors.
        var fatBytes = Data(capacity: fat.count * 4)
        for entry in fat { fatBytes.appendUInt32LE(entry) }
        place(fatBytes, into: &file, atSector: 0)

        // Directory sectors.
        var directory = Data(capacity: directoryBytes)
        directory.append(directoryEntry(
            name: "Root Entry",
            type: 5,
            startingSector: endOfChain,
            size: 0,
            left: noStream,
            right: noStream,
            child: orderedStreams.isEmpty ? noStream : 1
        ))
        for (index, stream) in orderedStreams.enumerated() {
            let right = index + 1 < orderedStreams.count ? UInt32(index + 2) : noStream
            directory.append(directoryEntry(
                name: stream.name,
                type: 2,
                startingSector: UInt32(streamStarts[index]),
                size: UInt64(stream.data.count),
                left: noStream,
                right: right,
                child: noStream
            ))
        }
        if directory.count < directoryBytes {
            directory.append(Data(count: directoryBytes - directory.count))
        }
        place(directory, into: &file, atSector: directoryStart)

        // Stream sectors.
        for (index, stream) in orderedStreams.enumerated() where streamSectorCounts[index] > 0 {
            place(stream.data, into: &file, atSector: streamStarts[index])
        }

        return file
    }

    private static func chain(_ fat: inout [UInt32], start: Int, count: Int) {
        guard count > 0 else { return }
        for i in 0..<count {
            fat[start + i] = i == count - 1 ? endOfChain : UInt32(start + i + 1)
        }
    }

    private static func place(_ bytes: Data, into file: inout Data, atSector sector: Int) {
        let offset = sectorSize + sector * sectorSize
        file.replaceSubrange(offset..<offset + bytes.count, with: bytes)
    }

    private static func writeHeader(into file: inout Data, fatSectors: Int, directoryStart: Int) {
        var header = Data(capacity: sectorSize)
        header.append(contentsOf: [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]) // signature
        header.append(Data(count: 16)) // CLSID
        header.appendUInt16LE(0x003E)  // minor version
        header.appendUInt16LE(0x0003)  // major version (512-byte sectors)
        header.appendUInt16LE(0xFFFE)  // byte order
        header.appendUInt16LE(0x0009)  // sector shift
        header.appendUInt16LE(0x0006)  // mini sector shift
        header.append(Data(count: 6))  // reserved
        header.appendUInt32LE(0)       // number of directory sectors (0 for v3)
        header.appendUInt32LE(UInt32(fatSectors))
        header.appendUInt32LE(UInt32(directoryStart))
        header.appendUInt32LE(0)       // transaction signature
        header.appendUInt32LE(UInt32(miniStreamCutoff))
        header.appendUInt32LE(endOfChain) // first mini FAT sector
        header.appendUInt32LE(0)          // number of mini FAT sectors
        header.appendUInt32LE(endOfChain) // first DIFAT sector
        header.appendUInt32LE(0)          // number of DIFAT sectors
        for i in 0..<109 {
            header.appendUInt32LE(i < fatSectors ? UInt32(i) : freeSector)
        }
        file.replaceSubrange(0..<header.count, with: header)
    }

    private static func directoryEntry(
        name: String,
        type: UInt8,
        startingSector: UInt32,
        size: UInt64,
        left: UInt32,
        right: UInt32,
        child: UInt32
    ) -> Data {
        var entry = Data(count: 128)
        let nameUTF16 = Array(name.utf16)
        var nameBytes = Data()
        for unit in nameUTF16 { nameBytes.appendUInt16LE(unit) }
        nameBytes.appendUInt16LE(0) // null terminator
        if nameBytes.count > 64 { nameBytes = nameBytes.prefix(64) }
        entry.replaceSubrange(0..<nameBytes.count, with: nameBytes)
        entry.writeUInt16LE(UInt16(nameBytes.count), at: 64)
        entry[66] = type
        entry[67] = 1 // color: black
        entry.writeUInt32LE(left, at: 68)
        entry.writeUInt32LE(right, at: 72)
        entry.writeUInt32LE(child, at: 76)
        entry.writeUInt32LE(startingSector, at: 116)
        entry.writeUInt32LE(UInt32(size & 0xFFFFFFFF), at: 120)
        entry.writeUInt32LE(UInt32(size >> 32), at: 124)
        return entry
    }

    /// CFB sort order: shorter UTF-16 names first, then upper-cased code units.
    private static func cfbLess(_ lhs: String, _ rhs: String) -> Bool {
        let a = Array(lhs.uppercased().utf16)
        let b = Array(rhs.uppercased().utf16)
        if a.count != b.count { return a.count < b.count }
        for (x, y) in zip(a, b) where x != y { return x < y }
        return false
    }

    private static func roundUp(_ value: Int, to multiple: Int) -> Int {
        value % multiple == 0 ? value : value + (multiple - value % multiple)
    }
}

extension Data {
    mutating func appendUInt16LE(_ value: UInt16) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
    }

    mutating func appendUInt32LE(_ value: UInt32) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }

    mutating func writeUInt16LE(_ value: UInt16, at offset: Int) {
        self[offset] = UInt8(value & 0xFF)
        self[offset + 1] = UInt8((value >> 8) & 0xFF)
    }

    mutating func writeUInt32LE(_ value: UInt32, at offset: Int) {
        self[offset] = UInt8(value & 0xFF)
        self[offset + 1] = UInt8((value >> 8) & 0xFF)
        self[offset + 2] = UInt8((value >> 16) & 0xFF)
        self[offset + 3] = UInt8((value >> 24) & 0xFF)
    }
}
