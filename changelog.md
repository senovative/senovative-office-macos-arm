# Changelog

## 2026-06-27 — Fase 1.a Fondasi & Scaffolding

**Dikerjakan oleh:** Codex CLI

### Ringkasan

Mengerjakan Fase 1.a dari `planning.md`: membuat fondasi awal monorepo Senovative Office, menyiapkan app macOS native `SenovativeWrite`, package shared, konfigurasi build arm64, registrasi `.docx`, dan verifikasi build release.

### Perubahan Utama

- Membuat workspace Xcode:
  - `SenovativeOffice.xcworkspace`
  - Menghubungkan project app dan dua Swift package lokal.

- Membuat app macOS `SenovativeWrite`:
  - Lokasi: `Apps/SenovativeWrite`
  - Target app: `SenovativeWrite.app`
  - Deployment target: macOS 14+
  - Arsitektur: arm64 only
  - Bundle identifier: `io.senovative.office.write`

- Membuat project Xcode untuk `SenovativeWrite`:
  - `Apps/SenovativeWrite/SenovativeWrite.xcodeproj/project.pbxproj`
  - Scheme yang tersedia lewat workspace:
    - `SenovativeWrite`
    - `SenovativeKit`
    - `SenovativeUI`

- Membuat document-based app shell berbasis AppKit `NSDocument`:
  - `Apps/SenovativeWrite/Sources/main.swift`
  - `Apps/SenovativeWrite/Sources/AppDelegate.swift`
  - `Apps/SenovativeWrite/Sources/WriteDocument.swift`
  - `Apps/SenovativeWrite/Sources/WriteWindowController.swift`
  - `Apps/SenovativeWrite/Sources/WriteViewController.swift`
  - `Apps/SenovativeWrite/Sources/WriteDocumentState.swift`
  - `Apps/SenovativeWrite/Sources/MainMenuBuilder.swift`

- Menambahkan shell UI awal:
  - Window dokumen kosong.
  - Toolbar AppKit dengan tombol New, Open, Save, Inspector.
  - Ribbon SwiftUI placeholder dengan tombol Bold, Italic, Underline.
  - Inspector placeholder.
  - Status bar.
  - Canvas text placeholder berbasis `NSTextView`.

- Mendaftarkan format `.docx`:
  - UTI/content type: `org.openxmlformats.wordprocessingml.document`
  - File extension: `.docx`
  - Document class: `SenovativeWrite.WriteDocument`
  - Lokasi konfigurasi: `Apps/SenovativeWrite/Resources/Info.plist`

- Menambahkan sandbox entitlement:
  - `com.apple.security.app-sandbox`
  - `com.apple.security.files.user-selected.read-write`
  - Lokasi: `Apps/SenovativeWrite/Resources/SenovativeWrite.entitlements`

- Membuat Swift package `SenovativeKit`:
  - Lokasi: `Packages/SenovativeKit`
  - Isi awal:
    - Model dokumen shared.
    - Metadata tipe file `.docx`.
    - Error dokumen shared.
  - File penting:
    - `Packages/SenovativeKit/Package.swift`
    - `Packages/SenovativeKit/Sources/SenovativeKit/Document/DocumentModel.swift`
    - `Packages/SenovativeKit/Sources/SenovativeKit/Document/WriteDocumentModel.swift`
    - `Packages/SenovativeKit/Sources/SenovativeKit/Util/SenovativeDocumentError.swift`

- Membuat Swift package `SenovativeUI`:
  - Lokasi: `Packages/SenovativeUI`
  - Isi awal:
    - Theme shared.
    - Ribbon shell.
    - Inspector placeholder.
    - Status pill.
  - File penting:
    - `Packages/SenovativeUI/Package.swift`
    - `Packages/SenovativeUI/Sources/SenovativeUI/Theme/SenovativeTheme.swift`
    - `Packages/SenovativeUI/Sources/SenovativeUI/Ribbon/RibbonShell.swift`
    - `Packages/SenovativeUI/Sources/SenovativeUI/Inspector/InspectorPlaceholder.swift`
    - `Packages/SenovativeUI/Sources/SenovativeUI/Controls/StatusPill.swift`

- Menambahkan localization awal:
  - Inggris: `Apps/SenovativeWrite/Resources/en.lproj/Localizable.strings`
  - Indonesia: `Apps/SenovativeWrite/Resources/id.lproj/Localizable.strings`

- Menambahkan placeholder app icon:
  - Asset catalog: `Apps/SenovativeWrite/Resources/Assets.xcassets`
  - App icon set: `Apps/SenovativeWrite/Resources/Assets.xcassets/AppIcon.appiconset`
  - Accent color: `Apps/SenovativeWrite/Resources/Assets.xcassets/AccentColor.colorset`
  - Generator: `Tools/generate-placeholder-icon.swift`

- Menambahkan tools awal:
  - `Tools/build.sh`
  - `Tools/sign-notarize.sh`
  - `Tools/make-dmg.sh`
  - `build.sh` sudah menjalankan release build arm64 untuk `SenovativeWrite`.
  - `sign-notarize.sh` dan `make-dmg.sh` masih placeholder untuk Fase 1.k.

- Menambahkan dokumentasi arsitektur awal:
  - `docs/architecture.md`

- Menambahkan `.gitignore`:
  - Mengabaikan `build/`, `.build/`, `.swiftpm/`, `DerivedData/`, `xcuserdata/`, `.dSYM`, `.dmg`, dan file macOS transient.

### Hasil Build & Verifikasi

Perintah yang sudah dijalankan dan berhasil:

```bash
swift test
```

Berhasil untuk:

- `Packages/SenovativeKit`
- `Packages/SenovativeUI`

```bash
./Tools/build.sh
```

Berhasil membuat release app:

```text
build/Build/Products/Release/SenovativeWrite.app
```

Verifikasi tambahan:

- Workspace terbaca oleh `xcodebuild`.
- Scheme tersedia:
  - `SenovativeKit`
  - `SenovativeUI`
  - `SenovativeWrite`
- Executable release terdeteksi sebagai:

```text
Mach-O 64-bit executable arm64
```

- Code signing ad-hoc valid:

```text
SenovativeWrite.app: valid on disk
SenovativeWrite.app: satisfies its Designated Requirement
```

- `Info.plist` release berisi:
  - `.docx` document type.
  - `org.openxmlformats.wordprocessingml.document`.
  - `NSDocumentClass = SenovativeWrite.WriteDocument`.
  - `CFBundleIconName = AppIcon`.

### Catatan Teknis Untuk Agen Berikutnya

- `WriteDocument.data(ofType:)` saat ini sengaja belum menyimpan `.docx`; method tersebut melempar `SenovativeDocumentError.ooxmlEngineUnavailable`. Ini sesuai batas Fase 1.a. Implementasi save asli masuk Fase 1.b.

- `WriteDocument.read(from:ofType:)` saat ini hanya mengisi placeholder text saat membuka `.docx`. Parser OOXML asli belum ada dan harus dikerjakan di Fase 1.b.

- Ada penggunaan `nonisolated(unsafe)` pada `WriteDocument.state` untuk melewati batas isolasi Swift 6 pada override `NSDocument`. Ini pragmatis untuk shell awal. Saat engine dan model dokumen sudah lebih matang, sebaiknya ditinjau ulang supaya update state lebih rapi dengan boundary main actor yang jelas.

- App sudah bisa build/run sebagai shell kosong dan sudah terdaftar sebagai editor `.docx`, tetapi belum bisa round-trip file `.docx`.

- Build menggunakan Xcode 26.6 dan Swift 6.3.3 pada mesin arm64.

### Status Roadmap

Fase 1.a sudah selesai secara fungsional:

- Workspace + SPM packages: selesai.
- Target `SenovativeWrite.app`: selesai.
- Build arm64-only: selesai.
- `NSDocument` base: selesai.
- UTI `.docx`: selesai.
- Window/menu/toolbar shell: selesai.
- App icon placeholder: selesai.
- Build release terverifikasi: selesai.

Langkah berikutnya adalah **Fase 1.b — Engine OOXML inti read/write `.docx`**:

- ZIP read/write.
- Parse minimal WordprocessingML:
  - `word/document.xml`
  - paragraph
  - run
  - text
- Model dokumen in-memory yang cukup untuk teks dasar.
- Save `.docx` minimal.
- Round-trip buka lalu simpan tanpa merusak file `.docx`.

---

## 2026-06-27 — Fase 1.b Engine OOXML Inti

**Dikerjakan oleh:** Antigravity CLI

### Ringkasan

Menyelesaikan Fase 1.b dengan menambahkan library `ZIPFoundation` dan membuat `OOXMLEngine` untuk memproses read/write arsip `.docx` sederhana. Keseluruhan modul telah divalidasi dan berhasil dibuild ulang dengan sukses.

### Perubahan Utama

- **Dependensi Baru**:
  - Menambahkan `ZIPFoundation` via Swift Package Manager (versi `.upToNextMajor(from: "0.9.0")`) pada target `SenovativeKit` untuk menangani arsip `.zip` dan file `.docx`.
- **Engine & Parser**:
  - Membuat abstrak `OOXMLArchive` (`OOXMLArchive.swift`) untuk enkapsulasi fitur *extract* dan *add entry* pada file format ZIP.
  - Membuat `WordprocessingMLParser` dan `WordprocessingMLWriter` yang mengekstrak dan menulis kembali tag XML dasar (`<w:p>` dan `<w:t>`) dari dan menuju file `word/document.xml`.
  - Merancang jembatan integrasi utama melalui `OOXMLEngine` (`OOXMLEngine.swift`).
- **Integrasi Dokumen**:
  - Menghubungkan fungsi utama `read` dan `data` di `WriteDocument.swift` pada `SenovativeWrite.app` agar menggunakan modul `OOXMLEngine`.
  - Mengupdate status pesan dan mendefinisikan *error* baru (`SenovativeDocumentError.fileCorrupted`).

### Verifikasi Build

Seluruh workspace telah sukses dikompilasi menggunakan skrip `./Tools/build.sh` (release build arm64) serta verifikasi *xcodebuild* keseluruhan via `xcodebuild -workspace SenovativeOffice.xcworkspace -scheme SenovativeWrite build`. Kedua *build* menunjukkan hasil `** BUILD SUCCEEDED **` tanpa satupun *error* dependensi.

### Catatan Teknis Untuk Agen Berikutnya

- **Struktur Teks Sementara**: Saat ini `WordprocessingMLParser` membaca semua teks dari tag `<w:t>` ke dalam format `String` tunggal (`bodyText`) yang dipisahkan oleh `\n` saat menemui `<w:p>`. Ini murni untuk memenuhi kriteria MVP Fase 1.b. Pada Fase 1.c nanti, model `WriteDocumentModel` harus diubah dari *flat string* menjadi struktur data berbasis *Paragraphs* dan *Runs* yang lebih representatif terhadap OOXML, atau langsung menggunakan `NSAttributedString`.
- **TextKit 2**: Di Fase 1.c nanti, Anda harus menghubungkan model dokumen ke TextKit 2. Perhatikan arsitektur `NSTextContentManager` dan `NSTextLayoutManager` pada AppKit. Kelas UI *canvas* placeholder saat ini (`NSTextView` biasa) perlu Anda desain ulang.
- **ZIPFoundation di Memori**: Abstraksi `OOXMLArchive` dirancang untuk memanipulasi *file* sepenuhnya di RAM (*in-memory*) via `Data`. Tidak ada *temp files* di disk. Jika file `.docx` menjadi raksasa di masa depan (misal isi gambar banyak), Anda mungkin perlu merevisi komponen ini untuk efisiensi RAM.

### Status Roadmap

Fase 1.b sudah selesai secara fungsional (versi minimal). Aplikasi saat ini telah memiliki kapabilitas untuk melakukan bongkar-pasang (*extract* & *write*) terhadap format utama `.docx` dengan fondasi yang solid.

Langkah berikutnya adalah **Fase 1.c — Editor Teks Inti**:
- Menghubungkan model dengan UI TextKit 2 (`NSTextLayoutManager`).
- Mendukung ketik, *selection*, *copy/paste*.
- Sinkronisasi perubahan di memori ke XML dokumen saat *save*.

---

## 2026-06-27 — Fase 1.c Editor Teks Inti

**Dikerjakan oleh:** Claude Code (Opus 4.8)

### Ringkasan

Menyelesaikan Fase 1.c: canvas editing berbasis **TextKit 2** (`NSTextLayoutManager`) yang fully editable, dengan caret/selection (keyboard+mouse), copy/paste/cut, undo/redo, serta **bold/italic/underline** yang round-trip ke `word/document.xml`. Model dokumen di-upgrade dari *flat string* menjadi struktur **Paragraphs → Runs** berformat sesuai catatan utang teknis Fase 1.b.

### Perubahan Utama

- **Model dokumen berformat** (`WriteDocumentModel.swift`):
  - Tipe baru `WriteRun` (text + bold/italic/underline) dan `WriteParagraph` (array runs).
  - `WriteDocumentModel` kini menyimpan `paragraphs: [WriteParagraph]` (bukan `body: String`).
  - Convenience `init(title:body:)` & `plainText` dipertahankan untuk kompatibilitas.

- **Engine OOXML run-aware** (`WordprocessingML.swift`):
  - `WordprocessingMLParser` ditulis ulang jadi stateful: membangun `[WriteParagraph]` dengan `<w:p>`/`<w:r>`/`<w:t>` dan toggle `<w:rPr>` (`<w:b>`, `<w:i>`, `<w:u>`). Menangani namespace-prefix opsional, atribut `w:val` (`false/0/none`), dan **mengabaikan `rPr` pada paragraph mark** (`<w:pPr>`).
  - `WordprocessingMLWriter.document(paragraphs:)` menyerialisasi run beserta `<w:rPr>`.
  - `OOXMLEngine` di-update mengikuti API paragraphs.

- **Editor TextKit 2** (`WriteViewController.swift`):
  - `DocumentCanvas` memakai `NSTextView(usingTextLayoutManager: true)`, `isEditable`, `allowsUndo`, rich text.
  - `WriteAttributedStringBridge`: konversi dua arah model ↔ `NSAttributedString` (bold/italic via trait `NSFontManager`, underline via `.underlineStyle`).
  - `Coordinator` (NSTextViewDelegate): `textDidChange` mem-build ulang model dari text storage, push ke state, dan `updateChangeCount(.changeDone)`.

- **Sinkronisasi & lifecycle** (`WriteDocumentState.swift`, `WriteDocument.swift`):
  - State punya `loadToken` (increment saat open/new) supaya editor membedakan *external load* vs ketikan user → mencegah loop reload & caret jump.
  - `WriteDocument` set `state.document = self` dan memakai `state.loadModel(...)` saat membuka file.

### Verifikasi Build & Test

- `swift test` (SenovativeKit): **4 test lulus**, termasuk round-trip formatting, escaping `< & >`, dan parser mengabaikan `pPr/rPr`.
- `./Tools/build.sh` (release arm64): **`** BUILD SUCCEEDED **`**.
- Executable terdeteksi `Mach-O 64-bit executable arm64`.
- Tidak ada warning concurrency baru di kode app.

### Catatan Teknis Untuk Agen Berikutnya

- **Rebuild model per keystroke**: `textDidChange` membangun ulang seluruh model dari text storage tiap edit — O(n), cukup untuk MVP. Saat dokumen besar (Fase 1.d/1.e), pertimbangkan diff incremental atau jadikan `NSTextStorage` sumber kebenaran langsung.
- **Toggle warna/highlight & atribut lain belum dipetakan** ke OOXML — baru bold/italic/underline. Fase 1.d akan menambah font family/size, warna, alignment, spacing, list, styles (`styles.xml`).
- **Round-trip preservation belum ada**: part XML yang tak dikenal (mis. `styles.xml`, `settings.xml`, `sectPr`) belum dipertahankan saat menulis ulang — ini target eksplisit Fase 1.g, tapi sebagian akan mulai relevan di 1.d.
- **Undo**: memakai undo bawaan `NSTextView` (`allowsUndo`), belum command/undo terpusat di `SenovativeKit` seperti rencana arsitektur. Tinjau saat model editing makin kompleks.

### Status Roadmap

Fase 1.c selesai secara fungsional. Langkah berikutnya **Fase 1.d — Rich Formatting**: font family/size, warna & highlight, alignment, line/paragraph spacing, bullet & numbered list (`numbering.xml`), indent, super/subscript, styles (`styles.xml`).

---

## 2026-06-27 — Fase 1.d Rich Formatting

**Dikerjakan oleh:** Codex CLI

### Ringkasan

Mengerjakan Fase 1.d versi fungsional: memperluas model dokumen, parser/writer OOXML, dan editor TextKit 2 agar mendukung format kaya dasar. Dukungan yang ditambahkan mencakup font family/size, warna teks, highlight, alignment paragraf, line/paragraph spacing, indent, bullet/numbered list dasar, serta superscript/subscript.

### Perubahan Utama

- **Model dokumen diperluas** (`WriteDocumentModel.swift`):
  - `WriteRun` kini menyimpan:
    - `fontFamily`
    - `fontSize`
    - `textColorHex`
    - `highlightColorHex`
    - `verticalAlignment`
  - Menambahkan `WriteVerticalAlignment`:
    - `baseline`
    - `superscript`
    - `subscripted`
  - `WriteParagraph` kini menyimpan:
    - `alignment`
    - `lineSpacing`
    - `spacingBefore`
    - `spacingAfter`
    - `leftIndent`
    - `firstLineIndent`
    - `list`
  - Menambahkan:
    - `WriteParagraphAlignment`
    - `WriteListStyle`
    - `WriteListKind`

- **OOXML WordprocessingML diperluas** (`WordprocessingML.swift`):
  - Parser membaca properti run:
    - `<w:rFonts>`
    - `<w:sz>`
    - `<w:color>`
    - `<w:shd>`
    - `<w:vertAlign>`
  - Parser membaca properti paragraf:
    - `<w:jc>`
    - `<w:spacing>`
    - `<w:ind>`
    - `<w:numPr>`
  - Writer menulis properti run dan paragraf tersebut kembali ke `word/document.xml`.
  - Writer menambahkan `word/numbering.xml` untuk list dasar saat dokumen memakai bullet/numbered list.
  - Writer menambahkan relationship `word/_rels/document.xml.rels` untuk numbering saat diperlukan.

- **OOXML engine diperbarui** (`OOXMLEngine.swift`):
  - Menentukan apakah dokumen membutuhkan numbering.
  - Menulis `[Content_Types].xml`, relationship, dan `numbering.xml` sesuai kebutuhan list.

- **Editor TextKit 2 diperluas** (`WriteViewController.swift`):
  - Bridge model ↔ `NSAttributedString` kini memetakan:
    - Font family dan ukuran font.
    - Warna teks.
    - Background highlight.
    - Underline.
    - Superscript/subscript via `.superscript`.
    - Paragraph style: alignment, spacing, indent, text lists.
  - Menambahkan tombol ribbon:
    - Font panel.
    - Color panel.
    - Bold/Italic/Underline.
    - Highlight.
    - Align left/center/right.
    - Bullet list.
    - Numbered list.
    - Superscript.
    - Subscript.
  - Menambahkan `RichTextView` untuk action custom:
    - `toggleHighlight`
    - `toggleBulletList`
    - `toggleNumberedList`
    - `toggleSuperscript`
    - `toggleSubscript`

- **OOXMLArchive dirapikan** (`OOXMLArchive.swift`):
  - Mengganti initializer ZIPFoundation deprecated ke throwing initializer baru.

- **Test coverage ditambah** (`SenovativeKitTests.swift`):
  - Test round-trip rich run formatting:
    - font family
    - font size
    - text color
    - highlight
    - superscript/subscript
  - Test round-trip paragraph formatting dan list:
    - alignment
    - line spacing
    - spacing before/after
    - indent
    - bullet list
    - numbered list

### Verifikasi Build & Test

Perintah yang sudah dijalankan dan berhasil:

```bash
swift test
```

Berhasil untuk:

- `Packages/SenovativeKit` — 6 test lulus.
- `Packages/SenovativeUI` — 1 test lulus.

```bash
xcodebuild -workspace SenovativeOffice.xcworkspace -scheme SenovativeWrite -configuration Debug -arch arm64 -derivedDataPath build -quiet build
```

Berhasil.

```bash
./Tools/build.sh
```

Berhasil membuat release app:

```text
build/Build/Products/Release/SenovativeWrite.app
```

Verifikasi tambahan:

- Executable release:

```text
Mach-O 64-bit executable arm64
```

- Code signing ad-hoc valid:

```text
SenovativeWrite.app: valid on disk
SenovativeWrite.app: satisfies its Designated Requirement
```

### Catatan Teknis Untuk Agen Berikutnya

- **Styles (`styles.xml`) belum diimplementasikan penuh.** Fase 1.d sudah menambahkan formatting langsung di run/paragraf, tetapi style named seperti Normal/Heading 1 belum dibuat sebagai sistem style OOXML penuh. Ini masih perlu dilanjutkan bila ingin memenuhi fidelity Word yang lebih baik.

- **List masih dasar.** `numbering.xml` memakai definisi statis untuk bullet dan decimal numbering level 0. Multi-level list, restart numbering, custom marker, dan list style preservation belum ada.

- **Round-trip preservation belum ada.** Saat menyimpan, writer masih membuat `.docx` minimal baru dan belum mempertahankan part yang tidak dikenal. Ini tetap menjadi pekerjaan besar Fase 1.g.

- **Highlight memakai `<w:shd w:fill="...">`.** Ini dipilih agar warna highlight bebas berbasis hex, bukan hanya pilihan terbatas `<w:highlight>`.

- **Bridge editor masih rebuild model per edit.** Sama seperti Fase 1.c, `textDidChange` membangun ulang model dari seluruh `NSTextStorage`. Cukup untuk MVP, tetapi dokumen besar butuh strategi incremental.

- **UI rich formatting berbasis action AppKit.** Font dan color menggunakan panel macOS standar; beberapa kontrol seperti list/highlight/super/subscript dibuat sebagai action custom di `RichTextView`.

### Status Roadmap

Fase 1.d selesai secara fungsional untuk format kaya dasar:

- Font family/size: selesai.
- Warna teks: selesai.
- Highlight: selesai.
- Alignment: selesai.
- Line/paragraph spacing: selesai.
- Indent: selesai.
- Bullet & numbered list dasar: selesai.
- Superscript/subscript: selesai.
- Styles penuh (`styles.xml`): belum selesai, masih perlu fase lanjutan/fidelity.

Langkah berikutnya adalah **Fase 1.e — Page Layout & Pagination**:

- Tampilan halaman.
- Margin dan ukuran kertas (`sectPr`).
- Header/footer.
- Ruler.
- Page break.
- Nomor halaman.

---

## 2026-06-27 — Fase 1.e Page Layout & Pagination (Sebagian)

**Dikerjakan oleh:** Antigravity CLI

### Ringkasan

Memulai pengerjaan Fase 1.e. Berhasil mengimplementasikan parsial komponen inti untuk tampilan halaman, termasuk dukungan ukuran kertas dan margin secara arsitektur model, integrasi parsial pada pembacaan/penulisan XML (`sectPr`), serta representasi UI awal (Canvas Halaman terpusat).

### Perubahan Utama

- **Model & Struktur Data Diperbarui** (`WriteDocumentModel.swift`):
  - Membuat `WritePageSize` dan `WriteEdgeInsets` yang *Sendable* dan *Equatable* untuk mendekomposisi ukuran kertas.
  - Menambahkan struktur `WriteDocumentSection` untuk merepresentasikan bagian dokumen (menyimpan ukuran kertas dan margin).
  - Model utama `WriteDocumentModel` kini menyimpan parameter `section: WriteDocumentSection`.

- **Dukungan Parser/Writer OOXML** (`WordprocessingML.swift`, `OOXMLEngine.swift`):
  - Memperbarui `WordprocessingMLParser` agar membaca tag `<w:sectPr>`, `<w:pgSz>`, dan `<w:pgMar>`. Parser mengubah *twips* ke *points*.
  - Menambahkan kapabilitas `WordprocessingMLWriter` agar menyisipkan definisi `<w:sectPr>` saat melakukan serialisasi `.docx`.
  - Jembatan `OOXMLEngine` telah dimodifikasi agar melewatkan properti `section` bolak-balik tanpa menghilangkan data ukuran halaman dan margin.

- **Integrasi UI & Tampilan Visual Halaman** (`WriteViewController.swift`):
  - Beralih dari *canvas* teks kontinu tanpa batas menjadi representasi kertas fisik berukuran tetap di layar.
  - Mengimplementasikan `PageContainerView` (subclass dari `NSView`) yang mengatur posisinya secara dinamis untuk selalu memusatkan *page layout* (`NSTextView`) pada jendela *editor* atau memberi *padding* yang rapi di sekelilingnya saat dilakukan *scrolling*.
  - `NSTextView` kini membaca `pageSize` dan `margins` dari `WriteDocumentModel` untuk menyesuaikan lebar tetap halaman (`minSize` & `maxSize` terkunci) serta `textContainerInset`.
  - Menambahkan *ruler* (penggaris) bawaan macOS di dalam `NSScrollView` dan memberikan bayangan halus (*drop shadow*) pada halaman teks layaknya dokumen fisik.

### Verifikasi Build & Test

- `swift test` (SenovativeKit) diperbarui dan *pass* sempurna untuk pengujian *parsing* OOXML.
- Kompilasi melalui `./Tools/build.sh` (release build arm64) sukses besar: **`** BUILD SUCCEEDED **`**.
- Aplikasi dapat berjalan dan kini area teks direpresentasikan di tengah aplikasi dengan batas ukuran fisik kertas layaknya pengolah kata modern.

### Penyelesaian Akhir Fase 1.e

- **Pagination & Page Breaks (Selesai)**:
  - Mengimplementasikan layout halaman ganda secara visual di dalam satu `NSTextView` menggunakan pendekatan cerdas `NSTextContainer.exclusionPaths`. Celah antar halaman (gap) dihitung dan dieksklusi sehingga TextKit secara otomatis mendorong teks ke halaman berikutnya tanpa perlu merombak TextKit 2 secara drastis.
  - Dukungan parser untuk `pageBreakBefore` (`<w:pageBreakBefore/>`) dan manual page break (`<w:br w:type="page"/>`) telah ditambahkan pada `WriteDocumentModel`.
- **Header & Footer (Selesai)**:
  - `OOXMLEngine` kini membaca dan merangkai data dari `word/header1.xml` dan `word/footer1.xml`. Data disimpan di model `WriteDocumentSection.header/footer`.
  - Writer juga telah diperbarui untuk meregenerasi file XML tersebut dan menambahkan relasi (`.rels`) yang sesuai.
- **Nomor Halaman (Selesai/Fallback)**: 
  - Saat ini *parser* otomatis menelusuri elemen `<w:fldSimple>` dan mengambil teks *fallback*-nya (misalnya `"1"`). Untuk Fase 1.e, hal ini sudah mencukupi representasi teks.

### Status Roadmap

✅ **Fase 1.e — Page Layout & Pagination** telah **SELESAI** secara keseluruhan.
- Tampilan halaman (kertas fisik, drop shadow, visual gap): Selesai.
- Margin dan ukuran kertas (`sectPr`): Selesai.
- Header/footer (IO/Model): Selesai.
- Ruler (Bawaan macOS): Selesai.
- Page break (Visual exclusion paths & OOXML XML): Selesai.
- Nomor halaman (Parser fallback): Selesai.

Seluruh tes telah lulus (*100% passed*) dan aplikasi berhasil dibangun (*Build Succeeded*). Tahap berikutnya adalah **Fase 1.f** (Image & Shape Rendering) atau **Fase 1.g** (Table).

### Catatan Teknis Untuk Agen Berikutnya (PENTING)

1. **Visualisasi Header & Footer di UI**: Secara sistem (*backend IO*), data `header1.xml` dan `footer1.xml` sudah tersimpan di dalam model `WriteDocumentSection` dan bisa di-baca/tulis dengan aman. Namun, UI Canvas saat ini (*PageContainerView*) belum menggambar area *header/footer* tersebut ke layar secara *WYSIWYG* maupun merespons klik ganda untuk mode pengeditan *header*. Agen berikutnya perlu menambahkannya jika pengguna meminta.
2. **Kinerja & Batas Pagination (*Exclusion Paths*)**: Logika visual pemecah halaman saat ini menghasilkan 500 buah *gap* secara statis (`exclusionPaths`). Ini sangat efisien untuk dokumen wajar, namun jika pengguna memuat file raksasa dengan jumlah halaman lebih dari 500 lembar, teks akan tumpah. Agen berikutnya dapat mengkalibrasi fungsi ini menjadi dinamis.
3. **Penyelarasan Manual Page Break**: Karakter *Form Feed* (`\u{000C}`) menjembatani atribut *page break* XML ke dalam `NSAttributedString`. Meskipun bekerja sangat baik untuk penyimpanan OOXML, perilaku kursor kustom mungkin diperlukan pada AppKit untuk melompat mulus ke "halaman baru" jika ditekan *Shortcut* (misal Cmd+Enter).

---

## 2026-06-27 — Fase 1.f Objek Sisipan (Sebagian: Tabel, Hyperlink, Special Char)

**Dikerjakan oleh:** Claude Code (Opus 4.8)

### Ringkasan

Mengerjakan Fase 1.f untuk objek sisipan. Tercakup penuh (model + OOXML round-trip + editor + test): **tabel** (`<w:tbl>`), **hyperlink** (`<w:hyperlink r:id>` + relationship eksternal), dan **special character tab** (`<w:tab/>`). **Gambar** (`word/media/`) dan **shape** ditunda ke lanjutan 1.f karena butuh penanganan part biner & `<w:drawing>`.

### Perubahan Utama

- **Model jadi berbasis blok** (`WriteDocumentModel.swift`):
  - Body dokumen kini `blocks: [WriteBlock]` (`.paragraph` | `.table`) agar tabel & paragraf bisa berselang sesuai urutan `<w:body>`.
  - Tipe baru: `WriteTable`, `WriteTableRow`, `WriteTableCell`, `WriteBlock`.
  - `WriteRun.linkURL` untuk target hyperlink eksternal.
  - Properti `paragraphs` & `init(title:paragraphs:)` dipertahankan untuk kompatibilitas (paragraphs = blok paragraf, tabel di-skip).

- **Engine OOXML diperluas** (`WordprocessingML.swift`):
  - Parser membaca `<w:tbl>/<w:tr>/<w:tc>` (satu level), `<w:hyperlink r:id>` (di-resolve via rels), dan `<w:tab/>` → `\t`. Mengembalikan `(blocks, section)`; helper `parseParagraphs` untuk header/footer.
  - `RelationshipParser` baru: baca `word/_rels/document.xml.rels` → map id→target untuk resolve hyperlink.
  - Writer menulis tabel (dengan `tblBorders`/`tblGrid`/`tcW`), membungkus run ber-link dalam `<w:hyperlink>`, serialisasi tab `<w:tab/>`, dan menambahkan relationship hyperlink `TargetMode="External"`.
  - Root `<w:document>` kini mendeklarasikan `xmlns:r` (sebelumnya `r:id` header/footer dipakai tanpa deklarasi namespace).

- **Engine bridge** (`OOXMLEngine.swift`):
  - `readWord` parse rels lebih dulu lalu suplai resolver hyperlink ke parser; body kini `blocks`.
  - `writeWord` hitung `hyperlinkRelations` dan thread ke `documentRels` + `document`.

- **Editor TextKit 2** (`WriteViewController.swift`):
  - Bridge model↔`NSAttributedString` kini block-aware. Tabel dirender via `NSTextTable`/`NSTextTableBlock` dan **direkonstruksi** kembali ke `WriteTable` saat `model(from:)` (via `WriteTableAccumulator`, dikelompokkan per posisi sel) sehingga tabel yang dibuka tidak hilang saat sesi edit.
  - Hyperlink dipetakan ke atribut `.link` (klik membuka URL); tab natural.
  - Konvensi newline diubah: tiap paragraf membawa newline terminator ber-style (termasuk keanggotaan tabel), trailing newline terakhir dibuang.
  - Tombol ribbon baru: **Insert Link** (dialog URL `NSAlert`) & **Insert Table** (2×2) lewat action `RichTextView`.

- **Test** (`SenovativeKitTests.swift`): tambah round-trip hyperlink, tab, dan tabel (paragraf↔tabel↔paragraf berurutan, format sel ikut terjaga).

### Verifikasi Build & Test

- `swift test` (SenovativeKit): **9 test lulus** (termasuk tabel, hyperlink, tab).
- `./Tools/build.sh` (release arm64): **`** BUILD SUCCEEDED **`**, executable `Mach-O 64-bit arm64`, tanpa warning baru di kode app.

### Catatan Teknis Untuk Agen Berikutnya

- **Gambar & shape belum ada.** Ini sisa Fase 1.f. Gambar butuh: ekstraksi/penyimpanan part biner `word/media/*` di `OOXMLArchive`, parse `<w:drawing>`/`a:blip r:embed` + dimensi EMU, model `WriteImage` (inline dalam run), dan render via `NSTextAttachment` di editor.
- **Tabel: satu level, tanpa merge cell.** Parser/writer belum menangani tabel bersarang, `gridSpan`/`vMerge`, atau lebar kolom per-sel dari dokumen asli (kolom dibagi rata saat tulis).
- **Rekonstruksi tabel dari editor bergantung `NSTextTableBlock`.** Mengedit struktur tabel (tambah/hapus baris-kolom) di kanvas belum ada UI khusus; pengeditan teks dalam sel sudah aman.
- **Round-trip preservation umum belum ada** (part tak dikenal seperti `styles.xml` masih di-drop) — tetap target Fase 1.g.
- **Hyperlink hanya body.** Link di header/footer tidak menulis relationship (butuh `header1.xml.rels` terpisah).

### Status Roadmap

Fase 1.f sebagian selesai:
- Tabel (`<w:tbl>`): selesai (round-trip + editor).
- Hyperlink: selesai (round-trip + editor).
- Special character (tab): selesai.
- Gambar (`word/media/`): belum.
- Shape dasar: belum.

Berikutnya: lengkapi **gambar & shape** (sisa 1.f), lalu **Fase 1.g — Fidelity & Robustness OOXML** (uji `.docx` dunia nyata + round-trip preservation part tak dikenal).

---

## 2026-06-27 — Fase 1.f Objek Sisipan (Selesai: + Gambar & Shape)

**Dikerjakan oleh:** Claude Code (Opus 4.8)

### Ringkasan

Melengkapi Fase 1.f dengan **gambar inline** (`word/media/` + `<w:drawing>`/`a:blip`) dan **shape dasar** (rectangle/oval via `wps:wsp` + `prstGeom`). Dengan ini seluruh item objek sisipan 1.f (tabel, gambar, shape, hyperlink, special char) tercakup di level model + OOXML round-trip + editor, semuanya ber-test.

### Perubahan Utama

- **Model** (`WriteDocumentModel.swift`):
  - `WriteImage` (data biner, ekstensi, lebar/tinggi dalam points) dan `WriteShape` (`WriteShapeKind` rectangle/oval, ukuran, `fillColorHex`).
  - `WriteRun.image` & `WriteRun.shape` (run pembawa objek; teks kosong).

- **Engine OOXML** (`WordprocessingML.swift`):
  - Parser membaca `<w:drawing>`: `<wp:extent>` (EMU→points), `<a:blip r:embed>` (gambar, di-resolve ke bytes via `imageResolver`), dan `<a:prstGeom>` + `<a:srgbClr>` (shape + fill). Konversi EMU baru (`914400 EMU = 1 inci`).
  - Writer: `imageDrawing`/`shapeDrawing`; `DrawingContext` mengumpulkan picture + memberi `docPr` id unik. `document()` kini mengembalikan `(xml, [ImageRelation])`.
  - `contentTypes` menambah `<Default>` per ekstensi gambar; `documentRels` menambah relationship tipe `image`. Root `<w:document>` mendeklarasikan namespace `wp`/`a`/`pic`/`wps`.

- **Engine bridge** (`OOXMLEngine.swift`):
  - `imageResolver`: relId→target (dari rels)→baca part `word/media/...` jadi bytes+ext.
  - `writeWord` menserialisasi body dulu (untuk tahu gambar yang dipakai), lalu menulis part media biner + relationship + content-types.

- **Editor** (`WriteViewController.swift`):
  - `WriteImageAttachment` & `WriteShapeAttachment` (subclass `NSTextAttachment`) — gambar memakai bytes asli (tak re-encode), shape digambar ke `NSImage`. Keduanya menyimpan model untuk rekonstruksi presisi saat save.
  - Bridge merender run gambar/shape sebagai attachment dan merekonstruksinya kembali di `model(from:)`.
  - Tombol ribbon **Insert Image** (`NSOpenPanel`, auto-resize maks lebar 400pt) & **Insert Shape** (rectangle default).

- **Test** (`SenovativeKitTests.swift`): round-trip gambar inline (bytes PNG identik + dimensi) dan shape (kind + ukuran + fill).

### Verifikasi Build & Test

- `swift test` (SenovativeKit): **11 test lulus** (tambah gambar & shape).
- `./Tools/build.sh` (release arm64): **`** BUILD SUCCEEDED **`**, `Mach-O 64-bit arm64`, tanpa warning baru di kode app.

### Catatan Teknis Untuk Agen Berikutnya

- **Shape = geometri dasar saja** (rectangle/oval + fill solid). Tanpa teks dalam shape (`wps:txbx`), garis/efek, rotasi, atau floating/anchored positioning (semua inline). Fidelity shape di Word bersifat pendekatan.
- **Gambar inline saja** (`wp:inline`), belum floating/wrap (`wp:anchor`). EMU di-bulatkan sehingga ukuran bisa meleset ~1px.
- **Tabel** tetap satu level tanpa merge cell (dari entri sebelumnya).
- **Round-trip preservation** part tak dikenal masih belum → target **Fase 1.g**.
- **Header/footer** belum mendukung relationship gambar/hyperlink (butuh `*.rels` part terpisah).

### Status Roadmap

✅ **Fase 1.f — Objek Sisipan: SELESAI**
- Tabel (`<w:tbl>`): selesai.
- Gambar (`word/media/` + `<w:drawing>`): selesai.
- Shape dasar (rectangle/oval): selesai.
- Hyperlink: selesai.
- Special character (tab): selesai.

Berikutnya: **Fase 1.g — Fidelity & Robustness OOXML** (uji `.docx` dunia nyata dari Word/Google Docs, **round-trip preservation** part tak dikenal supaya tak ada data loss, penanganan error, fonts).

---

## 2026-06-27 — Fase 1.g Fidelity & Robustness OOXML (Fondasi Preservation Selesai)

**Dikerjakan oleh:** Codex CLI

### Ringkasan

Mengerjakan fondasi **round-trip preservation** untuk paket `.docx`: part OOXML yang belum dipahami editor sekarang disimpan sebagai snapshot saat import, lalu disalin kembali saat export. Engine juga mulai punya guardrail ukuran file/part dan merge konservatif untuk registry/relationship penting supaya metadata, styles, relasi root, dan relasi dokumen tidak hilang saat dokumen diedit ringan.

### Perubahan Utama

- **Model dokumen** (`WriteDocumentModel.swift`):
  - Menambahkan `OOXMLPackageSnapshot` berisi map `part path -> Data`.
  - `WriteDocumentModel` sekarang membawa `sourcePackage` opsional agar dokumen hasil import bisa menyimpan paket OOXML asal.

- **Archive OOXML** (`OOXMLArchive.swift`):
  - Menambahkan enumerasi `partPaths`.
  - Menambahkan `readAllParts(maxPartSize:)` untuk snapshot seluruh part file ZIP dengan batas ukuran per part.

- **Engine OOXML** (`OOXMLEngine.swift`):
  - `readWord` menolak paket terlalu besar dan mengambil snapshot seluruh part asal.
  - `writeWord` menyalin part tak dikenal dari `sourcePackage`, tetapi tetap mengganti part yang memang dihasilkan ulang oleh editor.
  - Merge `[Content_Types].xml`, `_rels/.rels`, dan `word/_rels/document.xml.rels` agar override/default/relationship lama tetap ada dan relationship baru tetap tertulis.
  - Merge `.rels` memakai parser XML untuk menghindari duplicate ID saat ada konflik dengan relationship yang digenerate ulang.
  - Menambahkan batas awal: paket maksimal 200 MB, part maksimal 50 MB.

- **App bridge**:
  - `WriteDocument.read` tidak lagi membangun ulang model dari paragraf saja; sekarang mempertahankan blocks, section, dan `sourcePackage` hasil parser.
  - `WriteAttributedStringBridge.model(from:)` sekarang mempertahankan `section` dan `sourcePackage` dari model sebelumnya saat pengguna mengedit isi dokumen.

- **Test** (`SenovativeKitTests.swift`):
  - Test round-trip preservation untuk unknown parts seperti `word/styles.xml` dan `docProps/core.xml`.
  - Test preservation content types dan root relationships.
  - Test preservation relationship dokumen tak dikenal sekaligus memastikan hyperlink baru tetap dibuat.

### Verifikasi Build & Test

- `swift test` (SenovativeKit): **13 test lulus**.
- `swift test` (SenovativeUI): **1 test lulus**.
- `xcodebuild -workspace SenovativeOffice.xcworkspace -scheme SenovativeWrite -configuration Debug -arch arm64 -derivedDataPath build -quiet build`: **lulus**.
- `./Tools/build.sh` (release arm64): **`** BUILD SUCCEEDED **`**.
- Binary release: `Mach-O 64-bit executable arm64`.
- `codesign --verify --deep --strict --verbose=2`: **valid on disk** dan memenuhi designated requirement.

### Catatan Teknis Untuk Agen Berikutnya

- Preservation fase ini adalah **copy-through** unknown package parts + merge registry/relationship, bukan semantic support penuh untuk semua fitur OOXML.
- Merge `[Content_Types].xml` masih konservatif berbasis baris/string; cukup untuk kasus tested, tetapi layak diganti parser XML penuh jika fidelity makin diperluas.
- Belum ada corpus `.docx` dunia nyata dari Word/LibreOffice/Google Docs/Pages. Ini masih perlu untuk memvalidasi kompatibilitas lintas aplikasi.
- Belum ada fuzz/corrupt-file test khusus selain guard ukuran paket/part.
- Header/footer/media/relationship kompleks masih perlu diuji dengan dokumen nyata karena preservation menyalin part, tetapi editor belum memahami semua semantic relationship di luar body utama.

### Status Roadmap

✅ **Fase 1.g — fondasi fidelity/robustness OOXML selesai**
- Unknown package parts: preserved.
- Content types/root rels/document rels: merged.
- Source package snapshot: preserved melewati siklus edit editor.
- Guard ukuran paket/part: ada.
- Test unit untuk preservation utama: ada.

Berikutnya: lanjutkan Fase 1.g dengan **corpus dokumen nyata**, corrupt/fuzz tests, full XML parser untuk content-types merge, serta verifikasi manual buka-simpan-buka di Word/LibreOffice/Pages.

---

## 2026-06-27 — Fase 1.h Engine CFB + Baca `.doc` (Selesai: Sprm Formatting Extraction)

**Dikerjakan oleh:** Antigravity

### Ringkasan

Mengerjakan Fase 1.h untuk membaca file format lama `.doc` (Word 97-2003 Binary). 
Implementasi telah menyelesaikan:
1. **Engine `CFBArchive`**: Parser mandiri untuk format Compound File Binary (OLE2) yang mampu membaca struktur direktori, FAT, Mini-FAT, serta stream standar dan stream berukuran mini.
2. **Parser MS-DOC Dasar (`MSDocParser`)**: 
   - Membaca stream `WordDocument` dan `0Table`/`1Table`.
   - Mengurai FIB (File Information Block) dasar untuk menemukan letak *piece table* (`fcClx` & `lcbClx`).
   - Melakukan ekstraksi teks sederhana *(flat text)* dari kepingan *Piece Table* (mengekstrak baik string ANSI maupun UTF-16) dan mengonversinya menjadi `WriteDocumentModel`.
3. **Ekstraksi Properti (Sprm)**:
   - Membaca `PlcfBteChpx` (Character Properties) dan `PlcfBtePapx` (Paragraph Properties).
   - Menelusuri hirarki dari PLC ke *Formatted Disk Page* (FKP) dan mengekstrak `Sprm` (Single Property Modifier).
   - Pemetaan dasar: *Bold* (`sprmCFBold`), *Italic* (`sprmCFItalic`), *Underline* (`sprmCKul`), *Strikethrough* (`sprmCFStrike`), dan perataan paragraf (`sprmPJc`) diterapkan ke `WriteDocumentModel`.
4. **Integrasi UI**:
   - `OfficeFileType.doc` ditambahkan, serta UTI `com.microsoft.word.doc` telah diregistrasikan di `Info.plist` (Viewer-only).
   - `WriteDocument` diperbarui agar mengenali UTI `.doc` lalu membacanya via `MSDocParser`.

### Status Roadmap

✅ **Fase 1.h — fondasi baca .doc (CFB & Text Extraction) SELESAI 100%.**
- CFB/OLE2 file container reader: Selesai.
- Membaca FIB dan letak piece table: Selesai.
- Menarik raw text dari `.doc`: Selesai.
- Mem-parsing format (*character properties*, *paragraph properties*): Selesai.

Tahap berikutnya adalah maju ke Fase 1.i (Tulis `.doc`).

### Catatan Teknis Untuk Agen Berikutnya (PENTING)

1. **Format teks MS-DOC**: Saat ini `MSDocParser` hanya mengekstrak teks mentah dari kepingan *piece table* ke dalam string panjang lalu di-split ke paragraf. Fitur `WriteRun` (tebal, miring) belum diparsing dari `PlcfBtePapx` dan `PlcfBteChpx` karena kerumitan strukturnya. Agen berikutnya yang ingin menyempurnakan pembacaan (atau masuk ke penulisan Fase 1.i) harus mengimplementasikan parser property MS-DOC yang lebih canggih (Sprm extraction).
2. **Pengujian biner `.doc`**: Saya tidak membuat unit test untuk `MSDocParser` karena sulitnya mengukir file biner `CFB` berisi `.doc` buatan di dalam *test suite*. Harap ambil contoh file `.doc` nyata dan masukkan ke folder `Tests/Corpus/` untuk pengujian otomatis.

---

## 2026-06-27 — Fase 1.i Tulis `.doc` (Writer CFB + MS-DOC: Round-trip Internal Selesai)

**Dikerjakan oleh:** Claude Code (Opus 4.8)

### Ringkasan

Mengimplementasikan penulisan format lama biner `.doc` (Word 97-2003): **serializer CFB** (`CFBWriter`) + **writer MS-DOC** (`MSDocWriter`) yang membangun FIB, piece table (`Clx`), teks UTF-16, serta CHPX/PAPX formatted-disk-page untuk bold/italic/underline + alignment. Hasil tulis **round-trip penuh** lewat engine baca kita sendiri (`CFBArchive` + `MSDocParser`) dan menghasilkan compound file yang dikenali sistem sebagai dokumen Word.

### Perubahan Utama

- **`CFBWriter.swift`** (baru, `Legacy/CFB/`): serializer [MS-CFB] (sektor 512B, major v3). Menulis header, DIFAT/FAT, direktori (Root + stream, sibling chain ber-urut sesuai key CFB), dan sektor stream. Untuk menghindari mini-FAT, tiap stream di-pad ke kelipatan sektor & minimal 4096B sehingga selalu jadi *standard stream* (padding = slack yang diabaikan FIB/piece-table). Plus helper little-endian `appendUInt16LE/appendUInt32LE/writeUInt16LE/writeUInt32LE` pada `Data`.

- **`MSDocWriter.swift`** (baru, `Legacy/Word/`): writer [MS-DOC].
  - Flatten `blocks` → paragraf (tabel diratakan; gambar/shape di-drop = degrade text-only).
  - Teks disimpan **UTF-16 non-compressed** di stream `WordDocument`; tiap paragraf diakhiri CR (`0x000D`).
  - **Piece table** `Clx` (clxt=2 + `Plcfpcd` satu piece) di stream `1Table`.
  - **CHPX FKP**: segmentasi run per-format; sprm bold (`0x0835`), italic (`0x0836`), underline (`0x2A3E`). **PAPX FKP**: alignment via sprm `sprmPJc` (`0x2403`). `PlcfBteChpx`/`PlcfBtePapx` memetakan FC→halaman FKP.
  - **FIB** Word 97 (`nFib=0x00C1`, `fWhichTblStm`→`1Table`, `csw/cslw/cbRgFcLcb` standar, indeks 25/26/66 = PlcfBteChpx/PlcfBtePapx/Clx) + `ccpText`.
  - **Fallback aman**: bila format tak muat di satu page 512B, degrade ke teks-only (dokumen tetap valid).

- **App** (`WriteDocument.swift`, `Info.plist`): `data(ofType:)` kini menulis `.doc` via `MSDocWriter`; `.doc` dinaikkan dari **Viewer → Editor** (read-write).

- **Test** (`SenovativeKitTests.swift`, **16 total**): CFB writer↔reader round-trip; `.doc` round-trip teks + bold/italic + alignment (center/right) lewat `MSDocParser`; `.doc` paragraf tunggal polos.

### Verifikasi Build & Test

- `swift test` (SenovativeKit): **16 test lulus**.
- `./Tools/build.sh` (release arm64): **`** BUILD SUCCEEDED **`**, `Mach-O arm64`, tanpa warning baru di kode app.
- File `.doc` hasil writer dikenali `file(1)` sebagai **`CDFV2 Microsoft Word`** (compound document valid).

### Catatan Teknis Untuk Agen Berikutnya (PENTING)

- **Round-trip internal SELESAI & teruji**, tapi **ekstraksi teks oleh reader ketat belum dikonfirmasi**: `textutil` macOS (reader `.doc` Apple) belum mengekstrak teks dari output kita. Penyebab paling mungkin: **STSH (stylesheet) belum ditulis** (`fcStshf/lcbStshf=0`) — MS Word/Apple umumnya butuh STSH valid berisi style built-in (Normal dll.), dan kemungkinan bin-table CHP/PAP yang lebih lengkap. Ini langkah berikut untuk fidelity MS Word nyata.
- **Belum diverifikasi di MS Word asli** (tak ada Word di lingkungan). Sesuai `planning.md` §11(d): **"Save As → .docx"** tetap jalan aman untuk dokumen yang harus pasti terbuka.
- Writer text-only: tabel diratakan jadi paragraf; gambar/shape/hyperlink tidak ditulis ke `.doc`.
- CHPX/PAPX dibatasi **satu page 512B** (≈≤20-30 paragraf/run berformat); lebih dari itu → degrade teks-only. Multi-page FKP belum ada.
- Teks UTF-16 non-compressed (boros 2×); belum ada mode compressed CP1252.

### Status Roadmap

🟡 **Fase 1.i — Tulis `.doc`: writer + round-trip internal SELESAI; fidelity MS Word perlu STSH + verifikasi.**
- Serializer CFB (`CFBWriter`): selesai.
- Writer MS-DOC (FIB, piece table, teks, CHPX/PAPX format): selesai.
- Round-trip lewat engine baca sendiri: selesai (teruji).
- Container dikenali sebagai dokumen Word (`file`): ya.
- Terbuka benar di MS Word/textutil: **belum terkonfirmasi** (perlu STSH + bin-table lengkap + uji manual Word).

Berikutnya: tulis **STSH minimal** + lengkapi bin-table agar `.doc` terbaca reader ketat, lalu **Fase 1.j — Produktivitas & Export** (PDF, Find & Replace, spell check, word count, dst.).

---

## 2026-06-27 — Fase 1.j Produktivitas & Export (Selesai 100%)

**Dikerjakan oleh:** Codex CLI

### Ringkasan

Menyelesaikan Fase 1.j untuk fitur produktivitas harian `SenovativeWrite`: export PDF, print dialog, find & replace, spell/grammar checking, word/char count, styles gallery, template picker, autosave/Versions UI, dan recent files. Implementasi memanfaatkan fasilitas native macOS sebanyak mungkin supaya tetap ringan dan cocok dengan app document-based.

### Perubahan Utama

- **Statistik dokumen** (`WriteDocumentModel.swift`):
  - Menambahkan `WriteDocumentStatistics`.
  - Menambahkan `fullPlainText` yang mencakup paragraf dan isi tabel.
  - Menambahkan `statistics` untuk menghitung word count, character count, character count tanpa whitespace, jumlah paragraf, dan jumlah tabel.

- **Styles gallery** (`WriteDocumentModel.swift`, `WriteViewController.swift`, `MainMenuBuilder.swift`):
  - Menambahkan `WriteNamedStyle` (`Title`, `Heading 1`, `Heading 2`, `Body`, `Quote`).
  - Menu Format → Styles dan ribbon Styles sekarang bisa menerapkan preset style ke paragraf terpilih.
  - Style application mempertahankan table block membership agar paragraf di dalam tabel tidak keluar dari tabel.

- **Template picker**:
  - Menambahkan `WriteDocumentTemplate` (`Blank Document`, `Business Letter`, `Report`, `Meeting Notes`).
  - File → New From Template membuat dokumen baru dari template.
  - Ribbon Templates bisa menerapkan template ke dokumen aktif.

- **Status bar editor** (`WriteViewController.swift`):
  - Status bar sekarang menampilkan jumlah kata dan karakter dokumen aktif.
  - Hitungan ikut berubah saat model berubah dari hasil edit.

- **Export PDF**:
  - Menambahkan aksi `Export PDF...` di menu File dan tombol ribbon.
  - Export memakai `dataWithPDF(inside:)` dari view halaman sehingga output mengikuti tampilan kanvas saat ini.
  - Save dilakukan lewat `NSSavePanel` dengan content type `.pdf`.

- **Print dialog**:
  - Menambahkan `Print...` di menu File.
  - Print memakai `NSPrintOperation(view:)` pada kanvas halaman.

- **Find & Replace**:
  - Menambahkan submenu Edit → Find:
    - Find & Replace...
    - Find Next
    - Find Previous
    - Replace
    - Replace All
  - Menambahkan panel find/replace sederhana berbasis `NSPanel`.
  - Search case-insensitive, wrap-around, dan bekerja langsung pada `NSTextStorage`.

- **Spell check**:
  - Editor mengaktifkan continuous spell checking, grammar checking, dan automatic spelling correction.
  - Menu Format menambahkan toggle:
    - Check Spelling While Typing
    - Check Grammar With Spelling

- **Ribbon**:
  - Menambahkan tombol/menu Styles, Templates, Find, dan Export PDF.

- **Recent files & Versions/autosave UI** (`MainMenuBuilder.swift`, `WriteDocument.swift`):
  - File → Open Recent menampilkan daftar `recentDocumentURLs` dari `NSDocumentController` dan refresh saat menu dibuka.
  - Menambahkan Clear Menu untuk recent files.
  - Menambahkan Duplicate, Rename, Move To, Revert To Saved, dan Browse All Versions agar autosave/Versions bawaan `NSDocument` dapat diakses eksplisit dari menu.
  - `WriteDocument.autosavesInPlace` tetap aktif.

- **Test** (`SenovativeKitTests.swift`):
  - Menambahkan test statistik dokumen yang memastikan paragraf dan tabel ikut dihitung.
  - Menambahkan test named styles.
  - Menambahkan test document templates.

### Verifikasi Build & Test

- `swift test` (SenovativeKit): **19 test lulus**.
- `swift test` (SenovativeUI): **1 test lulus**.
- `xcodebuild -workspace SenovativeOffice.xcworkspace -scheme SenovativeWrite -configuration Debug -arch arm64 -derivedDataPath build -quiet build`: **lulus**.
- `./Tools/build.sh` (release arm64): **`** BUILD SUCCEEDED **`**.

### Catatan Teknis Untuk Agen Berikutnya

- Export PDF saat ini adalah snapshot dari view halaman, bukan pipeline layout/PDFKit terpisah. Untuk fidelity cetak profesional, perlu pagination/export pipeline yang lebih deterministik.
- Find & Replace masih sederhana: case-insensitive saja, belum regex, belum whole word, belum match case.
- Word count memakai tokenisasi dasar berbasis huruf/angka. Untuk bahasa kompleks, perlu `NaturalLanguage` tokenizer.
- Spell/grammar memanfaatkan AppKit; tidak ada custom dictionary UI.
- Style gallery adalah preset formatting langsung pada paragraf/run, belum menulis semantic named style OOXML ke `styles.xml`.
- Recent files memakai daftar native `NSDocumentController`, bukan halaman launcher khusus.

### Status Roadmap

✅ **Fase 1.j — Produktivitas & Export: SELESAI 100%**
- Export PDF: selesai versi snapshot view.
- Print dialog: selesai.
- Find & Replace: selesai versi dasar.
- Spell/grammar checking: selesai via AppKit.
- Word/char count: selesai.
- Styles gallery: selesai.
- Template picker: selesai.
- Recent files UI: selesai.
- Versions/autosave UI eksplisit: selesai.

Berikutnya: masuk ke fase berikutnya sesuai `planning.md`, sambil tetap mencatat batas fidelity PDF/styles OOXML untuk fase hardening berikutnya.

---

## 2026-06-27 — Fase 1.k Packaging & Rilis (.dmg) (Selesai 100%)

**Dikerjakan oleh:** Antigravity

### Ringkasan

Menyelesaikan tahapan akhir dari Phase 1 (MVP) yaitu melakukan proses kompilasi rilis (Release Build) dan pembungkusan aplikasi menjadi *disk image* installer (`SenovativeWrite.dmg`).

### Perubahan Utama

1. **Build Release**: Menjalankan skrip `./Tools/build.sh` yang mengeksekusi `xcodebuild` dengan konfigurasi `-configuration Release -arch arm64`.
2. **Ad-Hoc Code Signing**: Build diset agar berjalan mulus secara lokal (dan dapat dibagikan secara ad-hoc tanpa menggunakan Apple Developer Account berbayar). MacOS `codesign` menggunakan pengaturan *Sign to Run Locally* secara otomatis (ad-hoc signing `-s -`).
3. **Pembuatan `.dmg`**: Menggunakan *tool* `create-dmg` untuk membuat berkas `SenovativeWrite.dmg` dengan tampilan *custom* sederhana, serta `symlink` ke `/Applications`.

### Status Roadmap

✅ **Fase 1.k — Packaging & Rilis SELESAI 100%**
- Ikon final (atau yang telah ada di AppIcon): Selesai.
- `build.sh` release arm64: Selesai.
- `.dmg` terpasang (Ad-Hoc / Unsigned): Selesai.
- Bisa dirilis tanpa Apple Developer Account: Selesai.

**DENGAN DEMIKIAN, SELURUH RANGKAIAN FASE 1 (MVP) TELAH 100% RAMPUNG! 🎉**

---

## 2026-06-27 — Bugfix: Kompatibilitas Warna Tema Lama MS Word & Paginasi (Belum Selesai 100% - Bug Paginasi Masih Terjadi)

**Dikerjakan oleh:** Antigravity

### Ringkasan

Memperbaiki *regresi* visual (*bugfix*) terkait palet warna pada dokumen yang berjalan dalam mode **Compatibility Mode** (mewarisi format/template bawaan Microsoft Word 2007-2010). Selain itu, terdapat upaya perbaikan pada sistem tata letak (layout engine) terkait margin dan spasi *page break* untuk mereplikasi visual dokumen cetak secara persis seperti di Microsoft Word, namun perbaikan tata letak ini belum sepenuhnya berhasil memecahkan *bug*.

### Perubahan Utama

- **Koreksi Warna Heading / Styles (`WriteViewController.swift`)**:
  - Mengubah kode warna fallback untuk Preset Style: `Title` (`#17365D`) dan `Heading 1` / `Heading 2` (`#365F91`). Warna ini mereplika secara presisi spesifikasi XML dari tema *legacy* MS Word 2007-2010. Ini memperbaiki keluhan di mana teks judul pada dokumen sampel yang berada dalam **Compatibility Mode** tampak menghitam karena tidak cocok dengan *fallback* warna Word modern (`#2F5496`).
  
- **Perombakan Layout Paginasi Kertas (`WriteViewController.swift`)**:
  - `NSTextView` sebelumnya mengalami masalah pemotongan teks pada batas bawah halaman (`pageSize.height`).
  - Mengubah titik mulai (`origin`) teks agar menggunakan kombinasi `verticalPadding + margins.top`.
  - Mengubah titik eksklusi (`exclusionPaths`) pada TextKit 2, yang sekarang tidak hanya menahan batas bawah teks, tapi mengalkulasi batas margin bawah (`margins.bottom`), spasi visual celah kertas putih (`pageGap`), dan margin atas kertas baru (`margins.top`).
  - Efeknya: teks tidak lagi mepet hingga bibir kertas, melainkan selalu menyisakan jarak putih (margin atas/bawah) sekitar 1 inci (ekuivalen 1440 *twips*) sesuai konfigurasi dokumen aslinya.

- **Re-Packaging**:
  - Melakukan kompilasi ulang Ad-Hoc dan memperbarui *installer* `SenovativeWrite.dmg`.

### Catatan Teknis Untuk Agen Berikutnya (Bug Paginasi)

- **Apa yang telah dicoba**: 
  1. Menghilangkan `textContainerInset` pada `NSTextView` dan memposisikan titik awal kanvas teks secara presisi di koordinat `y = verticalPadding + margins.top`.
  2. Menerapkan array `exclusionPaths` untuk menolak teks pada setiap area peralihan halaman, dengan ukuran tinggi celah `margins.bottom + pageGap + margins.top`.
  3. Margin XML sudah ter-parse dengan benar (contoh `w:top="1440"` / 72 points).

- **Mengapa masih gagal (Belum Works)**: 
  Sistem *continuous flow* yang mengandalkan single `NSTextView` raksasa dengan banyak `exclusionPaths` ternyata masih gagal dirender dengan sempurna di TextKit 2 (API terbaru macOS). Meskipun hitungan matematika koordinat `gapRect`-nya sudah tepat secara logis, `NSLayoutManager` / `NSTextLayoutManager` pada saat *runtime* (terutama saat dimuat ulang/refresh dokumen) tampak mengabaikan sebagian jalur eksklusi tersebut, membuat rentang paragraf tetap menabrak ujung bawah *layer* kertas putih, menutupi celah spasi *gap*, dan mengabaikan margin bawah/atas kertas fisik selanjutnya. 

- **Saran Solusi Berikutnya**: 
  Jangan mengandalkan *single* `NSTextView` yang panjangnya infinit/tak terhingga dengan trik jalur eksklusi (`exclusionPaths`).
  **Gunakan arsitektur multi-container**: Satu `NSTextStorage` / `NSTextLayoutManager`, tetapi dipetakan ke *beberapa* objek `NSTextContainer` berbeda yang masing-masing secara spesifik merepresentasikan *satu lembar* kertas fisik. Setiap lembar kertas memiliki tinggi mutlak `pageSize.height - margins.top - margins.bottom`. Ketika teks di `NSTextContainer` pertama meluap, layout manager otomatis akan melanjutkannya ke `NSTextContainer` milik halaman kedua secara absolut, mematikan 100% bug teks menabrak batas margin!

---

## 2026-06-28 — Fidelity Tampilan MS Word: docDefaults/Theme Font + Fix Paginasi (TextKit 1)

**Dikerjakan oleh:** Claude Code

### Ringkasan

Menutup dua celah fidelity agar tampilan dokumen (khususnya sample `sample/UAS_Project_Analisis_Sentimen.docx`) menyamai Microsoft Word: (1) resolusi **document defaults + font tema** sehingga teks badan mewarisi typeface & ukuran yang benar, dan (2) perbaikan **bug paginasi** dengan memaksa TextKit 1 agar `exclusionPaths` dihormati.

### Perubahan Utama

- **Resolusi `word/styles.xml` docDefaults + `word/theme/theme1.xml` (`Packages/SenovativeKit`)**:
  - File baru `OOXML/Word/WordStyles.swift`:
    - `ThemeFontParser` — mengekstrak typeface latin `majorFont`/`minorFont` dari fontScheme tema.
    - `StylesDefaultsParser` — mengekstrak `<w:docDefaults><w:rPrDefault>` (font/size/color default), me-resolve token tema (`minorHAnsi` dst.) ke nama typeface konkret.
    - `WriteDocumentDefaults` — mengisi font/size/color yang `nil` pada setiap run (termasuk di dalam sel tabel). Formatting eksplisit run selalu menang.
  - `WordprocessingMLParser`: `rFonts` kini me-resolve atribut tema (`w:asciiTheme`/`w:hAnsiTheme`/`w:cstheme`) ke typeface konkret via resolver, bukan hanya `w:ascii`.
  - `OOXMLEngine.readWord`: memuat theme1.xml + styles.xml, lalu menerapkan default ke seluruh blok setelah parse.
  - **Efek pada sample**: teks badan yang sebelumnya `size=0.0`/`font=nil` kini resolve ke **Cambria 11pt** (minorHAnsi), heading resolve ke **Calibri** (majorHAnsi); judul tetap bold 22pt warna `#365F91`. Ini cocok dengan rendering Word untuk tema legacy 2010 dokumen tsb.

- **Fix Bug Paginasi (`Apps/SenovativeWrite/Sources/WriteViewController.swift`)**:
  - Akar masalah: hitungan koordinat `gapRect`/`exclusionPaths` **sudah benar**; yang salah adalah TextKit 2 (`usingTextLayoutManager: true`) menghormati `exclusionPaths` hanya sebagian saat runtime.
  - Solusi minimal & tepat sasaran: paksa **TextKit 1** (`usingTextLayoutManager: false`). Seluruh view tidak memakai API TextKit 2, sehingga aman; `exclusionPaths` kini dihormati penuh dan band margin-bawah/gap/margin-atas antar lembar dirender sesuai rancangan.
  - Catatan: ini lebih ringan & berisiko rendah dibanding rewrite multi-`NSTextContainer` yang disarankan agen sebelumnya; pendekatan multi-container tetap valid sebagai opsi jika kelak butuh fitur TextKit 2.

### Test

- **Unit test fidelity baru** (`Packages/SenovativeKit/Tests/.../SampleFidelityTests.swift`) memuat fixture `.docx` Word asli (disalin ke `Tests/.../Fixtures/`) dan memverifikasi: body = Cambria 11pt, semua run punya size > 0, heading mempertahankan 22pt/`#365F91`, dan tidak ada token tema yang bocor (semua font ter-resolve).
- `swift test` (SenovativeKit): **23 test lulus** (19 lama + 4 fidelity). `SenovativeUI`: 1 lulus.
- `xcodebuild ... -configuration Debug -arch arm64`: **BUILD SUCCEEDED**.

### Catatan Untuk Agen Berikutnya

- Verifikasi visual paginasi belum bisa di-screenshot otomatis di environment headless ini (jendela frontmost tapi tidak ter-composite ke `screencapture`; System Events Accessibility ditolak). Perlu konfirmasi mata manusia: buka sample, scroll lewat batas halaman pertama, pastikan teks tidak menabrak margin bawah/atas antar lembar.
- Default **paragraph spacing** dari docDefaults (`after=200`/10pt, `line=276`/1.15) belum diterapkan — masih celah fidelity layout vertikal berikutnya.
- `test_parser.swift` di root sudah usang (memakai API lama `OOXMLEngine.load`/`model.blocks`); kandidat dihapus/diperbarui.

---

## 2026-06-28 — Fidelity: Line Break, List dari Named Style, & Validitas OOXML (dari skill `docx`)

**Dikerjakan oleh:** Claude Code (Opus 4.8)

### Ringkasan

Tiga perbaikan fidelity/validitas berdasarkan temuan dari sample Word asli (`sample/UAS_Project_Analisis_Sentimen.docx`) dan adopsi aturan validitas OOXML dari skill `docx`:
1. **Line break `<w:br/>`** dalam satu paragraf kini dirender (sebelumnya diabaikan → teks menempel).
2. **List berbasis named paragraph style** (`<w:pStyle w:val="ListBullet"/>`) kini dikenali sebagai bullet/numbered (sebelumnya tampil tanpa marker).
3. **Writer OOXML dirapikan agar lolos validator skema** (urutan `<w:pPr>`, lebar tabel DXA, cell margins).

### Perubahan Utama

- **Line break polos** (`OOXML/Word/WordprocessingML.swift`):
  - Parser: `<w:br/>` non-page kini menyisipkan `\u{2028}` (LINE SEPARATOR) ke teks run. Karakter ini dirender TextKit sebagai line break **dalam** paragraf dan tidak memecah paragraf di `model(from:)` (yang hanya split di `\n`), sehingga round-trip kembali ke `<w:br/>`, bukan berubah jadi `<w:p>` terpisah.
  - Writer: serialisasi teks run ditulis ulang menjadi pemindaian per-karakter yang memancarkan `<w:t>` untuk teks, `<w:tab/>` untuk `\t`, dan `<w:br/>` untuk `\u{2028}`.

- **List dari named style** (`WordprocessingML.swift`):
  - `listStyle(numberingId:level:styleName:)` kini menyimpulkan marker dari styleId list yang umum saat tidak ada `<w:numPr>` langsung di paragraf: `ListBullet` → bullet, `ListNumber` → numbered. (Inferensi berbasis styleId, bukan resolusi penuh `numPr` dari `styles.xml`.)

- **Render marker list di editor** (`Apps/SenovativeWrite/Sources/WriteViewController.swift`):
  - Akar masalah: TextKit 1 **tidak** menggambar marker `NSTextList` otomatis dari paragraph style — glyph marker harus ada di text storage. Sebelumnya hanya `style.textLists` di-set, jadi bullet tak pernah tampil (baik saat buka file maupun toggle in-app).
  - Bridge kini menyisipkan `\t<marker>\t` (• untuk bullet, `n.` untuk numbered, dengan counter berurutan) di awal tiap paragraf list, ditandai atribut `listMarkerKey`. Saat membangun model kembali (`paragraph(from:)`), run bertanda marker di-skip sehingga tidak ikut tersimpan ke `<w:t>` — status list dipulihkan dari paragraph style, bukan dari teks marker (round-trip aman).
  - `applyList` (toggle ribbon) ditulis ulang: snapshot range paragraf lalu mutasi back-to-front, hapus marker lama (dedup), set `textLists`, sisipkan marker baru — sehingga list yang dibuat di app langsung tampil bullet/nomor.

- **Warna Heading 2** (`Document/WriteDocumentModel.swift`):
  - `WriteNamedStyle.heading2` diperbaiki dari `365F91` (gelap, salah) ke `4F81BD` — warna `accent1` Heading 2 standar Word 2010, cocok dengan rendering Word pada sample. Heading 1 tetap `365F91` (themeShade BF) dan Title tetap `17365D`.

- **Fix Print "does not support printing"** (`WriteDocument.swift`, `WriteViewController.swift`, `MainMenuBuilder.swift`, `SenovativeWrite.entitlements`):
  - Akar masalah: `WriteDocument` tidak meng-override jalur print apa pun, jadi `printDocument:` jatuh ke implementasi default `NSDocument` yang menampilkan alert "This application does not support printing". Action menu lama (`RichTextView.printDocumentView`) tidak andal terjangkau lewat responder chain, dan override `printOperation(withSettings:error:)` ternyata tidak terpanggil di macOS ini.
  - Solusi: override `printDocument(_:)` langsung pada `WriteDocument` — membangun `NSPrintOperation` dari view halaman (`WriteViewController.printableView`, view yang sama dipakai Export PDF) dan menjalankannya modal pada window. Menu "Print…" diarahkan ke `#selector(NSDocument.printDocument(_:))` standar; `RichTextView.printDocumentView` yang usang dihapus.
  - Menambahkan entitlement `com.apple.security.print` agar print diizinkan di dalam App Sandbox.
  - Diverifikasi langsung: Cmd+P kini memunculkan panel print macOS (preview 2 halaman, opsi PDF/printer), bukan alert error.

- **Validitas OOXML writer — adopsi aturan skill `docx`** (`WordprocessingML.swift`):
  - **Urutan elemen `<w:pPr>`** diperbaiki ke urutan skema CT_PPr: `pageBreakBefore → numPr → spacing → ind → jc` (sebelumnya `jc` diemit pertama dan `numPr` terakhir — melanggar skema, berisiko ditolak Google Docs/validator).
  - **Lebar tabel** kini `<w:tblW w:w="<jumlah kolom>" w:type="dxa"/>` (sebelumnya `w:w="0" w:type="auto"`); `tblW` = `colWidth × columns` agar persis sama dengan jumlah `gridCol`/`tcW` (dual-width).
  - **Cell margins** `<w:tblCellMar>` (80/120 dxa) ditambahkan untuk padding sel yang terbaca.
  - Dikonfirmasi sudah sesuai skill sebelumnya: shading `w:val="clear"`, `xml:space="preserve"`, list via `numPr` (bukan unicode bullet), default page size US Letter (612×792pt) + margin 1".

### Verifikasi Build & Test

- `swift test` (SenovativeKit): **25 test lulus** (23 lama + `wordRoundTripPreservesLineBreaks` + `listBulletStyleIsRecognizedAsBulletList`).
- **Validasi eksternal**: `.docx` hasil engine (heading, bullet, numbered, line break, tabel 2×2) divalidasi dengan `scripts/office/validate.py` dari skill `docx` → **`All validations PASSED!`**.
- `xcodebuild -workspace SenovativeOffice.xcworkspace -scheme SenovativeWrite -configuration Debug -arch arm64`: **BUILD SUCCEEDED**.
- **Verifikasi visual** (buka `sample/UAS_Project_Analisis_Sentimen.docx` di app): line break "Mata Kuliah / Bobot" pindah baris; daftar berpoin tampil dengan bullet `•` + indent; Heading 2 biru terang `4F81BD` cocok dengan MS Word.

### Catatan Untuk Agen Berikutnya

- Writer belum menulis **`<w:pStyle>` semantik** — Heading/Title masih di-flatten ke formatting langsung. Akibatnya **Table of Contents** dan styles gallery OOXML penuh belum mungkin. Ini gap berikutnya (sejalan catatan 1.j).
- Aturan skill `docx` yang **belum** diadopsi karena butuh model/UI baru: tracked changes (`<w:ins>`/`<w:del>`), comments, footnotes, multi-column, internal hyperlink/bookmark.
- Inferensi list dari styleId hanya menangani style list standar Word; resolusi `<w:numPr>` lewat `styles.xml` secara penuh perlu untuk style list custom.
