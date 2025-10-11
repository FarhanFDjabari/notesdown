# NotesDown Architecture

## Overview

NotesDown follows the **MVVM (Model-View-ViewModel)** architecture pattern, ensuring clean separation of concerns and testability.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                         NotesDownApp                        │
│                      (Application Entry)                     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ├──> ThemeManager (@StateObject)
                         │
                         v
        ┌────────────────────────────────────┐
        │           ContentView              │
        │        (Main Coordinator)          │
        └────────┬───────────────────┬───────┘
                 │                   │
                 v                   v
    ┌──────────────────┐   ┌─────────────────┐
    │ MarkdownEditorView│   │MarkdownPreviewView│
    │   (Text Input)    │   │  (Rendered MD)    │
    └──────────────────┘   └─────────────────┘
                 │
                 v
        ┌────────────────────────────────────┐
        │       DocumentViewModel            │
        │      (Business Logic)              │
        │  - Manages document state          │
        │  - Coordinates file operations     │
        │  - Handles errors                  │
        └────────┬──────────────┬────────────┘
                 │              │
                 v              v
        ┌──────────────┐  ┌────────────────┐
        │MarkdownDocument│  │  FileService  │
        │    (Model)    │  │   (Protocol)  │
        │  - content    │  │  - openFile() │
        │  - fileURL    │  │  - saveFile() │
        │  - isModified │  └────────────────┘
        └──────────────┘
```

## Layer Responsibilities

### 1. View Layer
**Location**: `Views/`

**Components**:
- `ContentView`: Main container, coordinates editor and preview
- `MarkdownEditorView`: Text input component
- `MarkdownPreviewView`: Markdown rendering component

**Responsibilities**:
- Render UI
- Handle user interactions
- Bind to ViewModels
- NO business logic

**Example**:
```swift
struct MarkdownEditorView: View {
    @Binding var text: String  // Bound to ViewModel

    var body: some View {
        TextEditor(text: $text)  // Pure UI
    }
}
```

### 2. ViewModel Layer
**Location**: `ViewModels/`

**Components**:
- `DocumentViewModel`: Manages document state and operations

**Responsibilities**:
- Business logic
- State management
- Coordinate between View and Services
- Error handling
- Data transformation

**Example**:
```swift
@MainActor
class DocumentViewModel: ObservableObject {
    @Published var document: MarkdownDocument

    func openFile() {
        // Coordinate with FileService
        // Update document state
        // Handle errors
    }
}
```

### 3. Model Layer
**Location**: `Models/`

**Components**:
- `MarkdownDocument`: Data structure for markdown documents

**Responsibilities**:
- Pure data structures
- NO business logic
- Conform to protocols (Identifiable, Equatable)

**Example**:
```swift
struct MarkdownDocument: Identifiable, Equatable {
    let id: UUID
    var content: String
    var fileURL: URL?
    var isModified: Bool
}
```

### 4. Service Layer
**Location**: `Services/`

**Components**:
- `FileService`: Protocol-based file I/O

**Responsibilities**:
- External API interactions
- File system operations
- Network calls (future)
- Protocol-based for testability

**Example**:
```swift
protocol FileServiceProtocol {
    func openFile() async throws -> (content: String, url: URL)
    func saveFile(content: String, to url: URL?) async throws -> URL
}

class FileService: FileServiceProtocol {
    // Implementation
}
```

### 5. Managers
**Location**: Root level

**Components**:
- `ThemeManager`: Global theme state

**Responsibilities**:
- Cross-cutting concerns
- Global state management
- App-wide configuration

## Data Flow

### Reading Data (Open File)

```
User Action → View → ViewModel → Service → FileSystem
    ↓                                         ↓
 Update UI ← View ← ViewModel ← Service ← Data
```

**Detailed Flow**:
1. User clicks "Open" button in `ContentView`
2. `ContentView` calls `documentViewModel.openFile()`
3. `DocumentViewModel` calls `fileService.openFile()`
4. `FileService` shows `NSOpenPanel` and reads file
5. `FileService` returns `(content, url)` to ViewModel
6. `ViewModel` creates new `MarkdownDocument` with data
7. `ViewModel` publishes changes via `@Published`
8. `ContentView` observes changes and updates UI

### Writing Data (Save File)

```
User Edit → View → ViewModel (mark modified) → Service → FileSystem
```

**Detailed Flow**:
1. User types in `MarkdownEditorView`
2. Two-way binding updates `documentViewModel.markdownText`
3. Setter marks `document.isModified = true`
4. User clicks "Save"
5. `DocumentViewModel` calls `fileService.saveFile()`
6. `FileService` writes to disk
7. `ViewModel` updates `document.isModified = false`

## Communication Patterns

### 1. View → ViewModel
- **Method**: Direct property access and method calls
- **Example**: `viewModel.openFile()`

### 2. ViewModel → View
- **Method**: Combine's `@Published` properties
- **Example**: `@Published var document: MarkdownDocument`

### 3. ViewModel → Service
- **Method**: Protocol-based dependency injection
- **Example**: `init(fileService: FileServiceProtocol = FileService())`

### 4. ViewModel → Model
- **Method**: Direct struct manipulation (value types)
- **Example**: `document.content = newText`

## Dependency Injection

### Protocol-Based DI

```swift
// Protocol definition
protocol FileServiceProtocol {
    func openFile() async throws -> (content: String, url: URL)
}

// ViewModel accepts protocol
class DocumentViewModel: ObservableObject {
    private let fileService: FileServiceProtocol

    init(fileService: FileServiceProtocol = FileService()) {
        self.fileService = fileService
    }
}

// Testing with mock
class MockFileService: FileServiceProtocol {
    // Mock implementation
}

// In tests
let mockService = MockFileService()
let viewModel = DocumentViewModel(fileService: mockService)
```

**Benefits**:
- Testability: Easy to inject mocks
- Flexibility: Swap implementations
- Loose coupling: Depend on abstractions

## State Management

### @StateObject vs @ObservedObject

```swift
struct ContentView: View {
    @StateObject private var documentViewModel = DocumentViewModel()
    // ✅ ContentView owns the ViewModel

    @EnvironmentObject var themeManager: ThemeManager
    // ✅ Shared state from environment
}
```

### State Ownership Rules

1. **View owns ViewModel**: Use `@StateObject`
2. **Pass down ViewModel**: Use `@ObservedObject`
3. **Global state**: Use `@EnvironmentObject`
4. **Local UI state**: Use `@State`

## Error Handling

### Strategy

```swift
class DocumentViewModel: ObservableObject {
    @Published var errorMessage: String?

    func openFile() {
        Task {
            do {
                // Operation
            } catch FileService.FileServiceError.userCancelled {
                // Silent - user intentionally cancelled
            } catch {
                // Show error to user
                errorMessage = "Failed: \(error.localizedDescription)"
            }
        }
    }
}
```

**Pattern**:
1. Catch specific errors for special handling
2. Catch generic errors for user feedback
3. Store error in `@Published` property
4. View observes and displays alert

## Async/Await Integration

### Actor-Isolated ViewModels

```swift
@MainActor  // Ensures UI updates on main thread
class DocumentViewModel: ObservableObject {
    func openFile() {
        Task {  // Create async context
            let result = try await fileService.openFile()
            // Automatically on main thread due to @MainActor
            self.document = MarkdownDocument(...)
        }
    }
}
```

## Testing Strategy

### Unit Tests

**What to Test**:
- ViewModels: Business logic
- Models: Properties, equality
- Services: I/O operations (mocked)

**What NOT to Test**:
- Views: Use UI tests instead
- SwiftUI framework code

### Test Structure

```swift
@MainActor
final class DocumentViewModelTests: XCTestCase {
    var sut: DocumentViewModel!  // System Under Test
    var mockService: MockFileService!

    override func setUp() {
        mockService = MockFileService()
        sut = DocumentViewModel(fileService: mockService)
    }

    func testOpenFileSuccess() async {
        // Given
        mockService.mockResult = ("content", URL(...))

        // When
        sut.openFile()
        try? await Task.sleep(nanoseconds: 100_000_000)

        // Then
        XCTAssertEqual(sut.document.content, "content")
    }
}
```

## Scalability Considerations

### Adding New Features

1. **New Model**: Add to `Models/`
2. **New Service**: Create protocol in `Services/`
3. **New ViewModel**: Add to `ViewModels/`
4. **New View**: Add to `Views/`
5. **Wire Together**: Update `ContentView`

### Example: Adding Export Feature

```
1. Create ExportFormat enum in Models/
2. Create ExportServiceProtocol in Services/
3. Add export() method to DocumentViewModel
4. Create ExportView in Views/
5. Add export button to ContentView
```

## Best Practices

### DO

✅ Keep Views dumb (no business logic)
✅ Use protocols for services
✅ Inject dependencies
✅ Make Models immutable (structs)
✅ Use `@MainActor` for ViewModels
✅ Write tests for ViewModels
✅ Handle all error cases

### DON'T

❌ Put business logic in Views
❌ Make Models mutable (classes)
❌ Create tight coupling
❌ Ignore async/await patterns
❌ Skip error handling
❌ Test Views with unit tests
❌ Use singletons unnecessarily

## Performance Considerations

### Efficient Updates

```swift
// ✅ Good: Specific property updates
viewModel.markdownText = newText

// ❌ Bad: Replacing entire object
viewModel.document = MarkdownDocument(...)
```

### Debouncing

For future enhancements:
```swift
class DocumentViewModel: ObservableObject {
    private var debounceTask: Task<Void, Never>?

    var markdownText: String {
        didSet {
            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 300_000_000)
                // Auto-save
            }
        }
    }
}
```

## Conclusion

This architecture provides:
- **Separation of Concerns**: Each layer has clear responsibilities
- **Testability**: Protocol-based DI enables easy mocking
- **Maintainability**: Changes isolated to specific layers
- **Scalability**: Easy to add new features
- **Type Safety**: Swift's type system prevents errors

The MVVM pattern, combined with SwiftUI's reactive programming model, creates a robust foundation for building quality macOS applications.
