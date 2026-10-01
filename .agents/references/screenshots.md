# Screenshots

- A PR that changes what the app looks like attaches real-app screenshots, dark and light, when it's opened. They go in the template's Screenshots section.
- Nothing real may show behind the UI: no desktop, wallpaper, menu bar or other apps' windows, not even blurred through the glass. Before opening the panel, cover the screen with a plain grey window: borderless, ignoring the mouse, at a level just below `.floating`, so it sits above app windows and under the launcher. Use about white 0.12 for dark and 0.94 for light.
- Capture the window alone with `screencapture -x -o -l <window id>`, not a crop of a full-screen capture. The launcher is the `Mado` window at layer 3 in `CGWindowListCopyWindowInfo`.
- Force light mode with `-NSRequiresAquaSystemAppearance YES`.
- Open every image before attaching it and check that only the grey backdrop shows through.
- Upload with `gh pr create --attach` or `gh pr edit --attach`, then move the images from the end of the body into the Screenshots section.
- Say in the PR when sample data came from a local patch that isn't in it, and that light mode was forced.
