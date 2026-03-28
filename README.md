# OpenPaste

A modern macOS clipboard management application built with SwiftUI.

## Overview

OpenPaste is a clipboard companion for macOS that helps you manage your copy/paste history with ease.

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Swift 5.9+

## Building

1. Open `OpenPaste.xcodeproj` in Xcode
2. Select the OpenPaste scheme
3. Press Cmd+R to build and run

Or build from command line:

```bash
xcodebuild -project OpenPaste.xcodeproj -scheme OpenPaste -configuration Debug
```

## Installation

### From Source

```bash
git clone https://github.com/fictionking/openpaste.git
cd openpaste
xcodebuild -project OpenPaste.xcodeproj -scheme OpenPaste
open build/Release/OpenPaste.app
```

### Homebrew (Coming Soon)

```bash
brew install --cask openpaste
```

## Features

- **Clipboard History**: Automatically captures all copy/paste operations
- **Quick Access**: Global hotkey (⌘⇧V) to show floating panel
- **Smart Organization**: Auto-categorization by source app
- **Pinning**: Pin important items to prevent expiry
- **Search**: Multi-dimensional search by content, type, date, and source
- **Privacy**: All data stored locally, no cloud sync

## Keyboard Shortcuts

- ⌘⇧V - Show/hide clipboard history

## License

This project is licensed under the MIT License - see the [MIT-LICENSE](MIT-LICENSE) file for details.

## License

This project is licensed under the MIT License - see the [MIT-LICENSE](MIT-LICENSE) file for details.
