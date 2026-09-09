# Architecture Decision Records (ADRs) & Key Decisions

This document records the major architectural, design, and product decisions made during the development of boring.notch enhancements.

---

## ADR 001: M1 Non-Notch Display Compatibility First

- **Date**: 2026-09-10
- **Status**: Accepted
- **Context**: The primary development and daily-driver hardware is an Apple Silicon MacBook M1 without a hardware notch (e.g., MacBook Air M1 / MacBook Pro 13"). Features must work cleanly on displays where `safeAreaInsets.top == 0`.
- **Decision**:
  - Never assume `safeAreaInsets.top > 0`.
  - Dynamically calculate closed notch heights via `Defaults[.nonNotchHeight]` and `vm.effectiveClosedNotchHeight`.
  - Align all open-state animations, corner clip shapes, and hover hitboxes with standard macOS menu bar geometry.
- **Consequences**: Zero visual glitches or clipping on flat-bezel screens while maintaining full backward compatibility with physical-notch MacBooks.

---

## ADR 002: Notion-Style Block Architecture for Scratchpad ("Notch Pad")

- **Date**: 2026-09-10
- **Status**: Accepted
- **Context**: The user required a quick notes / scratchpad experience within the notch canvas (~640x190pt) to brainstorm and manage checklist items with instant markdown / Notion-style triggers.
- **Decision**:
  - Implement a polymorphic block model (`NotchPadBlock`) with types: `.text`, `.todo(isCompleted:)`, `.bullet`, `.heading1`, `.heading2`, `.code`.
  - Support instant markdown prefixes (`[] `, `[ ] `, `- [ ] `, `* `, `- `, `# `, `## `, ````) to convert blocks inline.
  - Provide a floating command palette (`NotchPadSlashMenu`) triggered on `/`.
  - Continuous debounced auto-save (400ms) with atomic JSON writes to `~/Library/Application Support/boringNotch/Pad/scratchpad.json`.
- **Consequences**: Lightweight, distraction-free note taking that auto-persists without manual save buttons or database overhead.

---

## ADR 003: Text Editing & Notch Dismissal Protection

- **Date**: 2026-09-10
- **Status**: Accepted
- **Context**: In boring.notch, cursor movement outside the window boundary triggers automatic dismissal (`vm.close()`). While typing notes, accidental cursor drift caused the notch to collapse unexpectedly.
- **Decision**:
  - Bind `focusedBlockID != nil || isSlashMenuVisible` to `SharingStateManager.shared.preventNotchClose = true`.
  - Re-enable dismissal when focus is lost or the user explicitly presses `Esc` or clicks away.
- **Consequences**: Frustration-free typing experience with reliable notch retention during active edits.

---

## ADR 004: Dynamic Tab Selection & Preferences

- **Date**: 2026-09-10
- **Status**: Accepted
- **Context**: Adding new views (like `Pad`) needed to blend seamlessly with existing tabs (`Home`, `Shelf`) and respect user visibility preferences.
- **Decision**:
  - Extend `NotchViews` with `case pad`.
  - Dynamically compute `visibleTabs` in `TabSelectionView` based on `Defaults[.boringShelf]` and `Defaults[.boringPad]`.
  - Add `openPadByDefault` setting in Preferences to allow users to directly open the scratchpad on hover.
- **Consequences**: Clean UI adaptability; users can customize exactly which tabs appear in their notch header.

---

## ADR 005: Automated Cloud Builds via GitHub Actions

- **Date**: 2026-09-10
- **Status**: Accepted
- **Context**: The user does not have Xcode installed locally and Mac App Store requires upgrading macOS to download the latest Xcode.
- **Decision**:
  - Implement a GitHub Actions workflow (`.github/workflows/build_app.yml`) running on `macos-latest` runners.
  - Automatically resolve SPM dependencies, compile Release targets with ad-hoc signing (`CODE_SIGN_IDENTITY="-"`), package into `.zip`, and upload as an artifact.
- **Consequences**: Allows building, testing, and distributing custom `.app` builds in under 3 minutes without local Xcode installations or macOS upgrades.
