"""Two window-manager duties Hyprland's XWayland support leaves undone.

1. Override-redirect windows above managed ones. X11 apps place these
   themselves (menus, tooltips, Zoom's sharing toolbar), and Hyprland
   always draws them on top. But when Hyprland focuses a normal window
   it raises it to the top of the X stacking order, above them, and the
   X server sends clicks to whatever is topmost in *its* order. So a
   toolbar that is plainly visible stops taking clicks and drags. This
   keeps every mapped override-redirect window above the managed ones,
   matching what is on screen.

2. _NET_WM_MOVERESIZE. Hyprland lists it in _NET_SUPPORTED but never acts
   on it, so X11 apps that drag their own frameless windows that way
   (Qt's startSystemMove/Resize: Zoom's floating video) do not move.
   This carries the drag out: it follows Hyprland's cursor and moves the
   window with ordinary X configure requests, which Hyprland honours for
   floating windows, until the mouse button comes up.
"""
import json
import os
import socket
import time

from Xlib import X, display

MOVE, CANCEL = 8, 11
# _NET_WM_MOVERESIZE_SIZE_*: which edges (left, top, right, bottom) follow
# the pointer.
EDGES = {
    0: (True, True, False, False),
    1: (False, True, False, False),
    2: (False, True, True, False),
    3: (False, False, True, False),
    4: (False, False, True, True),
    5: (False, False, False, True),
    6: (True, False, False, True),
    7: (True, False, False, False),
}
MIN_W, MIN_H = 120, 60
BUTTONS = X.Button1Mask | X.Button2Mask | X.Button3Mask
RESTACK_ON = (X.ConfigureNotify, X.MapNotify, X.CirculateNotify)
HYPR = os.path.join(os.environ["XDG_RUNTIME_DIR"], "hypr",
                    os.environ["HYPRLAND_INSTANCE_SIGNATURE"],
                    ".socket.sock")


def hypr(cmd):
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
        s.connect(HYPR)
        s.sendall(cmd.encode())
        out = b""
        while chunk := s.recv(65536):
            out += chunk
    return json.loads(out)


def cursor():
    c = hypr("j/cursorpos")
    return c["x"], c["y"]


def is_tiled(x, y, w, h):
    # Hyprland's client list has no X window id; match by geometry.
    return any(c.get("xwayland") and not c["floating"]
               and c["at"] == [x, y] and c["size"] == [w, h]
               for c in hypr("j/clients"))


def restack(root):
    """Raise override-redirect windows that sit under a managed one."""
    stack = []
    for w in root.query_tree().children:  # bottom to top
        try:
            a = w.get_attributes()
        except Exception:
            continue
        if a.map_state == X.IsViewable:
            stack.append((w, a.override_redirect))
    seen_override = buried = False
    for _, override in stack:
        if override:
            seen_override = True
        elif seen_override:
            buried = True
            break
    if buried:
        # Bottom to top, so they keep their order among themselves.
        for w, override in stack:
            if override:
                w.configure(stack_mode=X.Above)


def follow(d, win, direction, moveresize):
    root = d.screen().root
    g = win.get_geometry()
    t = win.translate_coords(root, 0, 0)
    x0, y0, w0, h0 = -t.x, -t.y, g.width, g.height
    if is_tiled(x0, y0, w0, h0):
        return
    if root.grab_pointer(False, X.ButtonReleaseMask | X.PointerMotionMask,
                         X.GrabModeAsync, X.GrabModeAsync, X.NONE, X.NONE,
                         X.CurrentTime) != X.GrabSuccess:
        return
    cx0, cy0 = cursor()
    last = None
    deadline = time.monotonic() + 120
    try:
        while time.monotonic() < deadline:
            done = False
            while d.pending_events():
                ev = d.next_event()
                if ev.type == X.ButtonRelease:
                    done = True
                elif (ev.type == X.ClientMessage
                      and ev.client_type == moveresize
                      and ev.data[1][2] == CANCEL):
                    done = True
            if done or not root.query_pointer().mask & BUTTONS:
                break
            cx, cy = cursor()
            dx, dy = round(cx - cx0), round(cy - cy0)
            if direction == MOVE:
                geo = dict(x=x0 + dx, y=y0 + dy)
            else:
                left, top, right, bottom = EDGES[direction]
                x, y, w, h = x0, y0, w0, h0
                if left:
                    w = max(MIN_W, w0 - dx)
                    x = x0 + w0 - w
                if right:
                    w = max(MIN_W, w0 + dx)
                if top:
                    h = max(MIN_H, h0 - dy)
                    y = y0 + h0 - h
                if bottom:
                    h = max(MIN_H, h0 + dy)
                geo = dict(x=x, y=y, width=w, height=h)
            if geo != last:
                win.configure(**geo)
                d.flush()
                last = geo
            time.sleep(1 / 144)
    finally:
        d.ungrab_pointer(X.CurrentTime)
        d.flush()


def main():
    d = display.Display()
    root = d.screen().root
    moveresize = d.intern_atom("_NET_WM_MOVERESIZE")
    root.change_attributes(event_mask=X.SubstructureNotifyMask)
    restack(root)
    d.flush()
    while True:
        # Take a whole burst of events (a drag sends dozens), then
        # restack once.
        ev = d.next_event()
        dirty = False
        while True:
            if ev.type in RESTACK_ON:
                dirty = True
            elif ev.type == X.ClientMessage and ev.client_type == moveresize:
                direction = ev.data[1][2]
                if direction == MOVE or direction in EDGES:
                    try:
                        follow(d, ev.window, direction, moveresize)
                    except Exception as e:  # window gone mid-drag
                        print("moveresize:", e, flush=True)
                    dirty = True
            if not d.pending_events():
                break
            ev = d.next_event()
        if dirty:
            try:
                restack(root)
                d.flush()
            except Exception as e:  # a window vanished meanwhile
                print("restack:", e, flush=True)


if __name__ == "__main__":
    main()
