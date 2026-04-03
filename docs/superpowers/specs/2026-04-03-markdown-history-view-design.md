# Markdown Rendering in History View

**Date:** 2026-04-03  
**Scope:** `AIConversationSummaryDetailView` in `AIConversationHistoryView.swift`

## Goal

Render Markdown in all read-only text areas of the 查看历史记录 (view history) page, so AI-generated content (headings, bold, lists, code blocks, etc.) displays with proper formatting instead of raw Markdown syntax.

## Library

**`swift-markdown-ui`** by gonzalezreal — the standard SwiftUI Markdown rendering library.

- Package URL: `https://github.com/gonzalezreal/swift-markdown-ui`
- Version: `from: "2.4.0"`
- Module: `MarkdownUI`

## Package.swift Changes

Add as a package dependency and link to the `iTime` executable target:

```swift
dependencies: [
    .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0")
],
targets: [
    .executableTarget(
        name: "iTime",
        dependencies: [
            .product(name: "MarkdownUI", package: "swift-markdown-ui")
        ],
        exclude: ["Resources"]
    ),
    // testTarget unchanged
]
```

## View Changes

All changes are in `AIConversationSummaryDetailView` inside `Sources/iTime/UI/AIConversation/AIConversationHistoryView.swift`.

### 1. `editorOrText` — Summary body

**Before (read-only branch):**
```swift
Text(readOnlyText)
    .foregroundStyle(.secondary)
```

**After:**
```swift
Markdown(readOnlyText)
    .markdownTheme(.gitHub)
```

### 2. `detailSection` — Findings and Suggestions

**Before (read-only branch):**
```swift
ForEach(items, id: \.self) { item in
    Text("• \(item)")
        .foregroundStyle(.secondary)
}
```

**After:** Join the items array into a Markdown bullet list and render in one pass:
```swift
Markdown(items.map { "- \($0)" }.joined(separator: "\n"))
    .markdownTheme(.gitHub)
```

### 3. `longFormSection` — Long-form report content

**Before (read-only branch):**
```swift
Text(report.content)
    .foregroundStyle(.secondary)
```

**After:**
```swift
Markdown(report.content)
    .markdownTheme(.gitHub)
```

## Editing Mode

Edit mode (`isEditing = true`, `isEditingLongForm = true`) is unchanged — `TextEditor` shows raw Markdown source text. Only the read-only display branches switch to `Markdown`.

## Styling

Use `.markdownTheme(.gitHub)` on every `Markdown` view:
- Matches the visual style of AI-generated content
- Automatically adapts to system Light/Dark mode
- No additional color or font overrides needed
