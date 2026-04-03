# Markdown History View Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render Markdown in all read-only text areas of the 查看历史记录 detail view so AI-generated content displays with proper formatting.

**Architecture:** Add `swift-markdown-ui` as an SPM dependency, then replace the three read-only `Text(...)` display sites in `AIConversationSummaryDetailView` with `Markdown(...).markdownTheme(.gitHub)`. Edit mode is untouched — users still edit raw Markdown source in `TextEditor`.

**Tech Stack:** Swift 6, SwiftUI, `swift-markdown-ui` 2.4.0 (`MarkdownUI` module)

---

## Files

- **Modify:** `Package.swift` — add `swift-markdown-ui` dependency and link to `iTime` target
- **Modify:** `Sources/iTime/UI/AIConversation/AIConversationHistoryView.swift` — replace three read-only text display sites with `Markdown` views

No new files. No test files — these are pure SwiftUI view changes with no testable logic; correctness is verified by build + visual inspection.

---

### Task 1: Add swift-markdown-ui to Package.swift

**Files:**
- Modify: `Package.swift`

- [ ] **Step 1: Edit Package.swift**

Replace the current content of `Package.swift` with:

```swift
// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "iTime",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "iTime", targets: ["iTime"]),
    ],
    dependencies: [
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0"),
    ],
    targets: [
        .executableTarget(
            name: "iTime",
            dependencies: [
                .product(name: "MarkdownUI", package: "swift-markdown-ui"),
            ],
            exclude: ["Resources"]
        ),
        .testTarget(
            name: "iTimeTests",
            dependencies: ["iTime"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
```

- [ ] **Step 2: Resolve and verify the package**

```bash
swift package resolve
```

Expected: Package resolves without error. `swift-markdown-ui` and its `swift-cmark` dependency appear in `.build/checkouts/`.

- [ ] **Step 3: Build to confirm linkage**

```bash
swift build
```

Expected: Build succeeds (no new source files yet, just confirming the dependency links).

- [ ] **Step 4: Commit**

```bash
git add Package.swift Package.resolved
git commit -m "feat: add swift-markdown-ui dependency"
```

---

### Task 2: Replace read-only text with Markdown rendering

**Files:**
- Modify: `Sources/iTime/UI/AIConversation/AIConversationHistoryView.swift`

- [ ] **Step 1: Add MarkdownUI import**

At the top of `AIConversationHistoryView.swift`, add the import after `import SwiftUI`:

```swift
import SwiftUI
import MarkdownUI
```

- [ ] **Step 2: Replace editorOrText read-only branch**

Find the `editorOrText` function (around line 209). Replace its non-editing branch:

**Before:**
```swift
} else {
    Text(readOnlyText)
        .foregroundStyle(.secondary)
}
```

**After:**
```swift
} else {
    Markdown(readOnlyText)
        .markdownTheme(.gitHub)
}
```

- [ ] **Step 3: Replace detailSection read-only branch**

Find the `detailSection` function (around line 226). Replace its non-editing branch:

**Before:**
```swift
} else if !items.isEmpty {
    ForEach(items, id: \.self) { item in
        Text("• \(item)")
            .foregroundStyle(.secondary)
    }
}
```

**After:**
```swift
} else if !items.isEmpty {
    Markdown(items.map { "- \($0)" }.joined(separator: "\n"))
        .markdownTheme(.gitHub)
}
```

- [ ] **Step 4: Replace long-form report content read-only display**

Find the `longFormSection` computed property (around line 258). Replace the non-editing `Text(report.content)` branch:

**Before:**
```swift
} else {
    Text(report.title)
        .font(.headline)

    Text(report.content)
        .foregroundStyle(.secondary)
}
```

**After:**
```swift
} else {
    Text(report.title)
        .font(.headline)

    Markdown(report.content)
        .markdownTheme(.gitHub)
}
```

- [ ] **Step 5: Build to verify no compilation errors**

```bash
swift build
```

Expected: Build succeeds with no errors or warnings related to `MarkdownUI`.

- [ ] **Step 6: Commit**

```bash
git add Sources/iTime/UI/AIConversation/AIConversationHistoryView.swift
git commit -m "feat: render Markdown in history view read-only text areas"
```

---

## Verification

After completing both tasks, run the app via Xcode (`Cmd+R`), navigate to the AI conversation history tab, and confirm:

- Summary body renders headings, bold, bullet lists correctly
- Findings and suggestions render as a formatted bullet list
- Long-form report content renders with full Markdown formatting
- Editing mode still shows raw text in `TextEditor` (no regression)
- Deep dark mode toggle produces correctly adapted colors from `.gitHub` theme
