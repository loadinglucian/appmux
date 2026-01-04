# AppMux

A macOS menu bar application for grouping and managing windows from multiple applications into unified tab groups.

## What is AppMux?

AppMux brings browser-style tabbed window management to your entire desktop. Group windows from any application into a single tab bar, switch between them instantly, and keep your workspace organized.

## Features

- **Window Grouping** - Combine windows from different applications into a single tabbed interface
- **Floating Tab Bar** - A non-intrusive tab bar appears above your grouped windows
- **Drag & Drop** - Drag any window onto an existing group to add it
- **Quick Switching** - Click tabs or use the tab bar to switch between grouped windows
- **Window Restoration** - Dissolve groups to restore windows to their original positions
- **Global Hotkey** - Press `Ctrl+Opt+Cmd+Shift+G` to create a new group from the current window

## Requirements

- macOS (uses native Accessibility API)
- Accessibility permissions must be granted to AppMux

## Installation

1. Clone this repository
2. Open `AppMux.xcodeproj` in Xcode
3. Build and run the project
4. Grant accessibility permissions when prompted

## Usage

1. **Create a Group**: Focus a window and press `Ctrl+Opt+Cmd+Shift+G`, or use the menu bar
2. **Add Windows**: Drag windows onto an existing tab group's tab bar
3. **Switch Tabs**: Click on tabs in the floating tab bar
4. **Dissolve Group**: Use the menu bar to dissolve groups and restore windows

## Building

```bash
# Debug build
xcodebuild -project AppMux.xcodeproj -scheme AppMux -configuration Debug build

# Release build
xcodebuild -project AppMux.xcodeproj -scheme AppMux -configuration Release build

# Clean
xcodebuild -project AppMux.xcodeproj -scheme AppMux clean
```

## Architecture

AppMux is built with SwiftUI and uses a service-oriented architecture:

- **WindowManagerService** - Core group management and window positioning
- **WindowObserverService** - Monitors window lifecycle events via AXObserver
- **AccessibilityService** - Wraps macOS Accessibility API
- **DragDropService** - Handles global mouse events for drag-and-drop
- **HotkeyService** - Manages global keyboard shortcuts

## Dependencies

- [HotKey](https://github.com/soffes/HotKey) - Global keyboard shortcut handling

## License

MIT License - see [LICENSE](LICENSE) for details.
