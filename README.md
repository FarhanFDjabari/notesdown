# NotesDown

A simple, elegant markdown editor for macOS with live preview and theming support.

## Features

- **Markdown Editor**: Clean text editor with monospace font for comfortable writing
- **Live Preview**: Real-time markdown rendering using Apple's native AttributedString markdown parser
- **File Operations**: Open and save markdown files (.md, .markdown)
- **Multiple Windows**: Open untitled documents or selected files in separate windows
- **Light/Dark Mode**: Toggle between light and dark themes
- **Keyboard Shortcuts**:
  - `Cmd+N`: New window
  - `Cmd+O`: Open file
  - `Shift+Cmd+O`: Open files in new windows
  - `Cmd+S`: Save file
- **Offline Support**: Works completely offline with no external dependencies
- **Apple Silicon Optimized**: Built specifically for Apple Silicon Macs

## Architecture

The project follows the **MVVM (Model-View-ViewModel)** architecture pattern:

```
NotesDown/
├── Models/                    # Data models
│   └── MarkdownDocument.swift
├── ViewModels/                # Business logic
│   └── DocumentViewModel.swift
├── Views/                     # UI components
│   ├── MarkdownEditorView.swift
│   └── MarkdownPreviewView.swift
├── Services/                  # External services
│   └── FileService.swift
├── ThemeManager.swift         # Theme management
├── ContentView.swift          # Main view
└── NotesDownApp.swift         # App entry point
```

### Key Components

- **MarkdownDocument**: Immutable data model representing a markdown document
- **DocumentViewModel**: Manages document state and coordinates file operations
- **FileService**: Protocol-based service for file I/O operations
- **ThemeManager**: ObservableObject managing light/dark mode state

## Building the Project

### Requirements

- macOS 13.0 or later
- Xcode 15.0 or later
- Apple Silicon Mac (arm64)
- Swift Package Manager (included with Xcode)

### Dependencies

The project uses Swift Package Manager to manage dependencies:
- [swift-markdown](https://github.com/swiftlang/swift-markdown) v0.5.0+ - Apple's official Markdown parser

Dependencies are automatically resolved when you open the project in Xcode.

### Build from Command Line

```bash
cd /Users/djabari/Development/Projects/Swift/NotesDown
xcodebuild -project NotesDown.xcodeproj -scheme NotesDown -configuration Debug -arch arm64 -sdk macosx build
```

### Build from Xcode

1. Open `NotesDown.xcodeproj` in Xcode
2. Select the NotesDown scheme
3. Build with `Cmd+B`
4. Run with `Cmd+R`

## Testing

The project includes comprehensive unit tests for all business logic components.

### Test Coverage

- **DocumentViewModelTests**: Tests for document management, file operations, and error handling
- **MarkdownDocumentTests**: Tests for model initialization, properties, and equality
- **ThemeManagerTests**: Tests for theme toggling and color scheme management

### Running Tests

#### From Command Line

```bash
xcodebuild test -project NotesDown.xcodeproj -scheme NotesDown -destination 'platform=macOS'
```

#### From Xcode

1. Open the Test Navigator (`Cmd+6`)
2. Click the play button next to test class or individual test
3. Or press `Cmd+U` to run all tests

### Manual Testing Checklist

#### Markdown Preview
- [x] Open the app
- [x] Type markdown syntax (headers, bold, italic, lists, code blocks)
- [x] Verify preview updates in real-time
- [x] Check that all markdown elements render correctly

#### File Operations
- [x] Click "Open" or press `Cmd+O`
- [x] Select a .md file
- [x] Verify file content loads in editor
- [x] Make changes to the content
- [x] Click "Save" or press `Cmd+S`
- [x] Verify changes are saved (reopen file to confirm)

#### Theme Switching
- [x] Click the theme toggle button in toolbar
- [x] Verify app switches between light and dark mode
- [x] Check that both editor and preview adapt to theme
- [x] Verify text is readable in both themes

#### Error Handling
- [x] Try to open a non-existent file (should show error)
- [x] Cancel file open dialog (should not crash)
- [x] Cancel file save dialog (should not crash)
- [x] Try to save to a protected location (should show error)

## Technical Details

### Markdown Rendering

NotesDown uses [swift-markdown](https://github.com/swiftlang/swift-markdown), Apple's official Swift package for parsing and manipulating Markdown documents. This provides:
- **Full CommonMark support**: Compliant with the CommonMark specification
- **True offline functionality**: No CDN dependencies
- **Native performance**: Written in Swift with efficient parsing
- **Extensible**: Built-in support for headings, lists, code blocks, blockquotes, and more
- **Proper document structure**: AST-based parsing for accurate representation

Supported Markdown features:
- Headings (H1-H6) with visual hierarchy
- **Bold** and *italic* text
- Inline `code` and code blocks with language detection
- Tables with column alignment
- Mermaid flowchart code blocks with native preview
- Unordered and ordered lists (with nesting)
- Block quotes
- Horizontal rules
- Links (clickable)
- Proper paragraph spacing and formatting

### File I/O

The app uses `NSOpenPanel` and `NSSavePanel` for file dialogs, ensuring:
- Native macOS file picker experience
- Proper sandboxing support
- User-selected file access permissions

### State Management

- **@StateObject**: Used for view model ownership
- **@Published**: Enables reactive UI updates
- **@EnvironmentObject**: Shares theme state across views
- **Combine**: Handles asynchronous operations

## Project Structure

```
NotesDown/
├── NotesDown.xcodeproj/       # Xcode project file
├── NotesDown/                 # Main app source code
│   ├── Models/
│   ├── ViewModels/
│   ├── Views/
│   ├── Services/
│   ├── Assets.xcassets/       # App icons and assets
│   └── NotesDown.entitlements # Sandbox permissions
├── NotesDownTests/            # Unit tests
└── README.md                  # This file
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contributing

This project demonstrates modern SwiftUI and MVVM architecture patterns. Contributions are welcome! Feel free to:
- Report bugs
- Suggest new features
- Submit pull requests
- Use this as a reference for your own projects
