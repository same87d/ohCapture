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

## Current prototype

1. Build and open `build/ohCapture.app`.
2. Allow Screen Recording access when macOS asks, then relaunch ohCapture.
3. Press `Option + Shift + 2`, or choose **Interactive Capture** from the menu-bar icon.
4. Move the pointer over a window and click to capture its complete contents without raising it.
5. Or drag a rectangle to capture a free-form region on the current display.
6. Use the floating toolbar to copy, save, or close the captured image.

Press `Enter` to copy, `Command + S` to save, or `Escape` to close the preview.

Press `Escape` to cancel the capture overlay. The **Capture Window…** menu item remains available as a diagnostic window picker.

## Install

```sh
./scripts/install.sh
```

## Roadmap

The first engineering milestone validates the highest-risk path: discover windows, select an obscured window, capture its complete contents without raising it, and save the result as PNG.

## License

MIT
