import Foundation
@testable import SenovativeKit

let url = URL(fileURLWithPath: "/Users/senoadji/Code/github/senovative/senovative-office/sample/UAS_Project_Analisis_Sentimen.docx")
let data = try Data(contentsOf: url)
let model = try OOXMLEngine.load(data: data, fileType: .docx)

for block in model.blocks {
    if case .paragraph(let p) = block {
        if p.runs.first?.text.contains("UJIAN") == true {
            print("Title paragraph found:")
            for run in p.runs {
                print(" - run: text=\(run.text), bold=\(run.bold), fontSize=\(run.fontSize ?? 0), color=\(run.textColorHex ?? "nil")")
            }
        }
    }
}
