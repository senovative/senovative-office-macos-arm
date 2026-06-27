import Foundation

public struct CFBError: Error, CustomStringConvertible {
    public let description: String
    public init(_ description: String) { self.description = description }
}

public class CFBArchive {
    let data: Data
    
    // Header properties
    private let sectorShift: UInt16
    private let miniSectorShift: UInt16
    private let directorySectorsCount: UInt32
    private let fatSectorsCount: UInt32
    private let firstDirectorySectorLocation: UInt32
    private let minStandardStreamSize: UInt32
    private let firstMiniFatSectorLocation: UInt32
    private let miniFatSectorsCount: UInt32
    private let firstDifatSectorLocation: UInt32
    private let difatSectorsCount: UInt32
    
    // Extracted tables
    private var difat: [UInt32] = []
    private var fat: [UInt32] = []
    private var miniFat: [UInt32] = []
    public private(set) var rootDirectoryEntry: CFBDirectoryEntry!
    public private(set) var directoryEntries: [CFBDirectoryEntry] = []
    
    // Pre-calculated sizes
    private let sectorSize: Int
    private let miniSectorSize: Int
    
    // Constants
    private static let signature: [UInt8] = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]
    private static let endOfChain: UInt32 = 0xFFFFFFFE
    private static let freeSector: UInt32 = 0xFFFFFFFF
    
    public init(data: Data) throws {
        self.data = data
        
        guard data.count >= 512 else {
            throw CFBError("File too small to be a valid CFB archive.")
        }
        
        // Validate signature
        let sig = [UInt8](data[0..<8])
        guard sig == Self.signature else {
            throw CFBError("Invalid CFB signature.")
        }
        
        // Parse header (offsets are specified by MS-CFB)
        sectorShift = data.readUInt16(at: 30)
        miniSectorShift = data.readUInt16(at: 32)
        
        // Sector shift is typically 9 (512 bytes) or 12 (4096 bytes)
        guard sectorShift == 9 || sectorShift == 12 else {
            throw CFBError("Invalid sector shift: \(sectorShift)")
        }
        sectorSize = 1 << sectorShift
        miniSectorSize = 1 << miniSectorShift
        
        directorySectorsCount = data.readUInt32(at: 40)
        fatSectorsCount = data.readUInt32(at: 44)
        firstDirectorySectorLocation = data.readUInt32(at: 48)
        minStandardStreamSize = data.readUInt32(at: 56)
        firstMiniFatSectorLocation = data.readUInt32(at: 60)
        miniFatSectorsCount = data.readUInt32(at: 64)
        firstDifatSectorLocation = data.readUInt32(at: 68)
        difatSectorsCount = data.readUInt32(at: 72)
        
        try readDIFAT()
        try readFAT()
        try readMiniFAT()
        try readDirectory()
    }
    
    private func readDIFAT() throws {
        // DIFAT contains the FAT sectors. First 109 entries are in the header.
        difat = []
        for i in 0..<109 {
            let offset = 76 + (i * 4)
            let sector = data.readUInt32(at: offset)
            if sector != Self.freeSector {
                difat.append(sector)
            }
        }
        
        // If there are more DIFAT sectors, read them
        var currentDifatSector = firstDifatSectorLocation
        for _ in 0..<difatSectorsCount {
            if currentDifatSector == Self.endOfChain || currentDifatSector == Self.freeSector { break }
            let sectorOffset = offset(forSector: currentDifatSector)
            let capacity = (sectorSize - 4) / 4
            for i in 0..<capacity {
                let sector = data.readUInt32(at: sectorOffset + i * 4)
                if sector != Self.freeSector {
                    difat.append(sector)
                }
            }
            currentDifatSector = data.readUInt32(at: sectorOffset + capacity * 4)
        }
    }
    
    private func readFAT() throws {
        fat = []
        let capacity = sectorSize / 4
        for fatSector in difat {
            let offset = offset(forSector: fatSector)
            for i in 0..<capacity {
                fat.append(data.readUInt32(at: offset + i * 4))
            }
        }
    }
    
    private func readMiniFAT() throws {
        miniFat = []
        guard firstMiniFatSectorLocation != Self.endOfChain && firstMiniFatSectorLocation != Self.freeSector else { return }
        
        let capacity = sectorSize / 4
        let chain = getSectorChain(startingAt: firstMiniFatSectorLocation)
        for sector in chain {
            let offset = offset(forSector: sector)
            for i in 0..<capacity {
                miniFat.append(data.readUInt32(at: offset + i * 4))
            }
        }
    }
    
    private func readDirectory() throws {
        directoryEntries = []
        let chain = getSectorChain(startingAt: firstDirectorySectorLocation)
        for sector in chain {
            let offset = offset(forSector: sector)
            let entriesPerSector = sectorSize / 128
            for i in 0..<entriesPerSector {
                let entryOffset = offset + i * 128
                let entry = CFBDirectoryEntry(data: data, offset: entryOffset)
                directoryEntries.append(entry)
            }
        }
        
        guard !directoryEntries.isEmpty else {
            throw CFBError("No directory entries found.")
        }
        rootDirectoryEntry = directoryEntries[0]
    }
    
    private func getSectorChain(startingAt startSector: UInt32) -> [UInt32] {
        var chain: [UInt32] = []
        var current = startSector
        while current != Self.endOfChain && current != Self.freeSector && current < fat.count {
            chain.append(current)
            current = fat[Int(current)]
        }
        return chain
    }
    
    private func getMiniSectorChain(startingAt startSector: UInt32) -> [UInt32] {
        var chain: [UInt32] = []
        var current = startSector
        while current != Self.endOfChain && current != Self.freeSector && current < miniFat.count {
            chain.append(current)
            current = miniFat[Int(current)]
        }
        return chain
    }
    
    private func offset(forSector sector: UInt32) -> Int {
        return 512 + Int(sector) * sectorSize
    }
    
    public func readStream(named name: String) throws -> Data {
        guard let entry = directoryEntries.first(where: { $0.name == name && $0.type == .stream }) else {
            throw CFBError("Stream \(name) not found.")
        }
        
        if entry.streamSize < minStandardStreamSize {
            return try readMiniStream(entry)
        } else {
            return try readStandardStream(entry)
        }
    }
    
    private func readStandardStream(_ entry: CFBDirectoryEntry) throws -> Data {
        let chain = getSectorChain(startingAt: entry.startingSectorLocation)
        var streamData = Data()
        streamData.reserveCapacity(Int(entry.streamSize))
        
        var remainingSize = Int(entry.streamSize)
        for sector in chain {
            let offset = offset(forSector: sector)
            let readSize = min(sectorSize, remainingSize)
            streamData.append(data.subdata(in: offset..<offset+readSize))
            remainingSize -= readSize
            if remainingSize <= 0 { break }
        }
        return streamData
    }
    
    private func readMiniStream(_ entry: CFBDirectoryEntry) throws -> Data {
        let rootChain = getSectorChain(startingAt: rootDirectoryEntry.startingSectorLocation)
        var rootStreamData = Data()
        for sector in rootChain {
            let offset = offset(forSector: sector)
            rootStreamData.append(data.subdata(in: offset..<offset+sectorSize))
        }
        
        let chain = getMiniSectorChain(startingAt: entry.startingSectorLocation)
        var streamData = Data()
        streamData.reserveCapacity(Int(entry.streamSize))
        
        var remainingSize = Int(entry.streamSize)
        for sector in chain {
            let offset = Int(sector) * miniSectorSize
            let readSize = min(miniSectorSize, remainingSize)
            if offset + readSize <= rootStreamData.count {
                streamData.append(rootStreamData.subdata(in: offset..<offset+readSize))
            } else {
                throw CFBError("Mini stream bounds out of range.")
            }
            remainingSize -= readSize
            if remainingSize <= 0 { break }
        }
        return streamData
    }
}

public struct CFBDirectoryEntry {
    public enum EntryType: UInt8 {
        case empty = 0x00
        case storage = 0x01
        case stream = 0x02
        case lockBytes = 0x03
        case property = 0x04
        case rootStorage = 0x05
    }
    
    public let name: String
    public let type: EntryType
    public let startingSectorLocation: UInt32
    public let streamSize: UInt64
    
    init(data: Data, offset: Int) {
        let nameLength = Int(data.readUInt16(at: offset + 64))
        if nameLength > 2 && nameLength <= 64 {
            let nameData = data.subdata(in: offset..<(offset + nameLength - 2))
            name = String(data: nameData, encoding: .utf16LittleEndian) ?? ""
        } else {
            name = ""
        }
        
        let typeRaw = data[offset + 66]
        type = EntryType(rawValue: typeRaw) ?? .empty
        
        startingSectorLocation = data.readUInt32(at: offset + 116)
        streamSize = data.readUInt64(at: offset + 120)
    }
}

extension Data {
    func readUInt16(at offset: Int) -> UInt16 {
        guard offset + 2 <= count else { return 0 }
        return UInt16(self[offset]) | (UInt16(self[offset+1]) << 8)
    }
    
    func readUInt32(at offset: Int) -> UInt32 {
        guard offset + 4 <= count else { return 0 }
        return UInt32(self[offset]) | (UInt32(self[offset+1]) << 8) | (UInt32(self[offset+2]) << 16) | (UInt32(self[offset+3]) << 24)
    }
    
    func readUInt64(at offset: Int) -> UInt64 {
        guard offset + 8 <= count else { return 0 }
        return UInt64(readUInt32(at: offset)) | (UInt64(readUInt32(at: offset + 4)) << 32)
    }
}
