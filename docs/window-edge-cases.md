# Window management edge cases

What every window action does when the window is in full screen, on another Space, under Stage Manager, or moving between displays with different scale factors. Measured on 2026-10-03, and on 2026-10-05 for Stage Manager, macOS 26.6.2 (M2-22).

## Results

| Action | Full screen | Another Space | Stage Manager | Mixed DPI (2x ↔ 1x) |
| --- | --- | --- | --- | --- |
| Layouts (hotkeys, root commands, radial zones) | Refused by macOS. The window stays as it is and Mado reports no error. | Applied to the hidden window. | Exact for the window on the stage. Maximise and left-side layouts cover the strip, which slides out of view. Can't pick a window in the strip: layouts act on the window in front. Called on it directly, the layout lands and it stays in the strip. | Exact on the 1x display |
| Restore | Nothing to restore after a refused layout | Back to the pre-snap frame | Back to the pre-snap frame, on the stage or in the strip | Back to the pre-snap frame on the other display |
| Next / previous display | Refused, window stays | Moves. A window sent to a display that is showing a full-screen app lands behind it, out of sight. | Moves exactly and joins the other display's stage. The next window in the strip takes its place. Called on a window in the strip directly, it moves and shows on the other display. | Keeps its relative frame, both directions |
| macOS full screen (radial) | Already full screen, no change | Can't pick the hidden window: the radial acts on the window in front. Called on the hidden window directly, it enters full screen and the display switches to the new Space. | Enters full screen on its own Space. Leaving puts it back on the stage at its old frame. Called on a window in the strip directly, it enters full screen too and comes to the front. | Enters full screen on the 1x display |
| Move gesture (fn⌃) | Window stays. The outline and HUD still follow the pointer. | Can't pick the hidden window: the pointer finds the visible window in front. Called on the hidden window directly, the move lands. | Exact for the window on the stage. With the default target, a drag that starts over the strip does nothing (see the pointer row). Called on a window in the strip directly, the move lands and it stays in the strip. | Crosses the display edge and lands exactly |
| Resize gesture (fn⌃⌥) | Window stays. The outline and HUD still follow the pointer. | Can't pick the hidden window: the pointer finds the visible window in front. Called on the hidden window directly, the resize lands exactly. | Exact for the window on the stage. With the default target, a drag that starts over the strip does nothing (see the pointer row). Called on a window in the strip directly, the resize lands and it stays in the strip. | Exact after crossing displays |
| Window under the pointer (gesture target) | Finds the full-screen window | Finds the visible full-screen window, not the hidden one behind it | Finds the window on the stage. Over a strip thumbnail, or within 30 pt of the display's left edge even when a window covers it, it finds Stage Manager instead of a window, so a gesture there does nothing. | Finds the window on the 1x display |
| Radial ring, snap preview, gesture HUD | Shown over the full-screen app. The preview still draws the layout that macOS will refuse. | Shown on the current Space | Shown over the stage. Showing them doesn't change the stage or the app in front. | Shown on the 1x display |
| ⌥Tab: list | Listed | Not listed | Lists windows on the stage and in the strip. Windows in the strip have no thumbnail and come after the windows on screen. | Listed |
| ⌥Tab: focus | Comes to the front | Can't, the window isn't listed | Brings a window from the strip onto the stage. The window that was there goes to the strip. | Comes to the front |
| ⌥Tab: close | Closes, and its Space goes away | Can't, the window isn't listed | Closes a window in the strip. The stage stays as it is. | Closes |
| App hotkey (toggle) | Comes to the front. Pressing it again hides the app, but its window stays on screen. | The display switches to that Space and the app comes to the front. Pressing it again hides it. | Brings the app from the strip onto the stage. Pressing it again hides it and leaves the stage empty: the window that was there before stays in the strip, and Finder becomes active. | Comes to the front on the 1x display. Pressing it again hides it. |

"Another Space" means the window's Space is not the one its display is showing. The test covered its display with another app's full-screen Space. "Stage Manager" means Stage Manager is on and the window is on the Sidecar, either on the stage in the middle or in the strip of recent apps on the left.

## Known limitations

- **Full-screen windows can't be moved or resized.** macOS refuses the frame change, and Mado gives no feedback. The radial preview and the gesture outline still show where the window would go. Leave full screen first.
- **Sending a window to a display that is showing a full-screen app hides it.** It lands on that display's desktop Space, behind the full-screen app.
- **Hiding a full-screen app with its hotkey leaves its window showing.** The app is hidden and inactive, but its full-screen Space stays on the display with the window in it.
- **⌥Tab lists only windows on the Spaces currently shown.** The Accessibility window list leaves out windows on other Spaces, so they can't be focused or closed from the switcher.
- **Layouts don't leave room for the Stage Manager strip.** Maximise and left-side layouts use the whole display, so the window covers the strip and Stage Manager slides it out of view until the window moves away.
- **Gestures can't start over the Stage Manager strip.** With the default target, the pointer finds Stage Manager's thumbnails instead of a window. The same goes for the 30 pt along the display's left edge, even when a window covers it.
- **Hiding an app with its hotkey under Stage Manager leaves the stage empty.** The window that was on the stage before stays in the strip, and Finder becomes active.
- **⌥Tab shows no thumbnail for windows in the Stage Manager strip.** The window server reports the thumbnail's frame for them, so the switcher can't match them to a window number, and they come after the windows on screen.

Fixed while measuring: a layout refused in full screen used to save the full-screen frame as the restore point, so Restore after leaving full screen stretched the window to fill the display. Refused moves no longer save a restore point.

## How it was measured

A probe program ran the same WindowKit calls that the actions use (`WindowPlacement`'s layout, restore and display steps, `setFrame(_:changedFrom:)` for gestures, `FocusedWindow.under(quartzPoint:)`, `WindowList`) against a test window owned by a child process, by pid. It read the frame back after 600 ms and compared it with the target. Mado's own hotkey and pointer handling were not part of that run.

⌥Tab focus and the app hotkey were measured end to end: a Debug build of Mado ran with its real hotkeys, and the keys were posted as hardware events while nobody was using the Mac. A probe that activates apps itself can't measure these, because macOS ignores some activation requests from an app that didn't receive the key press. The switcher's request for screen-recording access was turned off in that build so the system prompt couldn't take focus; thumbnails don't affect which window gets focus.

The Stage Manager column used two probe apps on the Sidecar, one on the stage and one in the strip. The probe ran the same WindowKit calls on both, and showed an `OverlayPanel`, the panel the radial ring, snap preview and gesture HUD use. ⌃⌥←, ⌥Tab focus and close, and the app hotkey ran end to end as above. In that build the switcher listed only the two probe apps and didn't capture thumbnails.

Displays: built-in Retina (2x, 1800×1169 pt), Sidecar (2x, 1590×1192 pt), and a temporary 1x virtual display (1920×1080) created with `CGVirtualDisplay` for the mixed-DPI column. The end-to-end run put its full-screen and other-Space windows on that 1x display.
