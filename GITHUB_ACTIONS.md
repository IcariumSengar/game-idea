# GitHub Actions: Automated Game Builds

Automatically build Windows and macOS executables whenever you push a release tag.

## How it works

1. You push a git tag (e.g., `git tag v5 && git push origin v5`)
2. GitHub Actions automatically builds the game for Windows and macOS
3. Builds appear as downloadable artifacts on the GitHub releases page
4. Friends download and play

## Setup (one-time)

### 1. Create the workflow file

Create `.github/workflows/export.yml`:

```yaml
name: Export Game

on:
  push:
    tags:
      - 'v*'

jobs:
  export:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        include:
          - platform: windows
            os: ubuntu-latest
          - platform: macos
            os: macos-latest

    steps:
      - uses: actions/checkout@v4
      
      - name: Export to ${{ matrix.platform }}
        uses: firebelley/godot-export@v5
        with:
          godot_executable_download_url: https://downloads.tuxfamily.org/godotengine/4.7.1/Godot_v4.7.1-stable_linux.x86_64.zip
          godot_export_templates_download_url: https://downloads.tuxfamily.org/godotengine/4.7.1/Godot_v4.7.1-stable_export-templates.tpz
          relative_project_path: ./
          export_debug: false
          cache: true
          create_release: true
          use_prerelease_export_templates: false
```

### 2. Ensure export presets exist

In the Godot editor, go to **Project > Export** and create export presets for:
- **Windows Desktop** (preset name: `Windows`)
- **macOS** (preset name: `Mac`)

Save these in `export_presets.cfg` and commit to git.

## Usage

When ready to ship a build:

```bash
git tag v5
git push origin v5
```

GitHub Actions will:
1. Build Windows executable
2. Build macOS app bundle
3. Create a GitHub release with both files as downloads

Your friends can download from: `https://github.com/YOUR_USERNAME/game-idea/releases/tag/v5`

## Notes

- **Free builds**: Public repo = unlimited free GitHub Actions minutes. No cost.
- **Build time**: ~10–15 minutes total per tag
- **macOS signing**: The exported .app will work on most Macs. If friends get security warnings, they can `xattr -dr com.apple.quarantine /path/to/game.app` to allow it.
- **Re-export if needed**: Delete the tag (`git tag -d v5 && git push origin :v5`), fix the code, re-tag, and re-push.

## Troubleshooting

**Builds fail?** Check the Actions tab on GitHub for logs. Common issues:
- Export presets missing or misconfigured
- Godot version mismatch (update the URLs in the workflow if needed)
- GDScript errors (fix in code and re-tag)

**Friends can't run the macOS app?** They may need to allow it in Security & Privacy settings, or use:
```bash
xattr -dr com.apple.quarantine ~/Downloads/game-idea.app
```

## Reference

- [GitHub Actions docs](https://docs.github.com/en/actions)
- [firebelley/godot-export action](https://github.com/firebelley/godot-export)
- [Godot export documentation](https://docs.godotengine.org/en/stable/tutorials/export/index.html)
