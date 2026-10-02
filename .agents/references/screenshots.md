# Screenshots

- A PR that changes what the app looks like attaches real-app screenshots, dark and light, when it's opened. They go in the template's Screenshots section.
- Nothing real may show behind the UI: no desktop, wallpaper, menu bar or other apps' windows, not even blurred through the glass. Before opening the panel, cover the screen with a generated backdrop window: borderless, ignoring the mouse, at a level just below `.floating`, so it sits above app windows and under the launcher. Draw soft colour gradients and a few solid shapes on it, so the Liquid Glass has something to blur and tint. Use a deep palette for dark and a pastel one for light. Wait until it has drawn before opening the launcher.
- Crop the shot from a full-screen `screencapture -x`: take the panel plus a margin of backdrop, and keep the menu bar and Dock out. `screencapture -l <window id>` captures the window without what's behind it, so the glass comes out flat.
- Force light mode with `-NSRequiresAquaSystemAppearance YES`.
- When automating, close the launcher with its own shortcut (⌘Space, or ⌥Space until ⌘Space reaches Mado), not Esc.
- Open every image before attaching it and check that only the generated backdrop shows.
- Also attach the canvas board the change follows, so the reviewer can compare the two. Read the board with the Artifact tool (`path: project/<Board>.dc.html`), remove its `support.js` script tag, and render it at 1280×800 with headless Chrome (`--headless=new --screenshot`). Chrome may hang after writing the file, so run it in the background and stop it once the PNG exists. Put it under the screenshots in `<details><summary>Design: <board title></summary>`, and name the board in the summary.
- Upload with `gh pr create --attach` or `gh pr edit --attach`, then move the images from the end of the body into the Screenshots section.
- Say in the PR when sample data came from a local patch that isn't in it, and that light mode was forced.
