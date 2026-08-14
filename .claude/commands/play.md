Run the game (play mode, not the editor) for this directory.

- If a previous play-mode instance from this session is still tracked as running, stop it first (don't stack windows).
- Launch the Godot executable in the background with `--path "<current directory>"` and `--rendering-driver opengl3` (required on this machine — the default Vulkan renderer segfaults on the Intel iGPU).
- Give a short, headline-style test prompt: one line, what to do + what to expect. No verbose explanation unless something's actually wrong.
- Only run gdformat/gdlint/headless-import-check first if there's an uncommitted code change since the last check — not on every invocation.
