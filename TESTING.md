# NotesDown Testing Guide

This document provides detailed instructions for testing all features of NotesDown to ensure everything works correctly.

## Automated Tests

### Running Unit Tests

```bash
# From command line
cd /Users/djabari/Development/Projects/Swift/NotesDown
xcodebuild test -project NotesDown.xcodeproj -scheme NotesDown -destination 'platform=macOS'

# From Xcode
# Press Cmd+U or go to Product > Test
```

### Test Coverage

| Component | Test File | Coverage |
|-----------|-----------|----------|
| MarkdownDocument | MarkdownDocumentTests.swift | Model properties, initialization, equality |
| DocumentViewModel | DocumentViewModelTests.swift | File operations, state management, error handling |
| ThemeManager | ThemeManagerTests.swift | Theme toggling, color scheme mapping |

## Manual Testing Guide

### 1. Markdown Preview Functionality

#### Test 1.1: Basic Markdown Rendering
**Steps:**
1. Launch NotesDown
2. Type the following in the editor:
   ```markdown
   # Heading 1
   ## Heading 2
   ### Heading 3

   **Bold text** and *italic text*

   - List item 1
   - List item 2
   - List item 3
   ```
3. Observe the preview pane

**Expected Result:**
- Preview shows properly formatted headings
- Bold and italic text render correctly
- List items display with bullets
- Changes appear instantly as you type

#### Test 1.2: Code Blocks
**Steps:**
1. Type in editor:
   ```markdown
   Inline `code` here

   ```swift
   let greeting = "Hello, World!"
   print(greeting)
   ` ``
   ```
2. Check preview

**Expected Result:**
- Inline code has monospace font and background
- Code block displays with proper formatting
- Syntax is preserved

#### Test 1.3: Links and Formatting
**Steps:**
1. Type:
   ```markdown
   [Link text](https://example.com)

   > This is a blockquote

   ---

   Horizontal rule above
   ```

**Expected Result:**
- Link displays as clickable text
- Blockquote has distinct styling
- Horizontal rule shows as divider

### 2. File Operations

#### Test 2.1: Open File
**Steps:**
1. Create a test markdown file on your system with content
2. Click "Open" button or press `Cmd+O`
3. Select the test file
4. Click "Open"

**Expected Result:**
- File dialog opens
- File content loads into editor
- Preview updates with rendered content
- Window title may show filename

#### Test 2.2: Save New File
**Steps:**
1. Type some content in editor
2. Click "Save" or press `Cmd+S`
3. Choose location and filename
4. Click "Save"
5. Navigate to saved location and open file in another editor

**Expected Result:**
- Save dialog opens
- File saves successfully
- Content matches what was typed
- File has .md extension

#### Test 2.3: Save Existing File
**Steps:**
1. Open an existing file
2. Make modifications
3. Press `Cmd+S`

**Expected Result:**
- File saves without showing dialog
- Changes persist (verify by reopening)

#### Test 2.4: Cancel Operations
**Steps:**
1. Click "Open" and then "Cancel"
2. Click "Save" (with no file open) and then "Cancel"

**Expected Result:**
- No errors occur
- App remains functional
- Editor content unchanged

### 3. Theme Switching

#### Test 3.1: Toggle Light/Dark Mode
**Steps:**
1. Launch app (should start in light mode)
2. Click theme toggle button in toolbar
3. Click theme toggle again

**Expected Result:**
- App switches to dark mode
- All UI elements adapt (editor, preview, toolbar)
- Text remains readable
- Switching back to light mode works

#### Test 3.2: Theme Persistence Across Views
**Steps:**
1. Switch to dark mode
2. Verify both editor and preview adapt
3. Open a file
4. Check that theme remains consistent

**Expected Result:**
- Theme applies to all views
- No flickering or theme conflicts

### 4. Error Handling

#### Test 4.1: Invalid File Operations
**Steps:**
1. Try to open a non-markdown file (e.g., .jpg)
2. Attempt to save to a read-only location (if possible)

**Expected Result:**
- Appropriate error messages display
- App doesn't crash
- User can continue working

#### Test 4.2: Large Files
**Steps:**
1. Create a very large markdown file (10MB+)
2. Try to open it

**Expected Result:**
- File loads (may take time)
- Preview renders
- Editor remains responsive

### 5. User Experience

#### Test 5.1: Split View Resizing
**Steps:**
1. Drag the divider between editor and preview
2. Make editor very small
3. Make preview very small
4. Reset to balanced

**Expected Result:**
- Divider moves smoothly
- Both panes remain usable
- Text doesn't overlap
- Minimum widths are respected

#### Test 5.2: Window Resizing
**Steps:**
1. Resize window to very small
2. Resize to full screen
3. Check various sizes

**Expected Result:**
- Content adapts gracefully
- No UI elements disappear
- Toolbar remains accessible

#### Test 5.3: Keyboard Navigation
**Steps:**
1. Use Tab to move focus
2. Try keyboard shortcuts:
   - `Cmd+O` to open
   - `Cmd+S` to save

**Expected Result:**
- Focus indicators visible
- Shortcuts work reliably
- No conflicting shortcuts

## Performance Testing

### Memory Usage
**Steps:**
1. Open Activity Monitor
2. Launch NotesDown
3. Type large amount of text
4. Open several files
5. Monitor memory usage

**Expected Result:**
- Memory usage stays reasonable (<100MB typical)
- No memory leaks
- App remains responsive

### Responsiveness
**Steps:**
1. Type quickly in editor
2. Observe preview update latency

**Expected Result:**
- Preview updates within 100ms
- No dropped keystrokes
- Smooth scrolling

## Edge Cases

### Test E.1: Empty Document
**Steps:**
1. Delete all content
2. Save file

**Expected Result:**
- Empty file saves successfully
- Preview shows blank

### Test E.2: Special Characters
**Steps:**
1. Type various special characters: `<>[]{}#*_~`
2. Add emoji: 🎉 📝 ✨

**Expected Result:**
- Characters display correctly
- Markdown syntax respected
- Emojis render properly

### Test E.3: Very Long Lines
**Steps:**
1. Type a paragraph with no line breaks (1000+ characters)

**Expected Result:**
- Editor wraps text
- Preview handles correctly
- No horizontal scroll in preview

## Bug Reporting

If you find issues during testing:

1. **Describe the issue**: What went wrong?
2. **Steps to reproduce**: Exact steps to trigger the bug
3. **Expected behavior**: What should happen
4. **Actual behavior**: What actually happened
5. **Environment**: macOS version, app version
6. **Screenshots**: If applicable

## Test Status Template

Use this checklist when performing manual testing:

```
## Test Session: [Date]
### Tester: [Name]
### Build: [Version/Commit]

#### Markdown Preview
- [ ] Basic rendering
- [ ] Code blocks
- [ ] Links and formatting

#### File Operations
- [ ] Open file
- [ ] Save new file
- [ ] Save existing file
- [ ] Cancel operations

#### Theme Switching
- [ ] Toggle theme
- [ ] Persistence across views

#### Error Handling
- [ ] Invalid operations
- [ ] Large files

#### UX
- [ ] Split view resizing
- [ ] Window resizing
- [ ] Keyboard navigation

#### Notes:
[Any observations or issues found]
```

## Continuous Testing

For ongoing development:

1. Run unit tests before committing changes
2. Perform smoke tests for each major feature after changes
3. Do full manual test pass before releases
4. Monitor crash reports and user feedback
5. Add tests for any bugs discovered

## Test Automation (Future)

Potential automated testing improvements:

- UI tests using XCTest UI Testing
- Snapshot tests for preview rendering
- Integration tests for file operations
- Performance benchmarks
- Accessibility testing
