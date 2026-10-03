# Window management edge cases

What every window action does when the window is in full screen, on another Space, under Stage Manager, or moving between displays with different scale factors. Measured on 2026-10-03, macOS 26.6.2 (M2-22).

## Results

| Action | Full screen | Another Space | Stage Manager | Mixed DPI (2x ↔ 1x) |
| --- | --- | --- | --- | --- |
| Layouts (hotkeys, root commands, radial zones) | Refused by macOS. The window stays as it is and Mado reports no error. | Applied to the hidden window. | Not measured | Exact on the 1x display |
| Restore | Nothing to restore after a refused layout | Back to the pre-snap frame | Not measured | Back to the pre-snap frame on the other display |
| Next / previous display | Refused, window stays | Moves. A window sent to a display that is showing a full-screen app lands behind it, out of sight. | Not measured | Keeps its relative frame, both directions |
| macOS full screen (radial) | Already full screen, no change | Enters full screen, and the display switches to the new Space | Not measured | Enters full screen on the 1x display |
| Move gesture (fn⌃) | Window stays. The outline and HUD still follow the pointer. | Moves the hidden window | Not measured | Crosses the display edge and lands exactly |
| Resize gesture (fn⌃⌥) | Window stays. The outline and HUD still follow the pointer. | Resizes the hidden window exactly | Not measured | Exact after crossing displays |
| Window under the pointer (gesture target) | Finds the full-screen window | Finds the visible full-screen window, not the hidden one behind it | Not measured | Finds the window on the 1x display |
| Radial ring, snap preview, gesture HUD | Shown over the full-screen app. The preview still draws the layout that macOS will refuse. | Shown on the current Space | Not measured | Shown on the 1x display |
| ⌥Tab: list | Listed | Not listed | Not measured | Listed |
| ⌥Tab: focus | Comes to the front | Can't, the window isn't listed | Not measured | Comes to the front |
| ⌥Tab: close | Closes, and its Space goes away | Can't, the window isn't listed | Not measured | Closes |
| App hotkey (toggle) | Comes to the front. Pressing it again hides the app, but its window stays on screen. | The display switches to that Space and the app comes to the front. Pressing it again hides it. | Not measured | Comes to the front on the 1x display. Pressing it again hides it. |

"Another Space" means the window's Space is not the one its display is showing. The test covered its display with another app's full-screen Space.

## Known limitations

- **Full-screen windows can't be moved or resized.** macOS refuses the frame change, and Mado gives no feedback. The radial preview and the gesture outline still show where the window would go. Leave full screen first.
- **Sending a window to a display that is showing a full-screen app hides it.** It lands on that display's desktop Space, behind the full-screen app.
- **Hiding a full-screen app with its hotkey leaves its window showing.** The app is hidden and inactive, but its full-screen Space stays on the display with the window in it.
- **⌥Tab lists only windows on the Spaces currently shown.** The Accessibility window list leaves out windows on other Spaces, so they can't be focused or closed from the switcher.

Fixed while measuring: a layout refused in full screen used to save the full-screen frame as the restore point, so Restore after leaving full screen stretched the window to fill the display. Refused moves no longer save a restore point.

## Not measured yet

- **Stage Manager**: the whole column. It's a system setting, so it needs someone to turn it on for the run.

## How it was measured

A probe program ran the same WindowKit calls that the actions use (`WindowPlacement`'s layout, restore and display steps, `setFrame(_:changedFrom:)` for gestures, `FocusedWindow.under(quartzPoint:)`, `WindowList`) against a test window owned by a child process, by pid. It read the frame back after 600 ms and compared it with the target. Mado's own hotkey and pointer handling were not part of that run.

⌥Tab focus and the app hotkey were measured end to end: a Debug build of Mado ran with its real hotkeys, and the keys were posted as hardware events while nobody was using the Mac. A probe that activates apps itself can't measure these, because macOS ignores some activation requests from an app that didn't receive the key press. The switcher's request for screen-recording access was turned off in that build so the system prompt couldn't take focus; thumbnails don't affect which window gets focus.

Displays: built-in Retina (2x, 1800×1169 pt), Sidecar (2x, 1590×1192 pt), and a temporary 1x virtual display (1920×1080) created with `CGVirtualDisplay` for the mixed-DPI column. The end-to-end run put its full-screen and other-Space windows on that 1x display.
