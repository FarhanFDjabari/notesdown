# NotesDown

NotesDown is a native macOS Markdown editor with a split editor/preview workflow, local file handling, multiple document windows, tabs, themes, and offline rendering through Apple's Swift Markdown parser.

## Features

- **Split editor and preview**: Write in a monospace editor while the rendered preview updates live.
- **Native Markdown rendering**: Uses `swift-markdown` plus SwiftUI views for headings, inline styling, lists, block quotes, code blocks, horizontal rules, links, and tables.
- **Table support**: Renders Markdown tables with alignment, horizontal scrolling, stable row heights, and long-cell safeguards.
- **Mermaid flowchart previews**: Shows a lightweight native preview for Mermaid flowchart edges while preserving the source block.
- **Multiple documents**: Open untitled documents, selected files, multiple files in new windows, and new tabs.
- **Markdown file dialogs**: Supports `.md`, `.markdown`, `.mdown`, and `.mkd` files.
- **Light and dark themes**: Toggle the app color scheme from the toolbar.
- **Offline first**: No web views, CDN dependencies, or network access are required for editing and previewing.
- **Apple Silicon focused**: Project settings target arm64 macOS builds.

## Keyboard Shortcuts

| Shortcut | Action |
| --- | --- |
| `Cmd+N` | New window |
| `Cmd+T` | New tab |
| `Cmd+O` | Open file |
| `Shift+Cmd+O` | Open files in new windows |
| `Cmd+S` | Save file |

## Requirements

- macOS 14.0 or later for the app target
- Xcode with macOS SDK support
- Apple Silicon Mac for the default project architecture
- Swift Package Manager, included with Xcode

## Dependencies

Dependencies are managed by Swift Package Manager and resolved by Xcode.

- [`swift-markdown`](https://github.com/swiftlang/swift-markdown) 0.7.3
- [`swift-cmark`](https://github.com/swiftlang/swift-cmark) 0.7.0, resolved transitively

## Build

### Xcode

1. Open `NotesDown.xcodeproj`.
2. Select the `NotesDown` scheme.
3. Build with `Cmd+B`.
4. Run with `Cmd+R`.

### Command Line

```bash
xcodebuild \
  -project NotesDown.xcodeproj \
  -scheme NotesDown \
  -configuration Debug \
  -arch arm64 \
  -sdk macosx \
  build
```

## Test

Run the unit test suite from Xcode with `Cmd+U`, or from the command line:

```bash
xcodebuild test \
  -project NotesDown.xcodeproj \
  -scheme NotesDown \
  -destination 'platform=macOS'
```

Pull requests to `main` also run the `PR Tests` GitHub Actions workflow on macOS with code signing disabled for CI.

## Architecture

NotesDown follows an MVVM structure with protocol-based file I/O and app-level managers for shared state.

```text
NotesDown/
├── NotesDownApp.swift          # App entry point, windows, commands, app delegate
├── ContentView.swift           # Main split editor/preview coordinator
├── ThemeManager.swift          # Light/dark theme state
├── Models/
│   └── MarkdownDocument.swift  # Document model
├── ViewModels/
│   └── DocumentViewModel.swift # Document state and file coordination
├── Views/
│   ├── MarkdownEditorView.swift
│   └── MarkdownPreviewView.swift
├── Services/
│   └── FileService.swift       # NSOpenPanel/NSSavePanel file access
└── NotesDown.entitlements      # App sandbox permissions
```

### Key Components

- **`NotesDownApp`** configures the primary window group, URL-backed document windows, app commands, and reopen behavior.
- **`WindowManager`** queues external or multi-file open requests into new windows.
- **`NotesDownCommands`** owns menu commands and keyboard shortcuts for new windows, tabs, opening, and saving.
- **`ContentView`** coordinates the editor, preview, toolbar actions, file-opening notifications, and document command handlers.
- **`DocumentViewModel`** owns document state, save/open actions, modified tracking, and user-facing errors.
- **`FileService`** provides async file open/save operations through native macOS panels.
- **`MarkdownPreviewView`** parses Markdown into native SwiftUI rendering views, including tables and Mermaid flowchart blocks.

## Project Files

```text
.
├── .github/workflows/pr-tests.yml
├── ARCHITECTURE.md
├── TESTING.md
├── NotesDown/
├── NotesDown.xcodeproj/
├── NotesDownTests/
├── LICENSE
└── README.md
```

For deeper implementation details, see [ARCHITECTURE.md](ARCHITECTURE.md). For manual and automated validation guidance, see [TESTING.md](TESTING.md).

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.
