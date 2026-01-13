# DDR-0002: Standardize Markdown parsing and rendering

## Status
Accepted

## Date
2026-01-12

## Context
Workout definitions are stored as Markdown in the bundled knowledge base and may be edited or derived
into templates/variants. The app needs consistent parsing to extract structured sections and metadata,
plus a renderer for rich display in SwiftUI. We want a native Swift implementation, offline support,
and a shared AST to avoid divergence between parsing and rendering.

## Decision
Use Apple's Swift Markdown package as the canonical parser/AST for knowledge base ingestion and for
extracting structured sections. Use MarkdownUI for SwiftUI rendering of Markdown content. Persist raw
Markdown alongside parsed sections so we can re-derive structured data if parsing rules evolve.

## Alternatives
- Option A: Use Down or Ink for parsing and custom rendering
  - Pros: smaller dependencies, simpler initial parsing APIs
  - Cons: HTML-centric output, less native Swift AST tooling, separate render path
- Option B: Use WebView/HTML rendering for Markdown
  - Pros: mature Markdown support, easier styling via HTML/CSS
  - Cons: heavier runtime, reduced offline control, inconsistent with SwiftUI style system

## Consequences
- Knowledge base loader targets Swift Markdown AST nodes for headings, lists, and paragraphs.
- MarkdownUI becomes the default renderer in SwiftUI views for workout content and previews.
- Parsing fidelity is aligned with Swift Markdown capabilities; any unsupported syntax is treated as
  plain text.

## References
- `docs/architecture/README.md`
- `ios/WorkoutApp/WorkoutApp.xcodeproj`
- wa-8nu
