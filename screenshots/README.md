# Screenshots

Temporary storage for UI screenshots during implementation.

**Not committed to git** (see `.gitignore`).

## Usage

- Implementation chat: save UI reference screenshots here during work
- Name format: `YYYYMMDD_description.png` (e.g., `20260815_stats_overlay_v1.png`)
- Clear old screenshots regularly to avoid clutter

## Cleanup

Run cleanup script when version ships or screenshots accumulate:

**Windows (PowerShell):**
```powershell
.\cleanup.bat
```

**macOS/Linux (Bash):**
```bash
./cleanup.sh
```

Both scripts delete screenshots older than 7 days.

## Manual Cleanup

Delete folder contents and re-save only current work:
```bash
rm screenshots/*.png
```

## Version Release

Before cutting a version tag, clear all old screenshots:
```bash
# Clear everything except this README and cleanup scripts
rm screenshots/*.png screenshots/*.jpg
```

This keeps the repo light and prevents old UI iterations from cluttering the workspace.
