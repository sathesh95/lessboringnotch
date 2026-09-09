# Project Context & Development Guidelines: boring.notch

> **CRITICAL DIRECTIVE**: The primary development and testing target is an **Apple Silicon MacBook M1 without a physical notch** (e.g., MacBook Air M1, MacBook Pro 13" M1). All new features, UI layouts, animations, and window behaviors MUST be fully compatible with non-notch Macs without causing visual glitches, clipping, misalignment, or breaking physical notch compatibility.

---

## 1. Target Hardware & Display Constraints

### Primary Environment: Non-Notch MacBook (M1)
- **Safe Area Insets**: `screen.safeAreaInsets.top == 0` (No hardware cutout).
- **Notch Mode**: Uses a simulated notch anchored to the top-center of the screen.
- **Closed Notch Dimensions**:
  - Controlled by `Defaults[.nonNotchHeight]` and `Defaults[.nonNotchHeightMode]` (defaults to matching menu bar height, typically ~24–32pt).
  - Width is dynamically computed or defaults to ~185pt (customizable via sizing rules in `sizing/matters.swift`).
- **Open Notch Dimensions**:
  - `openNotchSize` is standard (`640x190pt` base) and expands downward with smooth spring animations.

### Compatibility Checklist for Every Feature
1. **Never Assume Hardware Insets**: Never rely on `screen.safeAreaInsets.top > 0` for positioning or visibility unless providing a fallback for `0`.
2. **Dynamic Height Resolution**: Always use `vm.effectiveClosedNotchHeight` and `getClosedNotchSize(screenUUID:)` rather than fixed constants.
3. **Hover & Hit Testing**: Hitbox detection (`isMouseHovering`) must correctly align with the top edge of non-notch menu bars.
4. **Corner Radii & Clip Shapes**: `NotchShape` and `BottomRoundedRectangle` must scale appropriately in both closed (minimal curve) and opened (expanded rounded rectangle) states.
5. **Fullscreen Behavior**: On non-notch screens, fullscreen windows may hide or collapse the menu bar; ensure `hideOnClosed` and detector logic properly handle auto-reveal or collapse.

---

## 2. Codebase Architecture Overview

### Technology Stack
- **Language**: Swift 5.9+ / Swift 6
- **UI Frameworks**: SwiftUI + AppKit (`NSPanel`, `NSWindowController`, `NSViewRepresentable`)
- **State & Persistence**: `Defaults` (Swifty `UserDefaults`), Combine (`ObservableObject`, `@Published`, `PassthroughSubject`)
- **Media Remote / System Integration**: `MediaRemoteAdapter`, `XPCHelperClient`, `AppleScriptHelper`, `WebcamManager`

### Core Components & Modules

| Module / Directory | Responsibility |
| :--- | :--- |
| `boringNotch/boringNotchApp.swift` | App lifecycle, status bar menu initialization, window setup |
| `boringNotch/ContentView.swift` | Root SwiftUI container hosting `NotchLayout`, closed chin, header, and active tab view |
| `boringNotch/models/BoringViewModel.swift` | Core view model for notch state (`open`, `closed`), hover logic, drag detection, and dimensions |
| `boringNotch/BoringViewCoordinator.swift` | Routing coordinator managing active tab (`home`, `shelf`, `calendar`, etc.), live activities, sneak peek |
| `boringNotch/sizing/matters.swift` | Geometry computations (`getClosedNotchSize`, `getScreenFrame`, standard sizes) |
| `boringNotch/components/Notch/` | Window shells (`BoringNotchWindow`, `BoringNotchSkyLightWindow`), shapes, and headers |
| `boringNotch/MediaControllers/` | Media player abstraction (`MediaControllerProtocol`, Spotify, Apple Music, YouTube Music, Now Playing) |
| `boringNotch/components/Shelf/` | Drag-and-drop shelf system (bookmarks, file actions, preview, drop target) |
| `boringNotch/components/Live activities/` | Mini HUDs (Battery, InlineHUD, Downloads, Volume/Brightness) |
| `boringNotch/components/Settings/` | Preference panels, tab reordering, and customization UI |

---

## 3. State Management & Navigation Flow

1. **State Ownership**:
   - `BoringViewModel` tracks per-screen notch state (`notchState`, `closedNotchSize`, `notchSize`).
   - `BoringViewCoordinator` tracks global UI navigation (`currentView`, `sneakPeek`, `expandingView`).
2. **Opening / Closing Mechanics**:
   - **Open**: Triggered by mouse hover (`openNotchOnHover`), hotkey, or clicking notch icon/chin.
   - **Close**: Triggered by mouse exit (with delay), swipe gesture up, or explicit escape key.
   - **Prevent Close**: `SharingStateManager.shared.preventNotchClose` prevents dismissal during active share sheets, file drag operations, or modal popovers.

---

## 4. Development & Contribution Rules

Before implementing any feature or modification:
1. **Consult This File**: Confirm that proposed changes respect non-notch screen geometry and state invariants.
2. **Safe UserDefaults**: Define new configuration keys in `boringNotch/models/Constants.swift` under `Defaults.Keys`.
3. **Keep Animations Smooth**: Use standard animation curves defined in `BoringAnimations` (spring animations with matching response/damping).
4. **Preserve Audio/Media Interception**: Ensure background polling and media observers remain low on CPU/battery footprint.
5. **No Regressions on Multi-Display**: Pass `screenUUID` when querying frames or sizing to ensure multi-monitor setups work reliably.
