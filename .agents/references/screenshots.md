# Screenshots

- A PR that changes what the app looks like attaches real-app screenshots, dark and light, when it's opened. They go in the template's Screenshots section.
- Nothing real may show behind the UI: no desktop, wallpaper, menu bar or other apps' windows, not even blurred through the glass. Before opening the panel, cover the screen with a generated backdrop window: borderless, ignoring the mouse, at a level just below `.floating`, so it sits above app windows and under the launcher. Draw soft colour gradients and a few solid shapes on it, so the Liquid Glass has something to blur and tint. Use a deep palette for dark and a pastel one for light. Wait until it has drawn before opening the launcher.
- Crop the shot from a full-screen `screencapture -x`: take the panel plus a margin of backdrop, and keep the menu bar and Dock out. `screencapture -l <window id>` captures the window without what's behind it, so the glass comes out flat.
- Force light mode with `-NSRequiresAquaSystemAppearance YES`.
- When automating, close the launcher with its own shortcut (⌘Space, or ⌥Space until ⌘Space reaches Mado), not Esc.
- Open every image before attaching it and check that only the generated backdrop shows.
- Upload with `gh pr create --attach` or `gh pr edit --attach`, then move the images from the end of the body into the Screenshots section.
- Say in the PR when sample data came from a local patch that isn't in it, and that light mode was forced.

## Recordings

- When the change is something you interact with, like a popover, toggles, reordering or a new flow, also attach a short screen recording of the real app. Keep the dark and light screenshots too.
- Record over the same generated backdrop as the screenshots, so nothing real shows. Start recording once the launcher is already open, with no app startup or blank lead-in. Keep the steps brisk.
- Record a region with `screencapture -x -v -V<seconds> -R<x,y,w,h> out.mov`. Convert it to MP4 with ffmpeg if needed: `ffmpeg -i out.mov -vf "crop=trunc(iw/2)*2:trunc(ih/2)*2" -c:v libx264 -pix_fmt yuv420p out.mp4`. The crop trims one pixel off an odd width or height, which `yuv420p` can't encode.
- Drive the steps through the Accessibility API (`AXUIElementPerformAction` with `kAXPressAction`) or with `CGEvent.postToPid` and `-MadoNoFocus YES` on a Debug build, since Release builds ignore that flag. Never move the user's pointer. Say in the PR that no pointer shows because the steps were driven through Accessibility or posted events, instead of adding a fake cursor.
- With `-MadoNoFocus` the panel isn't key, so native controls like `NSSwitch` draw in their inactive grey style. Say so in the PR.
- Watch the whole clip before attaching it, and check that only the generated backdrop shows.
- Upload it with `gh pr create --attach` or `gh pr edit --attach` like the images, then move it into the Screenshots section.
