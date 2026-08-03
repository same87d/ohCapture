# ohCapture

ohCapture is a lightweight, open-source screenshot utility for macOS. It is designed to capture regions or complete windows—including windows obscured by other windows—without changing the desktop's window order.

## MVP scope

- Global shortcut and rectangular selection
- Automatic window snapping
- Non-disruptive capture of obscured windows with ScreenCaptureKit
- Arrow, rectangle, text, numbered marker, and mosaic annotations
- Local OCR with Vision
- Screenshot translation

## Requirements

- macOS 14 or later
- Xcode 15 or later, including Command Line Tools

## Build

```sh
git clone https://github.com/YOUR_ACCOUNT/ohCapture.git
cd ohCapture
./scripts/build.sh
open build/ohCapture.app
```

The first capture asks for Screen Recording permission in System Settings.

## Install

```sh
./scripts/install.sh
```

## Roadmap

The first engineering milestone validates the highest-risk path: discover windows, select an obscured window, capture its complete contents without raising it, and save the result as PNG.

## License

MIT

