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
| **1.l** | **Hardening, Zoom, & Page Setup** | Perbaikan arsitektur kritis (Multi-Container, O(N) Editor, Semantic Styles), UI kontrol font/ruler/indikator, Zoom in/out, dan dialog Page Setup. | Arsitektur stabil, tidak lag, TOC MS Word berfungsi, UI ribbon, zoom, dan pengaturan halaman berjalan lancar. |

**Milestone Fase 1:** `SenovativeWrite.dmg` rilis-able yang baca/tulis **`.docx` & `.doc`** asli.

> Pola tiap sub-fase 1.c–1.f: setiap fitur editor **sekaligus** menambah dukungan baca/tulisnya di engine OOXML — model, view (TextKit 2), dan serialisasi `.docx` tumbuh bersamaan.

---

#### 🟦 Fase 1.l — Hardening, Zoom, & Page Setup (detail)

**Tambahan dalam 1.l — Page Setup:**

> Fitur tambahan pasca-1.k. Tujuan: pengguna bisa mengatur properti halaman (ukuran kertas, orientasi, margin, scaling) layaknya **File → Page Setup** di MS Word / dialog Page Setup macOS. Fondasinya sudah ada: `WriteDocumentSection` (di `SenovativeKit`) menyimpan `pageSize` & `margins`, parser/writer OOXML sudah baca/tulis `<w:pgSz>` & `<w:pgMar>`, dan pipeline print/PDF sudah memakai view halaman. Fase ini menyatukannya lewat satu dialog + re-layout live.

**Lingkup UI (mengacu screenshot Page Setup macOS / Word):**

| Kontrol | Nilai | Catatan |
|---|---|---|
| **Paper Size** | US Letter, A4, Legal, Tabloid, + **Custom** (width/height) | Preset umum dulu; custom menyusul. Tampilkan mm/inci sesuai `Locale`. Nilai OOXML dalam **DXA/twips** (lihat tabel referensi di bawah). |
| **Orientation** | Portrait / Landscape | Landscape = **tukar w/h** (width jadi sisi panjang) **dan** `w:orient="landscape"` di `<w:pgSz>`. |
| **Margins** | Top / Bottom / Left / Right | Gaya Word; default 1" = **1440 twips**. Validasi margin tak melebihi kertas. |
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
5. **OOXML round-trip**: writer menulis `<w:pgSz w:w w:h w:orient>` & `<w:pgMar>` dari nilai dialog; tambah `w:orient="landscape"` (belum ditulis). Parser sudah baca pgSz/pgMar; tambah baca `w:orient`. Pertahankan **urutan anak `<w:sectPr>`** (CT_SectPr): `headerReference`/`footerReference` → `pgSz` → `pgMar` → … (writer saat ini sudah urut demikian). **Selalu** tulis `pgSz` eksplisit (jangan andalkan default konsumen — Word/Google Docs berbeda default kertasnya).
6. **Sinkron print/PDF**: `NSPrintInfo` (paper size, orientation, scaling, margins) diselaraskan dengan section saat `printDocument(_:)` / Export PDF, agar hasil cetak konsisten dengan tampilan.

**Referensi unit & OOXML (dari skill `docx`):**

- **Konversi**: `1 inci = 1440 twips (DXA) = 72 points`; jadi **points × 20 = twips**. Model menyimpan ukuran dalam **points** (`WriteDocumentSection`: US Letter 612×792 pt, margin 72 pt), writer mengubah ke twips. Validasi konversi ini saat menulis pgSz/pgMar.
- **Ukuran kertas (DXA, portrait)**:

  | Kertas | Width | Height |
  |---|---|---|
  | US Letter | 12240 | 15840 |
  | A4 | 11906 | 16838 |
  | Legal | 12240 | 20160 |
  | Tabloid | 15840 | 24480 |

  Landscape = tukar kolom Width/Height + `w:orient="landscape"` (mis. US Letter landscape → `w:w="15840" w:h="12240"`).
- **Margin negatif/0**: izinkan 0 tapi waspadai konten keluar area cetak; macOS print clamp ke margin printer minimum.
- **Validasi**: setiap menulis perubahan section, uji `.docx` hasil dengan validator skema dari skill `docx` (`scripts/office/validate.py`) — sama seperti yang dipakai untuk validitas writer di changelog 2026-06-28 — agar `<w:sectPr>` tetap valid lintas Word/Google Docs/LibreOffice.

**Definition of Done:**
- Dialog Page Setup bisa dibuka; ubah **paper size**, **orientation**, dan **margin** → kanvas editor langsung memantulkan perubahan (lebar/tinggi halaman & margin).
- Nilai tersimpan ke `.docx` (`<w:sectPr>`) dan **terbuka sesuai di MS Word** (mis. dokumen di-set Landscape A4 margin 2cm tetap demikian saat dibuka Word).
- Cetak/Export PDF mengikuti pengaturan halaman.

**Catatan teknis & risiko:**
- Re-layout pagination saat ukuran berubah memakai jalur `exclusionPaths` TextKit 1 yang sama dengan pagination saat ini (lihat catatan changelog) — perlu hati-hati agar gap antar lembar tetap akurat setelah ganti ukuran/orientasi.
- `w:orient` hanyalah hint; sumber kebenaran tetap `w:w`/`w:h`. Saat Landscape, tulis width>height **dan** `w:orient="landscape"`.
- Custom paper size & multi-section (`<w:sectPr>` per bagian) di luar lingkup awal — degrade ke satu section dulu.

---

**Tambahan dalam 1.l — Zoom In/Out:**

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
- **Penyelarasan skill `docx`**: skill memperlakukan zoom sebagai **setelan tampilan**, bukan konten — di OOXML berada di `word/settings.xml` (`<w:zoom w:percent="…"/>` di dalam `<w:settings>`), terpisah dari `document.xml`. Konsekuensi: zoom **tidak boleh** mengubah `<w:sz>`/run apa pun; bila persistensi diaktifkan, tulis hanya `<w:zoom>` (round-trip `settings.xml` sudah dipertahankan oleh preservation di fase 1.g).

---

**Tambahan dalam 1.l — Hardening & Fidelity (Font, Ruler, Paginasi):**

> Fitur tambahan pasca-1.m. Tujuan: kontrol **nama font** dan **ukuran font** langsung di ribbon (seperti grup Font di tab Home MS Word), bukan lewat Font Panel macOS. Fondasi sudah ada: `WriteRun.fontFamily` & `WriteRun.fontSize` tersimpan di model dan round-trip ke `<w:rFonts>`/`<w:sz>`; resolusi theme font (`majorHAnsi`/`minorHAnsi` → Calibri/Cambria) sudah ada dari fase fidelity. Fase ini menambah **UI inline** + apply ke selection/typing dan refleksi dua-arah.

**Lingkup UI (mengacu grup Font Word):**

| Kontrol | Perilaku | Catatan |
|---|---|---|
| **Combo box nama font** | Editable + dropdown; apply ke teks terpilih / typing attributes | Isi dropdown: **Theme Fonts** (Calibri *(Headings)*, Cambria *(Body)*), **Recent Fonts**, **All Fonts** (daftar `NSFontManager.availableFontFamilies`). |
| **Live preview di menu** | Tiap nama font dirender memakai font-nya sendiri | Seperti Word; pakai atribut font per item menu. |
| **Combo box ukuran** | Editable + preset dropdown | Preset: **5, 5.5, 6.5, 7.5, 8, 9, 10, 10.5, 11, 12, 14, 16, 18, 20, 22, 24, 26, 28, 36, 48, 72**. Boleh ketik nilai bebas. |
| **Grow / Shrink (A▲ / A▼)** | Naik/turun ke preset berikutnya | Shortcut `⌘+>` / `⌘+<` ala Word. |
| **Refleksi caret** | Saat caret/seleksi pindah, combo box menampilkan font & ukuran aktif | Jika seleksi campur → field kosong/placeholder. |

**Pendekatan implementasi:**

1. **UI**: dua kontrol di ribbon (`SenovativeUI`/`WriteViewController`) — bisa `NSComboBox` (editable) yang di-host, atau menu SwiftUI. Dropdown font perlu item dengan **preview** (render nama dalam font tsb).
2. **Daftar font**: `NSFontManager.shared.availableFontFamilies`; bagian **Theme Fonts** dari section/theme dokumen (Headings=majorHAnsi, Body=minorHAnsi); **Recent** disimpan di preferensi.
3. **Apply**: ubah font pada `selectedRange` di `NSTextStorage` (pakai `NSFontManager.convert` untuk pertahankan bold/italic) atau set `typingAttributes` saat tak ada seleksi; lalu `didChangeText()` → model & `<w:rFonts>`/`<w:sz>` ikut.
4. **Refleksi dua-arah**: pada `NSTextViewDelegate.textViewDidChangeSelection`, baca atribut font/ukuran di caret → update combo box (tangani seleksi multi-font → tampil kosong).
5. **Ukuran**: preset list di atas, plus parsing input bebas (validasi rentang, mis. 1–1638pt seperti Word). Grow/Shrink melompat ke preset terdekat berikutnya.
6. **Konsistensi**: kontrol Font Panel lama (tombol "Fonts") boleh tetap ada sebagai pelengkap, tapi ribbon jadi jalur utama.

**Definition of Done:**
- Memilih nama font & ukuran dari ribbon mengubah teks terpilih (atau typing berikutnya); bold/italic yang ada tetap dipertahankan.
- Combo box **memantulkan** font & ukuran pada posisi caret; seleksi campur ditandai (field kosong).
- Perubahan tersimpan ke `.docx` (`<w:rFonts w:ascii=…>`, `<w:sz w:val=…>`) dan terbuka sesuai di Word.

**Catatan teknis & risiko (diselaraskan dengan skill `docx`):**
- **`<w:sz>` = half-point** (mis. 11pt → `w:val="22"`); pecahan 10.5pt → `21`. Writer sudah pakai `halfPoints(...)` — verifikasi preset pecahan (5.5/6.5/7.5/10.5). Untuk fidelity penuh, pasangkan **`<w:szCs>`** (ukuran complex-script) bernilai sama dengan `<w:sz>`.
- **`<w:rFonts>`**: writer kini menulis `w:ascii` + `w:hAnsi`. Word menyimpan font di beberapa slot — set juga **`w:cs`** (complex script) ke family yang sama agar konsisten di semua skrip; theme font ditulis sebagai typeface konkret (sudah ditangani fase fidelity — jangan bocorkan token `minorHAnsi`/`majorHAnsi`).
- **⚠️ Urutan anak `<w:rPr>` harus diperbaiki saat fase ini.** CT_RPr adalah `xsd:sequence` dengan urutan: `rFonts → b → i → … → color → sz → szCs → u → … → shd → vertAlign`. Writer sekarang memancarkan urutan **tidak sesuai** (`rFonts, sz, color, shd, b, i, u, vertAlign`). Karena kontrol font menyentuh `rPr`, rapikan urutan ini sekalian (analog perbaikan urutan `<w:pPr>` di changelog 2026-06-28) lalu validasi dengan `scripts/office/validate.py` dari skill `docx`.
- Font belum ter-install (ikon cloud di Word) di luar lingkup — cukup tampilkan font yang tersedia di sistem (`NSFontManager.availableFontFamilies`).

**Tambahan dalam 1.l — Indikator Halaman ("Page X of Y"):**

> Menampilkan **halaman aktif dari total halaman** di status bar (kiri-bawah ala Word, mis. "Page 2 of 2"). Murni indikator tampilan; tidak mengubah dokumen.

- **Total halaman**: dihitung dari pagination kanvas. Saat ini pagination memakai `exclusionPaths` (tinggi konten ÷ tinggi halaman efektif) — total = jumlah lembar yang benar-benar ditempati teks. Harus **konsisten** dengan lembar yang dirender (bukan asumsi 500 path statis).
- **Halaman aktif**: dari posisi scroll viewport (lembar yang sedang terlihat dominan) atau posisi caret; pilih salah satu konvensi (Word: berbasis caret saat mengetik, berbasis scroll saat menggulir).
- **Update**: pada edit (`textDidChange`), scroll (`NSView.boundsDidChangeNotification` pada clip view), dan `selectionDidChange`.
- **UI**: label di status bar `WriteViewController` (sebelah word/char count yang sudah ada); format ter-lokalisasi `String(localized: "Page \(current) of \(total)")`.
- **DoD**: status bar menampilkan "Page X of Y" yang berubah benar saat mengetik/scroll; total cocok dengan jumlah halaman tercetak (uji dokumen 1, 2, dan banyak halaman).
- **Risiko**: akurasi bergantung pada pagination `exclusionPaths` (lihat catatan changelog) — jika kelak pindah ke arsitektur multi-`NSTextContainer`, hitung total dari jumlah container yang terpakai.

**Tambahan dalam 1.l — Perbaikan Ruler (selebar kertas + zoom-aware):**

> Masalah sekarang: ruler memakai `NSScrollView` bawaan yang membentang **selebar window** (termasuk area gelap di luar kertas), dengan nol di tepi kiri view. Target ala Word: ruler **hanya menutupi area kertas**, dengan **0 di margin kiri**, batas margin/indent ditandai, dan **mengikuti posisi & skala kertas** saat di-zoom atau digulir.

- **Lingkup ruler kertas**:
  - Skala (angka) hanya digambar **sepanjang lebar kertas** (`pageSize.width`), bukan seluruh lebar window; area di luar kertas tampil kosong/redup.
  - **Origin di margin**: titik 0 berada di **margin kiri** halaman (mengikuti konvensi Word), bukan di tepi fisik kertas.
  - Tandai **batas margin** (area abu di luar margin) dan, menyusul, **penanda indent** (first-line/hanging/left) + tab stops yang bisa digeser.
- **Keterkaitan zoom (1.m)**: ruler harus **sinkron dengan `NSScrollView.magnification`** dan offset scroll horizontal — saat zoom in/out, jarak antar-angka & posisi kertas berubah, ruler ikut menyesuaikan sehingga angka tetap sejajar dengan posisi kertas sebenarnya. (Penyebab utama "ruler tidak nyambung dengan kertas" = ruler tak ikut transform zoom/scroll.)
- **Pendekatan implementasi**:
  - Opsi (a): subclass **`NSRulerView`** custom — set `clientView` = `PageContainerView`, `originOffset` = posisi margin-kiri kertas relatif client, `measurementUnits`, dan gambar hanya rentang kertas. `NSRulerView` sudah terintegrasi dengan scroll & magnification scroll view.
  - Opsi (b): ruler custom (`NSView`) yang menggambar sendiri berdasarkan geometri `PageContainerView` + `magnification` + `contentView.bounds.origin`. Lebih banyak kerja tapi kontrol penuh tampilan ala Word.
  - Rekomendasi: mulai dari (a) `NSRulerView` dengan `originOffset` ke margin & batasi gambar ke lebar kertas; tingkatkan ke penanda indent/tab kemudian.
- **DoD**: ruler horizontal hanya menutupi lebar kertas, 0 tepat di margin kiri, dan **tetap sejajar dengan kertas pada semua level zoom & saat digulir**; ruler vertikal serupa untuk tinggi halaman/margin atas-bawah.
- **Risiko**: sinkronisasi ruler dengan `magnification` + multi-halaman (vertikal) bisa rumit; mulai dari ruler horizontal satu halaman, lalu rapikan vertikal/multi-halaman.

**Tambahan dalam 1.l — Hardening hasil review DOCX/MS Word:**

> Review 2026-06-28 terhadap implementasi Fase 1.a–1.k menemukan beberapa gap fidelity yang tidak selalu tertangkap oleh unit test internal karena parser kita toleran. Sekalian dengan kontrol font/ruler/status bar, Fase 1.l harus menjadi titik rapih-rapih sebelum lanjut Slides/Sheets: writer harus lebih patuh skema OOXML, output lebih semantik seperti Word asli, dan `.doc` legacy tidak sekadar round-trip internal.

- **Preservation isi `word/document.xml` (no data loss yang lebih nyata)**:
  - Saat ini preservation menyalin part tak dikenal, tetapi `word/document.xml` tetap digenerate ulang. Akibatnya elemen unsupported di body dapat hilang saat open→save: `w:bookmarkStart/End`, `w:commentRangeStart/End`, `w:commentReference`, `w:footnoteReference`, `w:endnoteReference`, `w:fldSimple`/field complex, content controls (`w:sdt`), tracked changes (`w:ins`/`w:del`), floating drawing (`wp:anchor`), textbox/shape kompleks, dan TOC.
  - Target 1.n: minimal buat **unknown-inline/block preservation strategy** untuk elemen yang belum diedit, atau fallback konservatif: bila dokumen mengandung fitur body unsupported, tampilkan warning "Save may simplify unsupported Word features" + tawarkan Save As copy.
  - Tambah regression test: dokumen fixture dengan bookmark/comment/footnote/field sederhana dibuka lalu disimpan; elemen unsupported yang tidak tersentuh tetap ada di `document.xml`.

- **Semantic Word styles (`styles.xml` + `<w:pStyle>`)**:
  - `WriteNamedStyle` sekarang hanya flatten ke direct formatting. Secara visual bisa mirip, tetapi Word Navigation Pane, outline, TOC, dan style round-trip tidak berfungsi sebagai heading semantik.
  - Tambah model `styleId` pada `WriteParagraph` (mis. `Title`, `Heading1`, `Heading2`, `Normal`, `Quote`) dan writer menulis `<w:pPr><w:pStyle w:val="..."/></w:pPr>` dalam urutan CT_PPr yang benar.
  - Writer harus membuat/patch `word/styles.xml` minimal untuk style bawaan yang kita pakai, sambil tetap preserve style existing dari source package. Direct formatting tetap boleh sebagai fallback, tetapi bukan satu-satunya representasi.
  - DoD: paragraph dengan Heading 1 tersimpan sebagai `<w:pStyle w:val="Heading1">`, muncul sebagai heading semantik di Word/LibreOffice, dan TOC/outline bisa mengenali struktur.

- **Perbaiki spacing semantics dari Word (`w:spacing`)**:
  - Parser saat ini menganggap semua `w:line` sebagai twips; padahal `lineRule="auto"` memakai satuan 240 per line (mis. `276` = 1.15). Writer juga selalu menulis `lineRule="exact"`, yang bisa mengubah layout vertikal.
  - Tambah model line spacing dengan mode: `autoMultiple`, `exact`, `atLeast`; parse/tulis `w:lineRule` sesuai sumber.
  - Terapkan paragraph defaults dari `styles.xml`/`docDefaults` untuk `spacingAfter` dan line spacing (mis. Word sample `after=200`, `line=276`, `lineRule=auto`) agar fidelity vertikal lebih dekat.
  - DoD: sample Word asli tetap 2 halaman dan spacing antar heading/list/body tidak drift setelah open→save.

- **Page orientation & section metadata**:
  - Parser/writer sudah baca/tulis ukuran kertas dan margin, tetapi belum memodelkan `w:orient`. Ini juga prerequisite Fase 1.l Page Setup.
  - Tambah `orientation` pada `WriteDocumentSection`; parser baca `w:orient`, writer menulis `w:orient="landscape"` saat width/height landscape. Tetap pastikan width/height menjadi sumber kebenaran.
  - Pertahankan/parse juga header/footer distance (`w:header`, `w:footer`) bila ada, bukan selalu menulis `720`.

- **Table geometry mengikuti section, bukan hardcoded Letter**:
  - Writer tabel saat ini memakai `9360` dxa (6.5 inch Letter content width). Untuk A4, landscape, Legal, atau margin custom, tabel bisa overflow/tidak sejajar.
  - Hitung `usableWidthDxa = (pageSize.width - margins.left - margins.right) * 20`, tulis `tblW`, `tblGrid/gridCol`, dan setiap `tcW` dari nilai itu.
  - Tambahkan `tblInd` eksplisit (default 120 dxa atau 0 sesuai style dokumen) dan pastikan `tblW = sum(gridCol)`; ini mengikuti audit skill `documents` untuk tabel Word yang stabil.
  - DoD: tabel 1, 2, 3, 5 kolom valid di validator dan tidak overflow di Letter, A4, dan landscape.

- **Legacy `.doc` writer: STSH minimal + verifikasi reader ketat**:
  - `MSDocWriter` sudah round-trip internal, tetapi belum menulis STSH (`fcStshf/lcbStshf=0`) sehingga MS Word/textutil belum terkonfirmasi bisa membuka hasil tulis dengan benar.
  - Tambah STSH minimal berisi style built-in seperti Normal + bin-table CHP/PAP yang cukup untuk reader ketat.
  - DoD: `.doc` hasil Save As bisa dibuka oleh MS Word asli atau minimal `textutil` macOS mengekstrak teks yang benar; test internal saja tidak cukup untuk menandai 1.i benar-benar selesai.

- **Performa Editor Inkremental (O(N) Bottleneck)**:
  - Saat ini, setiap ketikan (`textDidChange`) memicu parsing ulang seluruh dokumen dari `NSTextStorage` ke `WriteDocumentModel`. Ini sangat lambat (O(N)) untuk dokumen besar.
  - Terapkan update inkremental (hanya memperbarui paragraf yang diedit) atau jadikan `NSTextStorage` sumber kebenaran tunggal selama sesi pengeditan.

- **Arsitektur Paginasi Multi-Container (Hapus Hack TextKit 1)**:
  - Penggunaan `exclusionPaths` untuk membuat batas antar halaman adalah hack yang rapuh dan mengunci aplikasi ke TextKit 1 dengan batas statis 500 halaman.
  - Rombak `PageContainerView` menggunakan arsitektur multi-`NSTextContainer` (satu container per halaman fisik) sehingga pemecahan halaman terjadi secara alami tanpa trik margin.

- **Tabel Kompleks & Merge Cells (`vMerge` / `gridSpan`)**:
  - Tabel saat ini tidak mendukung penggabungan sel vertikal maupun horizontal. File `.docx` dengan tabel kompleks akan rusak saat dirender/disimpan.
  - Tambahkan `columnSpan` dan `rowSpan` pada `WriteTableCell`, lalu pastikan parser membaca `<w:gridSpan>` dan `<w:vMerge>` dari `<w:tcPr>`.

- **Validation/render gate untuk semua perubahan Fase 1.l**:
  - Setiap perubahan writer `.docx` wajib menjalankan unit test + validator OOXML (`scripts/office/validate.py` dari skill `docx`/dokumen bila tersedia) pada output yang mencakup heading, list, font, table, image, page setup, dan line break.
  - Render sample dan dokumen sintetis ke PNG memakai workflow skill `documents` (`render_docx.py`) lalu inspeksi visual: tidak ada clipping, overlap, tabel overflow, heading/list drift, atau page break aneh.
  - Tambah fixture regression kecil di `Tests/Corpus`/`Fixtures` untuk: semantic heading, table custom margin, landscape section, line spacing auto, unsupported body element preservation, dan `.doc` STSH.

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
