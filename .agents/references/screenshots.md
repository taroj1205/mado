# Screenshots

- A PR that changes what the app looks like attaches real-app screenshots, dark and light, when it's opened. They go in the template's Screenshots section.
- Take every shot and recording in the test VM with `scripts/vm.sh`, not on the Mac's own screens. It runs a [Tart](https://tart.run) macOS VM with its own display, keyboard and pointer, so nothing on the Mac moves or loses focus. It needs Tart, tmux and vncdotool (`uv tool install vncdotool`). Create the VM once with `tart clone ghcr.io/cirruslabs/macos-tahoe-base:latest mado-vm`. Then `scripts/vm.sh up` boots it, `scripts/vm.sh launch [Mado.app] [app args...]` copies in the Debug build (default `build/Build/Products/Debug/Mado.app`) and opens it, `scripts/vm.sh view` shows the VM's screen in Screen Sharing, and `scripts/vm.sh done` frees the VM for the next session. Every worktree shares the one VM; `launch`, `vnc` and `down` wait while another worktree is using it.
- Nothing real may show behind the UI: no desktop, wallpaper, menu bar or other apps' windows, not even blurred through the glass. Before opening the panel, cover the VM's screen with a generated backdrop window: borderless, ignoring the mouse, at a level just below `.floating`, so it sits above app windows and under the launcher. Draw soft colour gradients and a few solid shapes on it, so the Liquid Glass has something to blur and tint. Use a deep palette for dark and a pastel one for light. Build it on the Mac, copy it in with `tar -cf - backdrop | tart exec -i mado-vm tar -xf - -C /tmp`, start it with `tart exec mado-vm sh -c 'nohup /tmp/backdrop >/dev/null 2>&1 &'`, and wait until it has drawn before opening the launcher.
- Capture the VM's screen with `scripts/vm.sh vnc capture full.png`, then crop the panel plus a margin of backdrop, and keep the menu bar and Dock out.
- Switch the VM between dark and light with `tart exec mado-vm osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'` (`false` for light).
- Drive the launcher with `scripts/vm.sh vnc`, for example `scripts/vm.sh vnc key meta-space pause 1 type calc key enter`. On this VNC server `alt-` is ⌘ and `meta-` is ⌥. `type` doesn't add Shift, so send shifted characters as keys (`key shift-8` for `*`).
- When automating, close the launcher with its own shortcut (⌥Space, `key meta-space`), not Esc.
- The first time a new VM runs `osascript` or a recording, macOS in the VM asks for permission. Find the dialog with `vnc capture`, click Allow with `scripts/vm.sh vnc move <x> <y> click 1` (coordinates are the capture's pixels), and rerun the command.
- Open every image before attaching it and check that only the generated backdrop shows.
- Upload with `gh pr create --attach` or `gh pr edit --attach`, then move the images from the end of the body into the Screenshots section.
- Say in the PR when sample data came from a local patch that isn't in it.

## Recordings

- When the change is something you interact with, like a popover, toggles, reordering or a new flow, also attach a short screen recording of the real app. Keep the dark and light screenshots too.
- Record over the same generated backdrop as the screenshots, so nothing real shows. Start recording once the launcher is already open, with no app startup or blank lead-in. Keep the steps brisk.
- Record a region inside the VM with `tart exec mado-vm screencapture -x -v -V<seconds> -R<x,y,w,h> /tmp/out.mov` (points, not capture pixels), started in the background so you can drive the steps meanwhile. Copy it out with `tart exec mado-vm cat /tmp/out.mov > out.mov`. Convert it to MP4 with ffmpeg if needed: `ffmpeg -i out.mov -vf "crop=trunc(iw/2)*2:trunc(ih/2)*2" -c:v libx264 -pix_fmt yuv420p out.mp4`. The crop trims one pixel off an odd width or height, which `yuv420p` can't encode.
- Drive the steps with `scripts/vm.sh vnc` keys, moves and clicks. They are real input inside the VM, so the panel stays key and the VM's pointer shows in the clip where it moved.
- Watch the whole clip before attaching it, and check that only the generated backdrop shows.
- Upload it with `gh pr create --attach` or `gh pr edit --attach` like the images, then move it into the Screenshots section.
