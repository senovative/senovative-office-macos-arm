import Foundation

/// Serializes a `WriteDocumentModel` into a Word 97-2003 binary `.doc`
/// ([MS-DOC]) wrapped in a [MS-CFB] compound file.
///
/// Scope (Fase 1.i): a single text piece stored as UTF-16 in the WordDocument
/// stream, a piece table (`Clx`) in the `1Table` stream, plus optional CHPX/PAPX
/// formatted-disk-pages carrying character toggles (bold/italic/underline) and
/// paragraph alignment. Tables are flattened to paragraphs; images/shapes are
/// dropped (text-only legacy format). If the formatting does not fit in a single
/// 512-byte page the writer degrades to text-only (still a valid document).
public enum MSDocWriter {
    private static let fibLength = 900
    private static let sectorSize = 512

    public static func writeDoc(model: WriteDocumentModel) throws -> Data {
        let paragraphs = flatten(model.blocks)

        // 1. Build the text as UTF-16 code units, recording per-unit character
        //    formatting and paragraph boundaries (each paragraph ends with CR).
        var units: [UInt16] = []
        var unitBold: [Bool] = []
        var unitItalic: [Bool] = []
        var unitUnderline: [Bool] = []
        var paragraphEndUnit: [Int] = []
        var alignments: [WriteParagraphAlignment] = []

        for paragraph in paragraphs {
            for run in paragraph.runs where run.image == nil && run.shape == nil {
                for unit in run.text.utf16 {
                    units.append(unit)
                    unitBold.append(run.bold)
                    unitItalic.append(run.italic)
                    unitUnderline.append(run.underline)
                }
            }
            units.append(0x000D) // paragraph mark
            unitBold.append(false)
            unitItalic.append(false)
            unitUnderline.append(false)
            paragraphEndUnit.append(units.count)
            alignments.append(paragraph.alignment)
        }

        let ccpText = units.count

        // 2. Lay out the WordDocument stream: FIB | text | CHPX page | PAPX page.
        let fcText = roundUp(fibLength, to: sectorSize)
        let textByteCount = ccpText * 2
        let chpxOffset = roundUp(fcText + textByteCount, to: sectorSize)
        let papxOffset = chpxOffset + sectorSize
        let wordDocumentLength = papxOffset + sectorSize

        let fcMin = UInt32(fcText)
        let fcMac = UInt32(fcText + textByteCount)
        let chpxPageNumber = UInt32(chpxOffset / sectorSize)
        let papxPageNumber = UInt32(papxOffset / sectorSize)

        // 3. Build the formatting pages (may fail -> degrade to text-only).
        let chpxPage = buildChpxPage(
            count: ccpText, fcMin: fcMin,
            bold: unitBold, italic: unitItalic, underline: unitUnderline
        )
        let papxPage = buildPapxPage(
            fcMin: fcMin, paragraphEndUnit: paragraphEndUnit, alignments: alignments
        )

        // 4. Build the 1Table stream: piece table + formatting bin tables.
        var table = Data()

        let clxOffset = table.count
        table.append(0x02) // clxt = pcdt
        var plcfpcd = Data()
        plcfpcd.appendUInt32LE(0)               // CP start
        plcfpcd.appendUInt32LE(UInt32(ccpText)) // CP end
        plcfpcd.appendUInt16LE(0)               // PCD flags
        plcfpcd.appendUInt32LE(fcMin)           // PCD fc (fCompressed = 0 -> UTF-16)
        plcfpcd.appendUInt16LE(0)               // PCD prm
        table.appendUInt32LE(UInt32(plcfpcd.count))
        table.append(plcfpcd)
        let clxLength = table.count - clxOffset

        var fcChpx = 0, lcbChpx = 0
        if chpxPage != nil {
            fcChpx = table.count
            table.appendUInt32LE(fcMin)
            table.appendUInt32LE(fcMac)
            table.appendUInt32LE(chpxPageNumber)
            lcbChpx = table.count - fcChpx
        }

        var fcPapx = 0, lcbPapx = 0
        if papxPage != nil {
            fcPapx = table.count
            table.appendUInt32LE(fcMin)
            table.appendUInt32LE(fcMac)
            table.appendUInt32LE(papxPageNumber)
            lcbPapx = table.count - fcPapx
        }

        // 5. Build the FIB and the WordDocument stream.
        let fib = buildFIB(
            wordDocumentLength: wordDocumentLength,
            ccpText: ccpText,
            clxOffset: clxOffset, clxLength: clxLength,
            fcPlcfBteChpx: fcChpx, lcbPlcfBteChpx: lcbChpx,
            fcPlcfBtePapx: fcPapx, lcbPlcfBtePapx: lcbPapx
        )

        var wordDocument = Data(count: wordDocumentLength)
        wordDocument.replaceSubrange(0..<fibLength, with: fib)

        var textBytes = Data(capacity: textByteCount)
        for unit in units { textBytes.appendUInt16LE(unit) }
        if !textBytes.isEmpty {
            wordDocument.replaceSubrange(fcText..<fcText + textBytes.count, with: textBytes)
        }
        if let chpxPage {
            wordDocument.replaceSubrange(chpxOffset..<chpxOffset + sectorSize, with: chpxPage)
        }
        if let papxPage {
            wordDocument.replaceSubrange(papxOffset..<papxOffset + sectorSize, with: papxPage)
        }

        return try CFBWriter.write(streams: [
            CFBStream(name: "WordDocument", data: wordDocument),
            CFBStream(name: "1Table", data: table),
        ])
    }

    // MARK: - Flattening

    private struct FlatParagraph {
        var runs: [WriteRun]
        var alignment: WriteParagraphAlignment
    }

    private static func flatten(_ blocks: [WriteBlock]) -> [FlatParagraph] {
        var result: [FlatParagraph] = []
        for block in blocks {
            switch block {
            case let .paragraph(paragraph):
                result.append(FlatParagraph(runs: paragraph.runs, alignment: paragraph.alignment))
            case let .table(table):
                for row in table.rows {
                    for cell in row.cells {
                        for paragraph in cell.paragraphs {
                            result.append(FlatParagraph(runs: paragraph.runs, alignment: paragraph.alignment))
                        }
                    }
                }
            }
        }
        return result.isEmpty ? [FlatParagraph(runs: [], alignment: .left)] : result
    }

    // MARK: - Formatted disk pages

    private static func buildChpxPage(
        count: Int, fcMin: UInt32,
        bold: [Bool], italic: [Bool], underline: [Bool]
    ) -> Data? {
        guard count > 0 else { return nil }

        // Segment the text into runs of identical character formatting.
        var runStarts: [Int] = [0]
        for k in 1..<count {
            if bold[k] != bold[k - 1] || italic[k] != italic[k - 1] || underline[k] != underline[k - 1] {
                runStarts.append(k)
            }
        }
        let crun = runStarts.count
        // No formatting at all -> no need for a CHPX page.
        if !(bold.contains(true) || italic.contains(true) || underline.contains(true)) {
            return nil
        }

        var page = Data(count: sectorSize)
        for (index, start) in runStarts.enumerated() {
            page.writeUInt32LE(fcMin + UInt32(start * 2), at: index * 4)
        }
        page.writeUInt32LE(fcMin + UInt32(count * 2), at: crun * 4)

        let rgbBase = (crun + 1) * 4
        guard rgbBase + crun <= 511 else { return nil }
        var cursor = rgbBase + crun
        if cursor % 2 != 0 { cursor += 1 }

        for (index, start) in runStarts.enumerated() {
            guard bold[start] || italic[start] || underline[start] else { continue }
            var sprms = Data()
            if bold[start] { sprms.appendUInt16LE(0x0835); sprms.append(0x01) }
            if italic[start] { sprms.appendUInt16LE(0x0836); sprms.append(0x01) }
            if underline[start] { sprms.appendUInt16LE(0x2A3E); sprms.append(0x01) }
            let chpxLength = 1 + sprms.count
            guard cursor + chpxLength <= 511 else { return nil }
            page[cursor] = UInt8(sprms.count)
            page.replaceSubrange(cursor + 1..<cursor + 1 + sprms.count, with: sprms)
            page[rgbBase + index] = UInt8(cursor / 2)
            cursor += chpxLength
            if cursor % 2 != 0 { cursor += 1 }
        }
        page[511] = UInt8(crun)
        return page
    }

    private static func buildPapxPage(
        fcMin: UInt32, paragraphEndUnit: [Int], alignments: [WriteParagraphAlignment]
    ) -> Data? {
        let crun = alignments.count
        guard crun > 0 else { return nil }
        // Only worth a PAPX page if some paragraph is non-default.
        guard alignments.contains(where: { $0 != .left }) else { return nil }

        var page = Data(count: sectorSize)
        page.writeUInt32LE(fcMin, at: 0)
        for (index, endUnit) in paragraphEndUnit.enumerated() {
            page.writeUInt32LE(fcMin + UInt32(endUnit * 2), at: (index + 1) * 4)
        }

        let bxBase = (crun + 1) * 4
        guard bxBase + crun * 13 <= 511 else { return nil }
        var cursor = bxBase + crun * 13
        if cursor % 2 != 0 { cursor += 1 }

        for (index, alignment) in alignments.enumerated() {
            var grpprl = Data()
            grpprl.appendUInt16LE(0) // istd
            if alignment != .left {
                grpprl.appendUInt16LE(0x2403) // sprmPJc
                grpprl.append(jcValue(alignment))
            }
            if grpprl.count % 2 != 0 { grpprl.append(0) }
            let papxLength = 1 + grpprl.count
            guard cursor + papxLength <= 511 else { return nil }
            page[cursor] = UInt8(grpprl.count / 2) // cw
            page.replaceSubrange(cursor + 1..<cursor + 1 + grpprl.count, with: grpprl)
            page[bxBase + index * 13] = UInt8(cursor / 2)
            cursor += papxLength
            if cursor % 2 != 0 { cursor += 1 }
        }
        page[511] = UInt8(crun)
        return page
    }

    private static func jcValue(_ alignment: WriteParagraphAlignment) -> UInt8 {
        switch alignment {
        case .left: 0
        case .center: 1
        case .right: 2
        case .justified: 3
        }
    }

    // MARK: - FIB

    private static func buildFIB(
        wordDocumentLength: Int,
        ccpText: Int,
        clxOffset: Int, clxLength: Int,
        fcPlcfBteChpx: Int, lcbPlcfBteChpx: Int,
        fcPlcfBtePapx: Int, lcbPlcfBtePapx: Int
    ) -> Data {
        var fib = Data(count: fibLength)
        fib.writeUInt16LE(0xA5EC, at: 0)   // wIdent
        fib.writeUInt16LE(0x00C1, at: 2)   // nFib (Word 97)
        fib.writeUInt16LE(0x0200, at: 10)  // flags: fWhichTblStm -> 1Table
        fib.writeUInt16LE(14, at: 32)      // csw
        fib.writeUInt16LE(22, at: 62)      // cslw
        fib.writeUInt32LE(UInt32(wordDocumentLength), at: 64) // FibRgLw97.cbMac
        fib.writeUInt32LE(UInt32(ccpText), at: 76)            // FibRgLw97.ccpText
        fib.writeUInt16LE(93, at: 152)     // cbRgFcLcb

        let base = 154
        func setFcLcb(_ index: Int, _ fc: Int, _ lcb: Int) {
            fib.writeUInt32LE(UInt32(fc), at: base + index * 8)
            fib.writeUInt32LE(UInt32(lcb), at: base + index * 8 + 4)
        }
        setFcLcb(1, 0, 0)                                  // fcStshf (none)
        setFcLcb(25, fcPlcfBteChpx, lcbPlcfBteChpx)
        setFcLcb(26, fcPlcfBtePapx, lcbPlcfBtePapx)
        setFcLcb(66, clxOffset, clxLength)
        // cswNew at offset 898 stays 0.
        return fib
    }

    private static func roundUp(_ value: Int, to multiple: Int) -> Int {
        value % multiple == 0 ? value : value + (multiple - value % multiple)
    }
}
