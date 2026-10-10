# Changelog

## v1.0.1 — 2026-10-10

### Fixed
- Fixed stale plugin cache warning (faster startup).

## v1.0.0 — 2026-10-10

First public release of VLC Neon, built on VLC 4.0.0-dev (upstream commit `e77e49b5`).

### Added
- Neon identity: new neon cone icon, Inter typography with tabular figures, own app ID (`org.VideoLAN.VLCNeon`), command (`vlc-neon`) and settings folders, so it runs next to regular VLC.
- Seek-bar thumbnail previews with timestamp (asynchronous, cached, also in fullscreen).
- Picture-in-Picture in a separate, always-on-top window (Wayland) with its own seek bar, ±3 s / ±10 s, play/pause and mute; optional KWin script for placement on KDE Plasma.
- Speed presets from 0.25× to 4× in one menu (Normal in the middle), plus native fine adjustment.
- Repeat menu: Off, 1–5 extra plays, or Unlimited, with a badge on the toolbar button; remembered between sessions.
- Volume boost presets up to 300 % with a peak limiter.
- Resume prompt for local files and a history of the last 100 files; per-file speed, volume, audio/subtitle tracks and delays.
- Video information panel (codec, resolution, decoder, hardware decoding).
- ±3 s skip buttons and an extended default toolbar (screenshot, record, A–B loop, frame stepping).
- File / right-click menu: copy current timestamp, copy media path, open containing folder.
- Hotkeys: ←/→ 5 s, Shift 10 s, Ctrl 60 s; E / Shift+E next/previous frame.
- Animated GIFs play and loop.

### Fixed
- Screenshots work with hardware-decoded video.
- No more "DVDRead could not open the disc" error dialog when opening regular files.
- Wayland: video keeps working when the EGL driver lacks display reference tracking; no stall or hang on quit when the window is minimized.

### Packages
- `.rpm` for Fedora, `.AppImage`, `.flatpak` bundle and the complete source tarball.

---

☕ If VLC Neon is useful to you, you can support it on [Ko-fi](https://ko-fi.com/taoufikmouadab).
