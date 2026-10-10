// SPDX-License-Identifier: GPL-2.0-or-later
// VLC Neon Picture-in-Picture on Wayland: a client cannot choose its position or stay on top, so KWin does it.
// The app turns its main window into the PiP window and sets this exact title; going back restores the old title.
const PIP_TITLE = "VLC Neon Picture-in-Picture";
const MARGIN = 16;
const TAG = "vlc-neon-pip: ";

let lastPipPosition = null;   // where the user left the PiP window (kept while KWin runs)
const states = {};
      // last position of each VLC Neon window while it was NOT in PiP (restored when PiP ends)            // per-window state, keyed by internalId (window objects do not take extra properties)

// Info logging is off; flip DEBUG to trace placement in the journal (journalctl --user -b | grep vlc-neon-pip)
const DEBUG = false;
function log(msg) { if (DEBUG) console.warn(TAG + msg); }

function isVlcNeon(window) {
    return window.normalWindow && /vlc/i.test(String(window.resourceClass) + " " + String(window.resourceName) + " " + String(window.desktopFileName));
}

function isPip(window) {
    // KWin appends the application name to the caption ("<title> — VLC Neon"), so match the prefix
    return isVlcNeon(window) && String(window.caption).indexOf(PIP_TITLE) === 0;
}

function rectOf(g) { return { x: g.x, y: g.y, width: g.width, height: g.height }; }

function clampToWorkArea(window, x, y) {
    const area = workspace.clientArea(KWin.PlacementArea, window);
    const g = window.frameGeometry;
    return {
        x: Math.round(Math.max(area.x + MARGIN, Math.min(x, area.x + area.width - g.width - MARGIN))),
        y: Math.round(Math.max(area.y + MARGIN, Math.min(y, area.y + area.height - g.height - MARGIN)))
    };
}

function placePip(window) {
    const area = workspace.clientArea(KWin.PlacementArea, window);   // work area of the window's screen: above the panel
    const g = window.frameGeometry;
    const wanted = lastPipPosition
        ? lastPipPosition
        : { x: area.x + area.width - g.width - MARGIN, y: area.y + area.height - g.height - MARGIN };
    const p = clampToWorkArea(window, wanted.x, wanted.y);
    window.frameGeometry = { x: p.x, y: p.y, width: g.width, height: g.height };
    log("placed at " + p.x + "," + p.y + " size " + g.width + "x" + g.height + " work area " + JSON.stringify(rectOf(area)));
}

function enterPip(window) {
    const id = String(window.internalId);
    if (states[id])
        return;
    const g = window.frameGeometry;
    const state = states[id] = { above: window.keepAbove, settled: false };
    log("PiP started: frame=" + JSON.stringify(rectOf(g)) + " client=" + JSON.stringify(rectOf(window.clientGeometry))
        + " buffer=" + JSON.stringify(rectOf(window.bufferGeometry)) + " output=" + window.output.name);
    window.keepAbove = true;
    log("keepAbove=" + window.keepAbove);
    // The app resizes the window right after changing the title (and drops its shadow margin): keep the window in the
    // bottom-right corner while that settles, then only keep it inside the work area.
    state.onGeometry = () => {
        if (!states[id] || window.move || window.resize) return;
        if (!state.settled) {
            placePip(window);
        } else {
            const now = window.frameGeometry;
            const p = clampToWorkArea(window, now.x, now.y);
            if (p.x !== Math.round(now.x) || p.y !== Math.round(now.y))
                window.frameGeometry = { x: p.x, y: p.y, width: now.width, height: now.height };
        }
    };
    window.frameGeometryChanged.connect(state.onGeometry);
    state.timer = new QTimer();
    state.timer.singleShot = true;
    state.timer.interval = 1000;
    state.timer.timeout.connect(() => { state.settled = true; log("settled at " + JSON.stringify(rectOf(window.frameGeometry))); });
    state.timer.start();
    state.onGeometry();
}

function leavePip(window) {
    const id = String(window.internalId);
    const state = states[id];
    if (!state)
        return;
    delete states[id];
    window.frameGeometryChanged.disconnect(state.onGeometry);
    const g = window.frameGeometry;
    lastPipPosition = { x: g.x, y: g.y };
    log("PiP ended at " + g.x + "," + g.y);
    workspace.windowList().forEach((w) => { if (isVlcNeon(w) && !isPip(w)) log("main window minimized after PiP ended: " + w.minimized); });
}

// "Back to main window": the PiP window is renamed "<title> (back)" just before it goes away. A Wayland client can not
// un-minimize its own window, so the main window is restored and activated here.
function restoreMainWindows() {
    workspace.windowList().forEach((w) => {
        if (isVlcNeon(w) && !isPip(w)) {
            log("restoring main window (was minimized: " + w.minimized + ")");
            w.minimized = false;
            workspace.activeWindow = w;
            log("main window now minimized: " + w.minimized);
        }
    });
}

function track(window) {
    try {
        if (!isVlcNeon(window))
            return;
        log("tracking window: caption=\"" + window.caption + "\" class=" + window.resourceClass);
        if (isPip(window))
            enterPip(window);
        window.captionChanged.connect(() => {
            try {
                log("caption changed: \"" + window.caption + "\"");
                if (isPip(window)) {
                    enterPip(window);
                    if (String(window.caption).indexOf("(back)") >= 0)
                        restoreMainWindows();
                } else {
                    leavePip(window);
                }
            } catch (e) { console.warn(TAG + "ERROR in captionChanged: " + e); }
        });
        window.interactiveMoveResizeFinished.connect(() => {
            if (states[String(window.internalId)]) {
                const g = window.frameGeometry;
                lastPipPosition = { x: g.x, y: g.y };
                log("user moved/resized PiP to " + JSON.stringify(rectOf(g)));
            }
        });
    } catch (e) {
        console.warn(TAG + "ERROR tracking window: " + e);
    }
}

log("script loaded");
workspace.windowRemoved.connect((window) => {
    try { if (states[String(window.internalId)]) leavePip(window); } catch (e) { console.warn(TAG + "ERROR in windowRemoved: " + e); }
});
workspace.windowAdded.connect(track);
workspace.windowList().forEach(track);
