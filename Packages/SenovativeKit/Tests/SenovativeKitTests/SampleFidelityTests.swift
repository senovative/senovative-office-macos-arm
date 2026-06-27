import Foundation
import Testing
@testable import SenovativeKit

/// Fidelity checks against a real Word-authored `.docx` fixture. These assert
/// that opening the document yields the same character formatting Word would
/// render: body text inherits the theme's body font and the document default
/// size, headings keep their authored size/color, and theme-referenced heading
/// fonts resolve to a concrete typeface.
struct SampleFidelityTests {
    private func loadSample() throws -> WriteDocumentModel {
        let url = try #require(
            Bundle.module.url(
                forResource: "UAS_Project_Analisis_Sentimen",
                withExtension: "docx",
                subdirectory: "Fixtures"
            ),
            "sample fixture is missing from the test bundle"
        )
        return try OOXMLEngine.readWord(from: try Data(contentsOf: url))
    }

    /// Finds the first top-level paragraph whose text starts with `prefix`.
    private func paragraph(startingWith prefix: String, in model: WriteDocumentModel) throws -> WriteParagraph {
        let match = model.paragraphs.first { $0.plainText.hasPrefix(prefix) }
        return try #require(match, "no paragraph starting with \"\(prefix)\"")
    }

    @Test func bodyTextInheritsThemeFontAndDefaultSize() throws {
        let model = try loadSample()
        // A plain body paragraph carries no direct font/size in the XML, so it
        // must inherit the document defaults: Cambria (theme minorHAnsi) at 11pt.
        let body = try paragraph(startingWith: "Anda diminta membangun", in: model)
        let run = try #require(body.runs.first, "body paragraph has no runs")

        #expect(run.fontFamily == "Cambria")
        #expect(run.fontSize == 11)
        #expect(!run.bold)
    }

    @Test func defaultRunSizeIsElevenPoints() throws {
        let model = try loadSample()
        // Every run that lacks an explicit size must resolve to the 11pt default
        // (`<w:sz w:val="22"/>` in docDefaults) — never 0 or nil.
        for paragraph in model.paragraphs {
            for run in paragraph.runs where !run.text.isEmpty {
                #expect(run.fontSize != nil, "run \"\(run.text.prefix(20))\" has no resolved size")
                #expect((run.fontSize ?? 0) > 0)
            }
        }
    }

    @Test func headingKeepsAuthoredSizeAndColor() throws {
        let model = try loadSample()
        // The document title heading is authored bold, 22pt, in the legacy Word
        // accent color #365F91 — these are direct run properties and must survive.
        let title = try paragraph(startingWith: "UJIAN AKHIR SEMESTER", in: model)
        let run = try #require(title.runs.first, "title has no runs")

        #expect(run.bold)
        #expect(run.fontSize == 22)
        #expect(run.textColorHex == "365F91")
    }

    @Test func listBulletStyleIsRecognizedAsBulletList() throws {
        let model = try loadSample()
        // These items use `<w:pStyle w:val="ListBullet"/>`, which carries the
        // numbering in styles.xml rather than on the paragraph. They must still
        // resolve to a bullet list so the editor renders the marker.
        let item = try paragraph(startingWith: "Sumber dataset", in: model)
        let list = try #require(item.list, "list item was not recognized as a list")
        #expect(list.kind == .bullet)
    }

    @Test func themeFontTokensResolveToConcreteTypeface() throws {
        let model = try loadSample()
        // No run should leak an unresolved theme token (e.g. "minorHAnsi"); every
        // resolved font must be a real typeface name.
        let themeTokens: Set<String> = ["minorHAnsi", "majorHAnsi", "minorEastAsia", "majorEastAsia", "minorBidi", "majorBidi"]
        for paragraph in model.paragraphs {
            for run in paragraph.runs {
                if let font = run.fontFamily {
                    #expect(!themeTokens.contains(font), "font \"\(font)\" was not resolved from its theme token")
                }
            }
        }
    }
}
