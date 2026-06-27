import Foundation

public struct MSDocError: Error, CustomStringConvertible {
    public let description: String
    public init(_ description: String) { self.description = description }
}

public class MSDocParser {
    private let archive: CFBArchive
    private let wordDocumentData: Data
    private let tableData: Data
    
    public init(archive: CFBArchive) throws {
        self.archive = archive
        self.wordDocumentData = try archive.readStream(named: "WordDocument")
        
        guard wordDocumentData.count >= 32 else {
            throw MSDocError("WordDocument stream too small for FIB.")
        }
        
        let magic = wordDocumentData.readUInt16(at: 0)
        guard magic == 0xA5EC else {
            throw MSDocError("Invalid WordDocument magic number.")
        }
        
        let flags = wordDocumentData.readUInt16(at: 10)
        let fWhichTblStm = (flags & 0x0200) != 0
        let tableName = fWhichTblStm ? "1Table" : "0Table"
        
        self.tableData = try archive.readStream(named: tableName)
    }
    
    public func parse() throws -> WriteDocumentModel {
        let fib = try parseFIB()
        
        let plcfBteChpxOffset = fib.fcPlcfBteChpx
        let lcbPlcfBteChpx = fib.lcbPlcfBteChpx
        let plcfBteChpx = lcbPlcfBteChpx > 0 ? tableData.subdata(in: Int(plcfBteChpxOffset)..<Int(plcfBteChpxOffset + lcbPlcfBteChpx)) : Data()
        
        let plcfBtePapxOffset = fib.fcPlcfBtePapx
        let lcbPlcfBtePapx = fib.lcbPlcfBtePapx
        let plcfBtePapx = lcbPlcfBtePapx > 0 ? tableData.subdata(in: Int(plcfBtePapxOffset)..<Int(plcfBtePapxOffset + lcbPlcfBtePapx)) : Data()
        
        let formatter = MSDocFormatter(wordDocumentData: wordDocumentData, plcfBteChpx: plcfBteChpx, plcfBtePapx: plcfBtePapx)
        
        return try extractDocument(fcClx: fib.fcClx, lcbClx: fib.lcbClx, formatter: formatter)
    }
    
    private struct FIBPointers {
        let fcClx: UInt32
        let lcbClx: UInt32
        let fcPlcfBteChpx: UInt32
        let lcbPlcfBteChpx: UInt32
        let fcPlcfBtePapx: UInt32
        let lcbPlcfBtePapx: UInt32
    }
    
    private func parseFIB() throws -> FIBPointers {
        let csw = wordDocumentData.readUInt16(at: 32)
        let baseOfRgLw = 34 + Int(csw) * 2
        
        let cslw = wordDocumentData.readUInt16(at: baseOfRgLw)
        let baseOfRgFcLcb = baseOfRgLw + 2 + Int(cslw) * 4
        let cbMac = wordDocumentData.readUInt16(at: baseOfRgFcLcb)
        
        guard cbMac > 66 else { throw MSDocError("FIB too small.") }
        
        let fcClxOffset = baseOfRgFcLcb + 2 + 66 * 8
        let fcClx = wordDocumentData.readUInt32(at: fcClxOffset)
        let lcbClx = wordDocumentData.readUInt32(at: fcClxOffset + 4)
        
        let fcPlcfBteChpxOffset = baseOfRgFcLcb + 2 + 25 * 8
        let fcPlcfBteChpx = wordDocumentData.readUInt32(at: fcPlcfBteChpxOffset)
        let lcbPlcfBteChpx = wordDocumentData.readUInt32(at: fcPlcfBteChpxOffset + 4)
        
        let fcPlcfBtePapxOffset = baseOfRgFcLcb + 2 + 26 * 8
        let fcPlcfBtePapx = wordDocumentData.readUInt32(at: fcPlcfBtePapxOffset)
        let lcbPlcfBtePapx = wordDocumentData.readUInt32(at: fcPlcfBtePapxOffset + 4)
        
        return FIBPointers(fcClx: fcClx, lcbClx: lcbClx, fcPlcfBteChpx: fcPlcfBteChpx, lcbPlcfBteChpx: lcbPlcfBteChpx, fcPlcfBtePapx: fcPlcfBtePapx, lcbPlcfBtePapx: lcbPlcfBtePapx)
    }
    
    fileprivate struct RunProps: Equatable {
        var bold: Bool = false
        var italic: Bool = false
        var underline: Bool = false
        var strikethrough: Bool = false
    }
    
    fileprivate struct ParaProps: Equatable {
        var alignment: WriteParagraphAlignment = .left
    }
    
    private func extractDocument(fcClx: UInt32, lcbClx: UInt32, formatter: MSDocFormatter) throws -> WriteDocumentModel {
        guard lcbClx > 0 else { return WriteDocumentModel(title: "Untitled", blocks: []) }
        let clxData = tableData.subdata(in: Int(fcClx)..<Int(fcClx + lcbClx))
        
        var offset = 0
        var plcData: Data? = nil
        while offset < clxData.count {
            let clxt = clxData[offset]
            if clxt == 1 {
                let cbgrpprl = Int(clxData.readUInt16(at: offset + 1))
                offset += 3 + cbgrpprl
            } else if clxt == 2 {
                let lcb = Int(clxData.readUInt32(at: offset + 1))
                plcData = clxData.subdata(in: offset + 5 ..< offset + 5 + lcb)
                break
            } else {
                throw MSDocError("Unknown clxt type: \(clxt)")
            }
        }
        
        guard let plc = plcData else { return WriteDocumentModel(title: "Untitled", blocks: []) }
        
        let n = (plc.count - 4) / 12
        let pcdOffset = (n + 1) * 4
        
        var paragraphs: [WriteBlock] = []
        var currentRuns: [WriteRun] = []
        var currentRunText = ""
        var currentRunProps = RunProps()
        var isFirstRun = true
        
        func commitRun() {
            if !currentRunText.isEmpty {
                var run = WriteRun(text: currentRunText)
                run.bold = currentRunProps.bold
                run.italic = currentRunProps.italic
                run.underline = currentRunProps.underline
                if currentRunProps.strikethrough {
                    // There is no explicit strikethrough in WriteRun currently, we ignore it for now or if we had it, we'd map it.
                }
                currentRuns.append(run)
                currentRunText = ""
            }
        }
        
        func commitParagraph(papxFC: UInt32) {
            commitRun()
            let pProps = formatter.getParagraphProperties(forFC: papxFC)
            var p = WriteParagraph(runs: currentRuns)
            p.alignment = pProps.alignment
            paragraphs.append(.paragraph(p))
            currentRuns = []
            isFirstRun = true
        }
        
        for i in 0..<n {
            let cpStart = plc.readUInt32(at: i * 4)
            let cpEnd = plc.readUInt32(at: (i + 1) * 4)
            let cpLen = Int(cpEnd - cpStart)
            guard cpLen > 0 else { continue }
            
            let pcdEntryOffset = pcdOffset + i * 8
            let fc = plc.readUInt32(at: pcdEntryOffset + 2)
            let isCompressed = (fc & 0x40000000) != 0
            let actualFc = isCompressed ? (fc & 0x3FFFFFFF) / 2 : fc
            
            for j in 0..<cpLen {
                let currentFc = isCompressed ? actualFc + UInt32(j) : actualFc + UInt32(j * 2)
                let props = formatter.getRunProperties(forFC: currentFc)
                
                let charStr: String
                if isCompressed {
                    let b = wordDocumentData[Int(currentFc)]
                    charStr = String(bytes: [b], encoding: .windowsCP1252) ?? ""
                } else {
                    let b1 = wordDocumentData[Int(currentFc)]
                    let b2 = wordDocumentData[Int(currentFc) + 1]
                    charStr = String(bytes: [b1, b2], encoding: .utf16LittleEndian) ?? ""
                }
                
                // Skip internal cell marks
                if charStr == "\u{0007}" { continue }
                
                if charStr == "\r" {
                    commitParagraph(papxFC: currentFc)
                } else {
                    if isFirstRun {
                        currentRunProps = props
                        isFirstRun = false
                    } else if props != currentRunProps {
                        commitRun()
                        currentRunProps = props
                    }
                    currentRunText += charStr
                }
            }
        }
        
        if !currentRunText.isEmpty || !currentRuns.isEmpty {
            commitRun()
            paragraphs.append(.paragraph(WriteParagraph(runs: currentRuns)))
        }
        
        return WriteDocumentModel(title: "Untitled", blocks: paragraphs)
    }
}

fileprivate class MSDocFormatter {
    private let wordDocumentData: Data
    private let plcfBteChpx: Data
    private let plcfBtePapx: Data
    
    init(wordDocumentData: Data, plcfBteChpx: Data, plcfBtePapx: Data) {
        self.wordDocumentData = wordDocumentData
        self.plcfBteChpx = plcfBteChpx
        self.plcfBtePapx = plcfBtePapx
    }
    
    func getRunProperties(forFC fc: UInt32) -> MSDocParser.RunProps {
        guard plcfBteChpx.count > 0 else { return MSDocParser.RunProps() }
        let n = (plcfBteChpx.count - 4) / 8
        var pn: UInt32? = nil
        
        for i in 0..<n {
            let startFc = plcfBteChpx.readUInt32(at: i * 4)
            let endFc = plcfBteChpx.readUInt32(at: (i + 1) * 4)
            if fc >= startFc && fc < endFc {
                pn = plcfBteChpx.readUInt32(at: (n + 1) * 4 + i * 4)
                break
            }
        }
        
        guard let pageNumber = pn else { return MSDocParser.RunProps() }
        let fkpOffset = Int(pageNumber) * 512
        guard fkpOffset + 512 <= wordDocumentData.count else { return MSDocParser.RunProps() }
        
        let crun = Int(wordDocumentData[fkpOffset + 511])
        var bxOffset: Int? = nil
        
        for i in 0..<crun {
            let startFc = wordDocumentData.readUInt32(at: fkpOffset + i * 4)
            let endFc = wordDocumentData.readUInt32(at: fkpOffset + (i + 1) * 4)
            if fc >= startFc && fc < endFc {
                let bxIndex = fkpOffset + (crun + 1) * 4 + i
                bxOffset = Int(wordDocumentData[bxIndex]) * 2
                break
            }
        }
        
        guard let bxOff = bxOffset else { return MSDocParser.RunProps() }
        let chpxStart = fkpOffset + bxOff
        let cb = Int(wordDocumentData[chpxStart])
        let sprmsData = wordDocumentData.subdata(in: chpxStart + 1 ..< chpxStart + 1 + cb)
        
        var props = MSDocParser.RunProps()
        parseSprms(sprmsData, isPapx: false) { sprm, val in
            if sprm == 0x0835 && val == 1 { props.bold = true }
            else if sprm == 0x0836 && val == 1 { props.italic = true }
            else if sprm == 0x2A3E && val != 0 { props.underline = true }
            else if sprm == 0x0837 && val == 1 { props.strikethrough = true }
        }
        return props
    }
    
    func getParagraphProperties(forFC fc: UInt32) -> MSDocParser.ParaProps {
        guard plcfBtePapx.count > 0 else { return MSDocParser.ParaProps() }
        let n = (plcfBtePapx.count - 4) / 8
        var pn: UInt32? = nil
        
        for i in 0..<n {
            let startFc = plcfBtePapx.readUInt32(at: i * 4)
            let endFc = plcfBtePapx.readUInt32(at: (i + 1) * 4)
            if fc >= startFc && fc < endFc {
                pn = plcfBtePapx.readUInt32(at: (n + 1) * 4 + i * 4)
                break
            }
        }
        
        guard let pageNumber = pn else { return MSDocParser.ParaProps() }
        let fkpOffset = Int(pageNumber) * 512
        guard fkpOffset + 512 <= wordDocumentData.count else { return MSDocParser.ParaProps() }
        
        let crun = Int(wordDocumentData[fkpOffset + 511])
        var bxOffset: Int? = nil
        
        for i in 0..<crun {
            let startFc = wordDocumentData.readUInt32(at: fkpOffset + i * 4)
            let endFc = wordDocumentData.readUInt32(at: fkpOffset + (i + 1) * 4)
            if fc >= startFc && fc < endFc {
                let bxIndex = fkpOffset + (crun + 1) * 4 + i * 13
                bxOffset = Int(wordDocumentData[bxIndex]) * 2
                break
            }
        }
        
        guard let bxOff = bxOffset, bxOff > 0 else { return MSDocParser.ParaProps() }
        let papxStart = fkpOffset + bxOff
        let cw = Int(wordDocumentData[papxStart])
        let cb = cw * 2
        // PAPX format: 1 byte cw, then 2 bytes istd (Style ID), then sprms
        guard cb > 2 else { return MSDocParser.ParaProps() }
        let sprmsData = wordDocumentData.subdata(in: papxStart + 3 ..< papxStart + 1 + cb)
        
        var props = MSDocParser.ParaProps()
        parseSprms(sprmsData, isPapx: true) { sprm, val in
            if sprm == 0x2403 {
                if val == 0 { props.alignment = .left }
                else if val == 1 { props.alignment = .center }
                else if val == 2 { props.alignment = .right }
                else if val == 3 { props.alignment = .justified }
            }
        }
        return props
    }
    
    private func parseSprms(_ data: Data, isPapx: Bool, handler: (UInt16, Int) -> Void) {
        var offset = 0
        while offset + 2 <= data.count {
            let sprm = data.readUInt16(at: offset)
            let spra = sprm >> 13
            var paramLen = 0
            var val: Int = 0
            
            switch spra {
            case 0, 1:
                paramLen = 1
                if offset + 2 + 1 <= data.count { val = Int(data[offset + 2]) }
            case 2, 4, 5:
                paramLen = 2
                if offset + 2 + 2 <= data.count { val = Int(data.readUInt16(at: offset + 2)) }
            case 3:
                paramLen = 4
                if offset + 2 + 4 <= data.count { val = Int(data.readUInt32(at: offset + 2)) }
            case 6:
                if offset + 2 + 1 <= data.count { paramLen = 1 + Int(data[offset + 2]) }
            case 7:
                paramLen = 3
            default: break
            }
            
            handler(sprm, val)
            offset += 2 + paramLen
        }
    }
}
