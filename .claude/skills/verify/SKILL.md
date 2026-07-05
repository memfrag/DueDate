---
name: verify
description: Build, launch, and drive the DueDate macOS app to verify changes end-to-end with screenshots.
---

# Verifying DueDate

## Build

```bash
cd /Users/martinjohannesson/Projekt/git/Apps/DueDate
xcodebuild -project DueDate.xcodeproj -scheme "DueDate (Debug)" -destination 'platform=macOS,arch=arm64' build
```

Schemes are `DueDate (Debug)` and `DueDate (Release)` (note the spaces/parens).
Built app lands at:
`~/Library/Developer/Xcode/DerivedData/DueDate-*/Build/Products/Debug/DueDate.app`

## Launch & position (accessibility scripting works without extra prompts)

```bash
open <path-to>/DueDate.app && sleep 3
osascript -e 'tell application "DueDate" to activate
delay 0.3
tell application "System Events" to tell process "DueDate"
set position of front window to {60, 60}
set size of front window to {1500, 900}
end tell'
```

## Drive (clicks) and capture

No cliclick installed; use a tiny CGEvent Swift script (`swift click.swift X Y`
posts a left click at screen points):

```swift
import CoreGraphics
import Foundation
let x = Double(CommandLine.arguments[1])!, y = Double(CommandLine.arguments[2])!
for type in [CGEventType.leftMouseDown, .leftMouseUp] {
    CGEvent(mouseEventSource: nil, mouseType: type,
            mouseCursorPosition: CGPoint(x: x, y: y), mouseButton: .left)?
        .post(tap: .cghidEventTap)
    usleep(50_000)
}
```

Capture the window region: `screencapture -x -R60,60,1500,900 out.png` then
Read the PNG. Screenshot pixels are 2x window points; with the window at
{60,60}: screen point = 60 + (image px / 2).

## Gotchas

- The app is sandboxed: its files live under
  `~/Library/Containers/io.apparata.DueDate/Data/…` (SwiftData store,
  `Application Support/DueDate/ExchangeRates.json` FX cache, container tmp).
- `print()` from the GUI app is invisible (buffered, no tty; `script -q` also
  fails). For debug traces, append to a file in `NSTemporaryDirectory()`
  (the container tmp) and `cat` it from outside.
- Sidebar rows: `.badge()` must be INSIDE the NavigationLink label — wrapping
  the link breaks List selection (row highlights but selection becomes nil).

## Flows worth driving

- Subscriptions table → click row → read-only inspector fills in.
- Smart views (badges must match filtered row counts).
- Dashboard card math: monthly total × 12 == annual projection.
- FX: check the ExchangeRates.json cache appears after first launch (Riksbank).
- Editor sheet via toolbar `+` (Save disabled until name+amount valid).
