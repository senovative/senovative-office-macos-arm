# Senovative Office Architecture

This document tracks implementation details that refine `planning.md`.

## Phase 1.a Scaffold

- `SenovativeKit` owns shared document models, file type metadata, and future persistence engines.
- `SenovativeUI` owns shared SwiftUI chrome primitives such as ribbon, inspector, theme, and status controls.
- `SenovativeWrite` is an AppKit document-based macOS app with SwiftUI chrome and an AppKit text surface placeholder.
- `.docx` is registered through `org.openxmlformats.wordprocessingml.document` and mapped to `WriteDocument`.
- Sandbox entitlements are enabled with user-selected read/write file access.
