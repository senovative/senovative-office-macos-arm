# Senovative Office — Arsitektur & Planning

> Suite produktivitas **native macOS** (khusus chipset Apple Silicon / M-series, `arm64`).
> Clone dari Microsoft Office dengan brand **Senovative Office**.

| Produk Senovative | Setara Microsoft | Kode internal | Format modern (OOXML) | Format lama (biner, baca+tulis) |
|---|---|---|---|---|
| **Senovative Write** | Word | `write` | **`.docx`** (WordprocessingML) | **`.doc`** (MS-DOC, dalam CFB) |
| **Senovative Slides** | PowerPoint | `slides` | **`.pptx`** (PresentationML) | **`.ppt`** (MS-PPT, dalam CFB) |
| **Senovative Sheets** | Excel | `sheets` | **`.xlsx`** (SpreadsheetML) | **`.xls`** (MS-XLS / BIFF8, dalam CFB) |

> ⚠️ **Keputusan format (final):** TIDAK ada format buatan sendiri. Senovative Office membaca & menyimpan **langsung** ke format Microsoft Office. Mendukung **format modern OOXML** (`.docx/.pptx/.xlsx`) DAN **format lama biner** (`.doc/.ppt/.xls`) — keduanya **baca + tulis penuh**, agar 100% saling tukar dengan semua versi MS Office, Google Docs, LibreOffice, dll.

**Target rilis akhir:** file installer `.dmg` (signed + notarized), **arm64 only** (Apple Silicon M-series). Tidak ada slice Intel/x86_64.

---

## 1. Prinsip & Batasan

1. **Native, bukan Electron/web wrapper.** 100% Swift + AppKit/SwiftUI. Performa & integrasi macOS penuh (autosave, Versions, Quick Look, Continuity, dll).
2. **Apple Silicon only.** Build `arm64`, deployment target macOS 14+ (Sonoma) agar fitur TextKit 2 & SwiftUI modern tersedia.
3. **Bertahap.** Bangun **Senovative Write dulu sampai bisa dirilis sebagai `.dmg`**, baru Slides, lalu Sheets. Setiap aplikasi bisa berdiri sendiri.
4. **Inti dipakai bersama.** Document model, persistence, design system, packaging dibagi lewat framework `SenovativeKit` & `SenovativeUI`.
5. **Format = MS Office, bukan buatan sendiri.** Aplikasi membaca/menyimpan **langsung** ke `.docx/.pptx/.xlsx` (OOXML = ZIP berisi XML). Tidak ada format `.sw*` proprietary. Konsekuensinya: **engine OOXML (read/write) adalah fondasi, dikerjakan lebih awal**, lalu fidelity-nya diperdalam bertahap. In-memory document model dipakai saat editing, tapi sumber kebenaran di disk = OOXML.
6. **Dukung format lama biner (`.doc/.ppt/.xls`) baca + tulis.** Format pra-2007 = container **CFB/OLE2** ([MS-CFB]) berisi stream biner ([MS-DOC], [MS-XLS]/BIFF8, [MS-PPT]). Engine biner ini **jauh lebih berat & berisiko** daripada OOXML → dikerjakan **setelah** engine OOXML + editor stabil di tiap aplikasi (sub-fase tersendiri). In-memory document model yang sama dipakai untuk kedua format; hanya lapisan serialisasi yang berbeda (OOXML vs biner). Container CFB dibangun sekali di `SenovativeKit` lalu dipakai ulang oleh ketiga app.

---

## 2. Tech Stack

| Lapis | Pilihan | Alasan |
|---|---|---|
| Bahasa | **Swift 6** (strict concurrency) | Native, aman, modern |
| Shell/Chrome UI | **SwiftUI** | Cepat untuk toolbar, panel, inspector, dialog |
| Surface editing berat | **AppKit + TextKit 2** (`NSTextLayoutManager`), `NSView`/Metal untuk grid Sheets | Kontrol penuh atas layout teks, caret, pagination, scrolling besar |
| Document lifecycle | **`NSDocument`** (AppKit) + SwiftUI via `NSHostingView` | Autosave, Versions, recent, iCloud "gratis"; baca/tulis langsung ke file `.docx/.pptx/.xlsx` |
| File OOXML | **ZIPFoundation** (atau `libcompression`/`Archive`) + XML parser (`XMLParser`/`XMLDocument`) | `.docx/.pptx/.xlsx` = arsip ZIP berisi part XML; perlu zip read/write + XML read/write |
| File lama biner | **Engine CFB/OLE2 buatan sendiri** + codec biner per format (BIFF8 dll.) | `.doc/.ppt/.xls` = compound file biner; perlu baca/tulis struktur sektor/stream + parse/serialize record biner (low-level, byte-precise) |
| Build system | **Swift Package Manager** + **Xcode workspace** | Modular, satu workspace banyak target |
| Rendering grafis | Core Graphics / Core Animation / SwiftUI Canvas; Metal untuk Sheets bila perlu | Sesuai beban tiap app |
| Packaging | `xcodebuild` → codesign (Developer ID) → `notarytool` → `create-dmg`/`hdiutil` | Pipeline `.dmg` ter-notarisasi |

**Keputusan arsitektur kunci:**
- Backbone dokumen = `NSDocument` (bukan `DocumentGroup`) untuk kontrol penuh.
- View berat (kanvas teks, grid) = AppKit; chrome (ribbon, inspector, dialog) = SwiftUI.
- Model dokumen **immutable-ish + command/undo** lewat `UndoManager` terpusat di `SenovativeKit`.

---

## 3. Struktur Repo (Monorepo)

```
senovative-office/
├── SenovativeOffice.xcworkspace
├── Packages/
│   ├── SenovativeKit/        # Core: document model, persistence, undo, file IO, OOXML
│   │   └── Sources/SenovativeKit/
│   │       ├── Document/      # protocol DocumentModel, NSDocument base, in-memory model
│   │       ├── OOXML/         # engine baca/tulis .docx/.pptx/.xlsx (ZIP + XML)
│   │       │   ├── Zip/       # buka/tulis arsip OOXML
│   │       │   ├── Word/      # WordprocessingML  (document.xml, styles.xml, ...)
│   │       │   ├── Slides/    # PresentationML
│   │       │   └── Sheets/    # SpreadsheetML
│   │       ├── Legacy/        # engine baca/tulis format lama biner (.doc/.ppt/.xls)
│   │       │   ├── CFB/       # container OLE2 / Compound File [MS-CFB] (dipakai ketiga format)
│   │       │   ├── Doc/       # MS-DOC  (Word 97-2003)
│   │       │   ├── Ppt/       # MS-PPT  (PowerPoint 97-2003)
│   │       │   └── Xls/       # MS-XLS / BIFF8 (Excel 97-2003)
│   │       ├── Undo/          # command system, UndoManager wrapper
│   │       └── Util/          # logging, errors, geometry, color
│   └── SenovativeUI/         # Design system + komponen UI bersama
│       └── Sources/SenovativeUI/
│           ├── Theme/         # warna, tipografi, ikon, spacing
│           ├── Ribbon/        # toolbar/ribbon, command bar
│           ├── Inspector/     # panel properti
│           └── Controls/      # font picker, color picker, dialogs
├── Apps/
│   ├── SenovativeWrite/      # target .app — MS Word clone   (Fase 1)
│   ├── SenovativeSlides/     # target .app — PowerPoint clone (Fase 2)
│   └── SenovativeSheets/     # target .app — Excel clone      (Fase 3)
├── Tools/
│   ├── build.sh              # build arm64 release
│   ├── sign-notarize.sh      # codesign + notarytool
│   └── make-dmg.sh           # create-dmg per app / suite
├── Resources/                # ikon app, background DMG, template dokumen
├── docs/
│   └── architecture.md
└── planning.md               # file ini
```

**Format file = OOXML Microsoft** (arsip ZIP berisi part XML). Contoh isi `.docx`:
```
report.docx                     (ZIP)
├── [Content_Types].xml         # daftar tipe MIME tiap part
├── _rels/.rels                 # relasi root
└── word/
    ├── document.xml            # ISI utama: paragraf, run, teks
    ├── styles.xml              # definisi style
    ├── numbering.xml           # list/bullet
    ├── settings.xml
    ├── media/                  # gambar (image1.png, ...)
    └── _rels/document.xml.rels # relasi (gambar, hyperlink)
```
`.pptx` (folder `ppt/`, `slide1.xml`, dst.) & `.xlsx` (folder `xl/`, `sheet1.xml`, `sharedStrings.xml`, dst.) berstruktur serupa. Tidak ada format proprietary — semua langsung OOXML.

---

## 4. Diagram Lapisan

```
┌───────────────────────────────────────────────────────────┐
│   SenovativeWrite.app   SenovativeSlides.app   ...Sheets   │  ← Fase 1 / 2 / 3
├───────────────────────────────────────────────────────────┤
│                      SenovativeUI                          │  ← design system bersama
│        (Ribbon · Inspector · Theme · Controls)            │
├───────────────────────────────────────────────────────────┤
│                      SenovativeKit                         │  ← core bersama
│  Document · Undo/Command · OOXML(zip+xml) · Legacy(CFB biner) │
├───────────────────────────────────────────────────────────┤
│        AppKit · TextKit 2 · SwiftUI · Core Graphics        │  ← platform Apple
└───────────────────────────────────────────────────────────┘
```

---

## 5. ROADMAP / FASE

> Aturan: hanya **Fase 1 yang di-breakdown detail** sekarang. Fase 2 & 3 baru dipecah jadi sub-fase saat akan dikerjakan.

### 🟦 FASE 1 — Senovative Write (clone MS Word) → output `.dmg`

| Sub-fase | Nama | Lingkup | Definition of Done |
|---|---|---|---|
| **1.a** | Fondasi & Scaffolding | Workspace + SPM, package `SenovativeKit` & `SenovativeUI` (skeleton), target `SenovativeWrite.app`, config build arm64-only, `NSDocument` base (UTI `.docx`), window + menu bar + toolbar shell kosong, app icon placeholder | App kosong bisa di-`build & run`, terdaftar sebagai pembuka `.docx` |
| **1.b** | **Engine OOXML inti (read/write `.docx`)** | ZIP read/write, parse & tulis WordprocessingML minimal (`document.xml`: paragraf + run + teks), in-memory document model, **round-trip** buka→simpan `.docx` | Buka `.docx` berisi teks dari Word & simpan kembali tanpa rusak |
| **1.c** | Editor Teks Inti | TextKit 2 (`NSTextLayoutManager`) tampilkan model, ketik, caret, selection (keyboard+mouse), copy/paste/cut, undo/redo, bold/italic/underline ↔ disimpan ke `document.xml` | Edit teks lalu simpan; perubahan kebaca di MS Word |
| **1.d** | Rich Formatting | Font family/size, warna & highlight, alignment, line/paragraph spacing, bullet & numbered list (`numbering.xml`), indent, super/subscript, styles (`styles.xml`) | Format kaya round-trip via OOXML |
| **1.e** | Page Layout & Pagination | Tampilan halaman, margin/ukuran kertas (`sectPr`), header/footer, ruler, page break, nomor halaman | Dokumen multi-halaman tampil, cetak, & sesuai saat dibuka di Word |
| **1.f** | Objek Sisipan | Tabel (`<w:tbl>`), gambar (`word/media/` + relasi), shape dasar, hyperlink, special characters | Objek round-trip ke/dari `.docx` |
| **1.g** | **Fidelity & Robustness OOXML** | Uji buka `.docx` dunia nyata (dari Word/Google Docs), pertahankan part yang belum didukung (round-trip aman, no data loss), penanganan error, fonts | Buka beragam `.docx` umum tanpa korup; fitur tak dikenal tetap terjaga |
| **1.h** | **Engine CFB + Baca `.doc`** | Engine container **CFB/OLE2** [MS-CFB] (baca sektor/stream) — dipakai ulang Slides/Sheets nanti; parser **MS-DOC** (FIB, piece table, teks, format, paragraf) → in-memory model | Buka `.doc` Word 97-2003 umum & tampil benar |
| **1.i** | **Tulis `.doc`** | Serializer CFB (tulis compound file) + writer **MS-DOC** biner (FIB, stream `WordDocument`/`1Table`, format) dari model | Simpan ke `.doc` yang terbuka benar di MS Word |
| **1.j** | Produktivitas & Export | Export **PDF** (PDFKit), Find & Replace, spell check (NSSpellChecker), word/char count, styles gallery, template, autosave/Versions, recent files, print dialog | Fitur sehari-hari setara Word dasar |
| **1.k** | **Packaging & Rilis** | Ikon final, `build.sh` release arm64, **`SenovativeWrite.dmg`** (background + symlink /Applications), unsigned dulu (signing/notarisasi menyusul saat akun Apple Developer siap) | `.dmg` terpasang & jalan di Mac M-series lain |
| **1.l** | **Page Setup** | Dialog Page Setup (ukuran kertas, orientasi, margin, scaling) yang mengedit `WriteDocumentSection`, re-layout kanvas live, dan round-trip ke `<w:sectPr>` | Ubah kertas/orientasi/margin via dialog → kanvas & cetak ikut berubah, tersimpan benar di `.docx` & terbuka sesuai di Word |
| **1.m** | **Zoom In/Out** | Kontrol zoom tampilan kanvas (slider − / + + persen) di status bar ala Word, menu View → Zoom, dan gesture pinch/⌘-scroll | Perbesar/perkecil tampilan halaman tanpa mengubah isi dokumen; persen akurat, caret/scroll tetap benar |

**Milestone Fase 1:** `SenovativeWrite.dmg` rilis-able yang baca/tulis **`.docx` & `.doc`** asli.

> Pola tiap sub-fase 1.c–1.f: setiap fitur editor **sekaligus** menambah dukungan baca/tulisnya di engine OOXML — model, view (TextKit 2), dan serialisasi `.docx` tumbuh bersamaan.

---

#### 🟦 Fase 1.l — Page Setup (detail)

> Fitur tambahan pasca-1.k. Tujuan: pengguna bisa mengatur properti halaman (ukuran kertas, orientasi, margin, scaling) layaknya **File → Page Setup** di MS Word / dialog Page Setup macOS. Fondasinya sudah ada: `WriteDocumentSection` (di `SenovativeKit`) menyimpan `pageSize` & `margins`, parser/writer OOXML sudah baca/tulis `<w:pgSz>` & `<w:pgMar>`, dan pipeline print/PDF sudah memakai view halaman. Fase ini menyatukannya lewat satu dialog + re-layout live.

**Lingkup UI (mengacu screenshot Page Setup macOS / Word):**

| Kontrol | Nilai | Catatan |
|---|---|---|
| **Paper Size** | US Letter (8.5×11"), A4, Legal, Tabloid, + **Custom** (width/height) | Preset umum dulu; custom menyusul. Tampilkan ukuran mm/inci sesuai `Locale`. |
| **Orientation** | Portrait / Landscape | Tukar width↔height; tulis `w:orient` di `<w:pgSz>`. |
| **Margins** | Top / Bottom / Left / Right | Gaya Word; default 1" (1440 twips). Validasi margin tak melebihi kertas. |
| **Scaling** | persen (mis. 100%) | Untuk cetak; map ke `NSPrintInfo.scalingFactor`. |
| **Apply settings to** (accessory) | Whole Document / This Section | Scope perubahan. Awal: Whole Document (satu section). |
| **Default…** (accessory) | tombol | Simpan setelan sebagai default dokumen baru. |
| **(Lanjutan)** | header/footer distance, vertical alignment | Opsional, menyusul. |

**Pendekatan implementasi:**

1. **Akses**: menu **File → Page Setup…** (`Cmd+Shift+P`); opsional tombol ribbon / double-click ruler.
2. **Dialog**: pakai **`NSPageLayout`** bawaan macOS + **accessory view** — **persis pendekatan MS Word** (screenshot Page Setup Word menampilkan panel native macOS dengan seksi tambahan "Microsoft Word"). Native panel sudah menyediakan **Format For** (printer), **Paper Size**, **Orientation**, **Scaling**, dan thumbnail preview; kita tinggal menambahkan accessory view berisi:
   - **"Apply Page Setup settings to:"** — dropdown scope (**Whole Document** / This Section). Untuk lingkup awal cukup *Whole Document* (satu `<w:sectPr>`); *This Section* menyusul saat multi-section didukung.
   - **Tombol "Margins…"** — membuka sheet/dialog terpisah untuk Top/Bottom/Left/Right (gaya Word; macOS sendiri tak punya UI margin di panel ini).
   - **Tombol "Default…"** — simpan setelan halaman sebagai default dokumen baru.
   Accessory dipasang via `NSPageLayout.accessoryControllers` (atau `runModal(with: printInfo)` + accessory `NSViewController`). Alternatif (b) **dialog custom SwiftUI** disimpan sebagai cadangan jika butuh kontrol di luar yang diberikan panel native.
3. **Model**: dialog membaca/menulis `WriteDocumentSection.pageSize` & `.margins` lewat `WriteDocumentState`; `updateChangeCount(.changeDone)` agar tersimpan.
4. **Re-layout live**: saat section berubah, `DocumentCanvas` harus menghitung ulang lebar halaman tetap, `textContainer` size, `exclusionPaths` (gap antar lembar), dan `PageContainerView` (ukuran/posisi kertas). Saat ini parameter tsb dibaca sekali di `makeNSView` — perlu jalur update agar bisa berubah tanpa buka-ulang dokumen.
5. **OOXML round-trip**: pastikan writer menulis `<w:pgSz w:w w:h w:orient>` & `<w:pgMar>` dari nilai dialog; tambah atribut `w:orient="landscape"` (saat ini belum ditulis). Parser sudah baca pgSz/pgMar; tambah baca `w:orient`.
6. **Sinkron print/PDF**: `NSPrintInfo` (paper size, orientation, scaling, margins) diselaraskan dengan section saat `printDocument(_:)` / Export PDF, agar hasil cetak konsisten dengan tampilan.

**Definition of Done:**
- Dialog Page Setup bisa dibuka; ubah **paper size**, **orientation**, dan **margin** → kanvas editor langsung memantulkan perubahan (lebar/tinggi halaman & margin).
- Nilai tersimpan ke `.docx` (`<w:sectPr>`) dan **terbuka sesuai di MS Word** (mis. dokumen di-set Landscape A4 margin 2cm tetap demikian saat dibuka Word).
- Cetak/Export PDF mengikuti pengaturan halaman.

**Catatan teknis & risiko:**
- Re-layout pagination saat ukuran berubah memakai jalur `exclusionPaths` TextKit 1 yang sama dengan pagination saat ini (lihat catatan changelog) — perlu hati-hati agar gap antar lembar tetap akurat setelah ganti ukuran/orientasi.
- `w:orient` hanyalah hint; sumber kebenaran tetap `w:w`/`w:h`. Saat Landscape, tulis width>height **dan** `w:orient="landscape"`.
- Custom paper size & multi-section (`<w:sectPr>` per bagian) di luar lingkup awal — degrade ke satu section dulu.

---

#### 🟦 Fase 1.m — Zoom In/Out (detail)

> Fitur tambahan pasca-1.l. Tujuan: pengguna bisa **memperbesar/memperkecil tampilan** dokumen (mis. 50%–500%) seperti kontrol zoom di kanan-bawah MS Word (slider **−/+** dengan persen), **tanpa mengubah isi atau ukuran kertas dokumen** — murni transformasi tampilan. Zoom **tidak** ditulis ke `.docx` sebagai konten (paling jauh hanya hint `w:zoom` di `settings.xml`, opsional).

**Lingkup UI (mengacu status bar Word):**

| Kontrol | Perilaku | Catatan |
|---|---|---|
| **Slider zoom** | Geser untuk set persen kontinu | Rentang awal 50%–200% (perluas 25%–500% menyusul). |
| **Tombol −  /  +** | Turun/naik per langkah (mis. 10% atau preset 25/50/75/100/125/150/200) | Di kiri/kanan slider. |
| **Label persen** | Tampil & klik → menu preset / input angka | Mis. "100%". |
| **Menu View → Zoom** | Zoom In (`⌘+`), Zoom Out (`⌘-`), Actual Size (`⌘0`), Zoom to… | Selaras shortcut standar macOS. |
| **Gesture** | Pinch trackpad & **⌘+scroll** untuk zoom | Opsional tapi natural. |

**Pendekatan implementasi:**

1. **Mekanisme zoom**: skala kanvas, **bukan** ukuran font model. Opsi:
   - (a) `NSScrollView.magnification` (built-in; set `allowsMagnification = true`, `minMagnification`/`maxMagnification`, `magnify(toFit:)`/`setMagnification(_:centeredAt:)`). **Rekomendasi** — paling ringkas, sudah menangani scroll, gesture pinch, dan posisi center.
   - (b) Transform `CALayer`/`scaleUnitSquare` manual (lebih banyak kerjaan; hanya bila (a) kurang).
2. **State**: simpan `zoomLevel` di `WriteDocumentState` (atau view-state per window) — **bukan** di `WriteDocumentModel` (zoom = preferensi tampilan, bukan isi dokumen).
3. **Status bar**: tambah slider + −/+ + label persen di status bar bawah (`WriteViewController`); dua arah sinkron dengan `magnification`.
4. **Menu & shortcut**: View → Zoom In/Out/Actual Size, map ke `⌘+` / `⌘-` / `⌘0`.
5. **Ketepatan**: zoom hanya memengaruhi render; **caret, selection, klik, ruler, dan pagination** harus tetap akurat pada koordinat ter-skala (`NSScrollView.magnification` menangani ini otomatis; verifikasi ruler ikut skala).
6. **Persistensi (opsional)**: ingat zoom terakhir per window via state; opsi tulis `<w:zoom w:percent="…">` di `word/settings.xml` agar Word membuka pada zoom sama (round-trip preservation sudah mempertahankan `settings.xml` bila tak diutak-atik).

**Definition of Done:**
- Slider/−/+ dan menu View → Zoom mengubah perbesaran kanvas dengan persen akurat; **Actual Size (⌘0)** kembali ke 100%.
- Isi dokumen & ukuran kertas **tidak berubah** saat zoom; menyimpan `.docx` tidak mengubah konten karena zoom.
- Caret, seleksi, klik mouse, dan scrolling tetap presisi pada semua level zoom.

**Catatan teknis & risiko:**
- `NSScrollView.magnification` berlaku pada `documentView` (`PageContainerView`) — pastikan ruler & exclusion-path pagination tetap konsisten setelah skala (uji di 50% & 200%).
- Hindari mengubah font/`pointSize` model untuk "zoom" — itu mengubah dokumen, bukan tampilan; pemisahan zoom (tampilan) vs ukuran kertas (Fase 1.l) harus jelas.
- Zoom adalah **per-window/preferensi**, jadi tidak memicu "edited"/`updateChangeCount` kecuali memang menulis `w:zoom`.

---

### 🟩 FASE 2 — Senovative Slides (clone PowerPoint) → output `.dmg`
*(breakdown detail dibuat saat Fase 2 dimulai)*

Garis besar yang akan dipecah nanti:
- 2.a Reuse `SenovativeKit`/`SenovativeUI` + scaffolding `SenovativeSlides.app`
- 2.b Engine OOXML `.pptx` inti (PresentationML: slide, shape, text) — read/write round-trip
- 2.c Kanvas slide (shapes, text box, gambar) + tools seleksi/transform
- 2.d Slide model: layout, master slide, tema, transisi
- 2.e Slide sorter, outline view, speaker notes
- 2.f Presenter mode (dual screen) + animasi dasar
- 2.g Fidelity `.pptx` dunia nyata + export PDF/gambar
- 2.h **Baca + Tulis `.ppt`** (MS-PPT biner via engine CFB dari Fase 1)
- 2.i Packaging → `SenovativeSlides.dmg`

---

### 🟧 FASE 3 — Senovative Sheets (clone Excel) → output `.dmg`
*(breakdown detail dibuat saat Fase 3 dimulai)*

Garis besar yang akan dipecah nanti:
- 3.a Scaffolding `SenovativeSheets.app`
- 3.b Engine OOXML `.xlsx` inti (SpreadsheetML: `sheet1.xml`, `sharedStrings.xml`, `styles.xml`) — read/write round-trip
- 3.c Grid ter-virtualisasi (scrolling jutaan sel, freeze panes) — kemungkinan Metal/NSView custom
- 3.d Model sel, tipe data, number/date format
- 3.e **Formula engine**: lexer → parser → evaluator, dependency graph, recalculation, fungsi (SUM, IF, VLOOKUP, dst.)
- 3.f Multi-sheet, sort/filter, conditional formatting
- 3.g Chart/grafik
- 3.h Fidelity `.xlsx` dunia nyata + export CSV/PDF
- 3.i **Baca + Tulis `.xls`** (MS-XLS / BIFF8 biner via engine CFB dari Fase 1)
- 3.j Packaging → `SenovativeSheets.dmg`

---

### 🟪 FASE 4 — Suite Integration & Installer Gabungan
- 4.a Konsistensi UX & shared theming final lintas 3 app
- 4.b Senovative Office "hub"/launcher (opsional) + template gallery bersama
- 4.c **Installer suite `SenovativeOffice.dmg`** berisi ketiga app (signed + notarized)
- 4.d Auto-update (Sparkle) — opsional
- 4.e Halaman About, lisensi, dokumentasi

---

## 6. Strategi Distribusi `.dmg` (arm64-only)

Pipeline tiap rilis (`Tools/`):
1. `xcodebuild -scheme <App> -configuration Release -arch arm64 -derivedDataPath build`
2. `codesign --deep --force --options runtime --sign "Developer ID Application: …"`
3. `xcrun notarytool submit … --wait` lalu `xcrun stapler staple`
4. `create-dmg` → `.dmg` dengan background, ikon app, symlink ke `/Applications`
5. Verifikasi `spctl -a -vvv` & `codesign --verify` di Mac M-series bersih

> **Catatan:** notarisasi butuh akun Apple Developer ($99/thn) + Developer ID certificate. Untuk build internal/uji, bisa pakai `.dmg` unsigned (user buka via klik-kanan → Open).

---

## 7. Strategi Testing & Fidelity

Karena keberhasilan proyek = **file harus terbuka benar di MS Office asli**, testing adalah bagian inti, bukan afterthought.

- **Korpus uji file nyata.** Kumpulan `.docx/.doc` (lalu `.pptx/.ppt`, `.xlsx/.xls`) dari berbagai sumber (Word, Google Docs, LibreOffice, template publik) disimpan di `Tests/Corpus/`. Dipakai sebagai input regression.
- **Round-trip test (golden).** Untuk tiap file korpus: buka → model → simpan → buka lagi → bandingkan model harus setara (tidak ada data hilang). Inti pertahanan terhadap regresi format.
- **Cross-app verification (semi-manual + checklist).** File hasil tulis kita dibuka di **MS Office / Pages / LibreOffice** untuk verifikasi visual. Untuk format biner (`.doc/.xls/.ppt`) langkah ini wajib tiap rilis.
- **Unit test per layer.** Parser/serializer OOXML & CFB diuji terisolasi (byte-level untuk CFB) terlepas dari UI.
- **Snapshot test render.** Halaman/ slide/ sheet di-render ke gambar lalu dibandingkan (deteksi regresi tata letak).
- **Fuzz/robustness.** File rusak/terpotong tidak boleh crash — harus gagal dengan rapi (lihat §9 Keamanan).
- **CI** (nanti, Fase 1.k+): build arm64 + jalankan unit + round-trip test otomatis.

---

## 8. Dependencies (Build vs Buy)

Prinsip: **manfaatkan framework Apple semaksimal mungkin**, tulis sendiri hanya bagian yang tak ada padanannya.

| Kebutuhan | Pilihan | Catatan |
|---|---|---|
| PDF, print, spell check, font | PDFKit, NSPrintOperation, NSSpellChecker, CoreText | Bawaan macOS — jangan reinvent |
| ZIP (OOXML) | **ZIPFoundation** (SPM, MIT) atau `Compression` framework | Boleh 1 dependency kecil & teruji |
| XML | `XMLParser`/`XMLDocument` (bawaan) | Cukup; tak perlu lib eksternal |
| Container CFB & codec biner (`.doc/.xls/.ppt`) | **Tulis sendiri** | Tak ada lib Swift matang; ini justru nilai inti proyek |
| Formula engine (Sheets) | **Tulis sendiri** | Inti diferensiasi Sheets |
| Auto-update (opsional, Fase 4) | **Sparkle** | Standar de-facto app macul di luar App Store |

> Kebijakan: dependency pihak-ketiga harus berlisensi permisif (MIT/Apache/BSD), minim, dan bisa di-vendor. Hindari ketergantungan besar yang mengikat arsitektur.

---

## 9. Keamanan (Parsing File Tak Tepercaya)

File Office sering jadi vektor serangan; engine kita memproses file dari sumber tak dikenal.

- **Makro VBA TIDAK dieksekusi.** Storage makro (`vbaProject.bin` / stream di CFB) **dipertahankan saat round-trip** agar tidak hilang, tapi **tidak pernah dijalankan**. Tidak ada interpreter VBA.
- **Parser defensif.** Semua offset/panjang dari file divalidasi sebelum dipakai (cegah out-of-bounds). Batasi: ukuran dekompresi ZIP (anti *zip-bomb*), kedalaman rekursi, jumlah sektor CFB.
- **App Sandbox + hardened runtime.** Aktifkan App Sandbox dengan entitlement minimal (user-selected file access). Wajib untuk hardened runtime + notarisasi.
- **Gagal dengan rapi.** File korup → pesan error, bukan crash/eksekusi. Jadi target fuzzing (§7).
- **Tidak ada koneksi jaringan tersembunyi.** Relasi eksternal/`oleObject`/remote image tidak di-fetch otomatis tanpa izin user.

---

## 10. Lokalisasi & Aksesibilitas

- **Lokalisasi.** Semua string lewat `String(localized:)` sejak awal. Bahasa awal: **Inggris + Indonesia**; tambah lain belakangan. Format angka/tanggal pakai `Locale` (penting untuk Sheets).
- **Aksesibilitas.** Dukung **VoiceOver**, Dynamic Type, Increase Contrast, Full Keyboard Access sejak komponen UI dibangun di `SenovativeUI` (lebih murah daripada retrofit).
- **Dark Mode & tema.** Pakai semantic colors di `SenovativeUI/Theme` agar Light/Dark otomatis.

---

## 11. Risiko & Catatan Teknis

- **OOXML adalah pekerjaan inti, bukan tambahan.** Karena format file = `.docx/.pptx/.xlsx` langsung, engine read/write OOXML (1.b, 2.b, 3.b) jadi fondasi & berisiko tinggi. Strategi penting: **selalu pertahankan part XML yang belum kita dukung** saat menyimpan ulang (round-trip preservation) supaya tidak ada data hilang.
- **Format lama biner (`.doc/.ppt/.xls`) = item paling berisiko & paling mahal di proyek ini.** Menulis biner `.doc`/BIFF8/`.ppt` dari nol itu byte-precise dan sedikit salah = file korup. Mitigasi: (a) bangun engine **CFB** sekali, uji terisolasi dgn banyak file nyata; (b) untuk MS-DOC, dukung tulis **piece table sederhana** dulu; (c) selalu uji round-trip dengan membuka hasil di MS Word asli; (d) sediakan "Save As → .docx" sebagai jalan aman kalau file lama terlalu eksotis. Realistis: dukung subset fitur umum, degrade dgn rapi.
- **Fidelity** (OOXML & biner) tidak akan 100% sama dengan MS Office — target realistis: dokumen umum aman & terbuka benar, fitur eksotis di-degrade dengan baik (bukan korup).
- **TextKit 2 + pagination** bagian tersulit di sisi editor Fase 1 (1.c–1.e).
- **Grid Sheets (3.c)** & **formula engine (3.e)** adalah dua sub-fase berisiko tinggi; mungkin perlu rendering Metal.
- **Spell check, PDF, print** sudah disediakan macOS (NSSpellChecker, PDFKit, NSPrintOperation) → manfaatkan, jangan reinvent.
- **Apple Developer account** diperlukan untuk distribusi `.dmg` ter-notarisasi.

---

## 12. Langkah Berikutnya

Mulai **Fase 1.a — Fondasi & Scaffolding**:
1. Inisialisasi Xcode workspace + SPM packages (`SenovativeKit`, `SenovativeUI`)
2. Buat target `SenovativeWrite.app` (arm64, macOS 14+), daftarkan UTI `.docx` (`org.openxmlformats.wordprocessingml.document`)
3. Pasang `NSDocument` base + window/menu/toolbar shell
4. Verifikasi build & run; lalu lanjut **1.b** = engine OOXML untuk buka/simpan `.docx` beneran
