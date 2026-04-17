import platform
import tkinter as tk

WIDTH, HEIGHT = 480, 640
CORNER_RADIUS = 28
BG_TRANSPARENT = "#ab23ff"  # fake-transparent key color for Windows
CARD_COLOR = "#1e1e2e"
TEXT_COLOR = "#cdd6f4"


def make_frameless_transparent(root: tk.Tk) -> str:
    """Strip window chrome and make background transparent on any OS.

    Returns the background color the window/canvas should use.
    """
    system = platform.system()

    if system == "Darwin":
        # macOS: overrideredirect alone leaves the titlebar until the window
        # is re-mapped. withdraw -> overrideredirect -> deiconify fixes it,
        # and `-transparent` + systemTransparent gives true transparency.
        root.withdraw()
        root.overrideredirect(True)
        root.wm_attributes("-transparent", True)
        root.configure(bg="systemTransparent")
        root.after(10, root.deiconify)
        return "systemTransparent"

    if system == "Windows":
        # Windows: overrideredirect removes chrome. True per-pixel transparency
        # isn't supported, so we use a transparent color key.
        root.overrideredirect(True)
        root.configure(bg=BG_TRANSPARENT)
        root.wm_attributes("-transparentcolor", BG_TRANSPARENT)
        root.wm_attributes("-topmost", True)
        return BG_TRANSPARENT

    # Linux / other X11: overrideredirect + alpha works on most WMs.
    root.overrideredirect(True)
    root.wm_attributes("-alpha", 0.95)
    try:
        root.wm_attributes("-type", "splash")
    except tk.TclError:
        pass
    root.configure(bg=CARD_COLOR)
    return CARD_COLOR


def draw_rounded_rect(canvas: tk.Canvas, x0, y0, x1, y1, radius, fill):
    """Draw a smooth rounded rectangle using a single spline polygon."""
    points = [
        x0 + radius, y0,
        x1 - radius, y0,
        x1, y0,
        x1, y0 + radius,
        x1, y1 - radius,
        x1, y1,
        x1 - radius, y1,
        x0 + radius, y1,
        x0, y1,
        x0, y1 - radius,
        x0, y0 + radius,
        x0, y0,
    ]
    return canvas.create_polygon(points, smooth=True, splinesteps=36,
                                 fill=fill, outline="")


def main() -> None:
    root = tk.Tk()
    root.geometry(f"{WIDTH}x{HEIGHT}")
    root.resizable(False, False)

    bg = make_frameless_transparent(root)

    canvas = tk.Canvas(root, width=WIDTH, height=HEIGHT, bg=bg,
                       highlightthickness=0, borderwidth=0)
    canvas.pack(fill="both", expand=True)

    draw_rounded_rect(canvas, 0, 0, WIDTH, HEIGHT,
                      radius=CORNER_RADIUS, fill=CARD_COLOR)
    canvas.create_text(WIDTH // 2, HEIGHT // 2, text="Hello, world!",
                       font=("Arial", 28, "bold"), fill=TEXT_COLOR)

    # Drag to move
    drag = {"x": 0, "y": 0}

    def on_press(event):
        drag["x"] = event.x_root - root.winfo_x()
        drag["y"] = event.y_root - root.winfo_y()

    def on_drag(event):
        root.geometry(f"+{event.x_root - drag['x']}+{event.y_root - drag['y']}")

    canvas.bind("<ButtonPress-1>", on_press)
    canvas.bind("<B1-Motion>", on_drag)
    canvas.bind("<Double-Button-1>", lambda e: root.destroy())
    root.bind("<Escape>", lambda e: root.destroy())

    root.mainloop()


if __name__ == "__main__":
    main()
