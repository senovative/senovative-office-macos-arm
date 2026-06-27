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
