# Package tests

`smoke-test.sh` checks an installed VLC Neon in a clean container: version, plugin inventory,
audio and video decoding (to WAV / Y4M files), and the Qt interface under Xvfb with the built-in
Neon integration test (`VLC_REBORN_TEST_REPORT`), which exercises seek previews, seeking, speed,
repeat, A–B loop, recording, frame stepping, compact mode and fullscreen.

```bash
podman build -t vlc-neon-test-fedora -f tests/Containerfile.fedora tests
podman run --rm -v "$PWD:/w:Z" vlc-neon-test-fedora bash -c \
  'dnf -y install /w/dist/vlc-neon-*.rpm && /w/tests/smoke-test.sh vlc-neon /w/demo.mp4 /tmp/out'
```

Use a video with audio of at least a minute as the test media (the integration test needs the video to still be playing when it reaches the fullscreen step). Under Xvfb there is no window manager or sound
device, so the seek-bar mouse checks and the volume-boost check need a real session
(for example a nested `kwin_wayland --virtual`) to pass.
