"""Draws the gear the player wears, as overlays that line up pixel for pixel with
the player sheet (16x18 frames; rows are down, up, left, right). Each piece is
cut from the character's own silhouette, so a helmet hugs the head and armour
sits on the torso, never over the face. Output: assets/sprites/worn/<id>.png,
a 64x18 strip of the four facings. Run from the game folder."""
import pathlib
import sys

import numpy as np

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from pngio import read_png, write_png  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHEET = read_png(str(ROOT / "assets/sprites/player.png"))
W, H = 16, 18
FACINGS = ["down", "up", "left", "right"]
OUTLINE = (26, 18, 32, 255)


def hexc(code, alpha=255):
    code = code.lstrip("#")
    return tuple(int(code[i:i + 2], 16) for i in (0, 2, 4)) + (alpha,)


def silhouette(facing):
    row = FACINGS.index(facing)
    return SHEET[row * H:(row + 1) * H, 0:W, 3] > 0


def dilate(mask):
    out = mask.copy()
    out[1:, :] |= mask[:-1, :]
    out[:-1, :] |= mask[1:, :]
    out[:, 1:] |= mask[:, :-1]
    out[:, :-1] |= mask[:, 1:]
    return out


def rows(mask, top, bottom):
    out = np.zeros_like(mask)
    out[top:bottom + 1] = mask[top:bottom + 1]
    return out


def front(facing, x):
    """True for columns on the side the character faces (for visors)."""
    if facing == "right":
        return x >= 8
    if facing == "left":
        return x <= 7
    return True


class Canvas:
    def __init__(self):
        self.px = np.zeros((H, W, 4), np.uint8)
        self.shape = np.zeros((H, W), bool)

    def fill(self, mask, color):
        self.px[mask] = color
        self.shape |= mask

    def put(self, x, y, color):
        if 0 <= x < W and 0 <= y < H:
            self.px[y, x] = color
            self.shape[y, x] = True

    def outline(self):
        """Darkens the piece's own rim, so it reads clearly without growing wider than the body."""
        inner = self.shape.copy()
        inner[1:, :] &= self.shape[:-1, :]
        inner[:-1, :] &= self.shape[1:, :]
        inner[:, 1:] &= self.shape[:, :-1]
        inner[:, :-1] &= self.shape[:, 1:]
        rim = self.shape & ~inner
        self.px[rim, :3] = (self.px[rim, :3].astype(float) * 0.45 + np.array(OUTLINE[:3]) * 0.55).astype(np.uint8)


# ------------------------------------------------------------------ helmets

def dome(facing, bottom):
    """The crown of the head, one pixel taller, so a helmet sits on it."""
    head = rows(silhouette(facing), 0, bottom)
    lifted = head.copy()
    lifted[:-1] |= head[1:]
    return rows(lifted, 0, bottom)


def hard_hat(facing):
    c = Canvas()
    body = dome(facing, 5)
    c.fill(body, hexc("#f2c23a"))
    c.fill(rows(body, 5, 5), hexc("#c8961e"))
    xs = np.where(body[5])[0]
    # the brim sticks out one pixel more, and further forward in profile
    brim = np.zeros((H, W), bool)
    lo, hi = xs.min() - 1, xs.max() + 1
    if facing == "right":
        hi += 2
    if facing == "left":
        lo -= 2
    brim[6, max(lo, 0):min(hi, W - 1) + 1] = True
    c.fill(brim, hexc("#a87818"))
    for y in (1, 2, 3, 4):  # centre ridge
        ridge = 7 if facing in ("down", "up") else (6 if facing == "right" else 9)
        if body[y, ridge]:
            c.put(ridge, y, hexc("#ffe27a"))
    c.outline()
    top = np.where(body[2])[0]
    c.put(int(top.min()) + 1, 2, hexc("#fff4c0"))
    return c


def welding_mask(facing):
    c = Canvas()
    cap = dome(facing, 5)
    c.fill(cap, hexc("#7a7a8c"))
    c.fill(rows(cap, 1, 2), hexc("#9a9aac"))
    face = rows(silhouette(facing), 6, 11)
    if facing == "up":
        strap = rows(silhouette(facing), 7, 7)
        c.fill(strap, hexc("#4a3a30"))
    else:
        plate = np.zeros((H, W), bool)
        for y in range(6, 12):
            for x in range(W):
                if face[y, x] and front(facing, x):
                    plate[y, x] = True
        c.fill(plate, hexc("#6a6a7c"))
        for x in range(W):
            if plate[8, x]:
                c.put(x, 8, hexc("#1f3a2a"))
                c.put(x, 9, hexc("#2e5a3e"))
        xs = np.where(plate[8])[0]
        if len(xs):
            c.put(int(xs.min()) + 1, 8, hexc("#9be04a"))
    c.outline()
    return c


def crash_helmet(facing):
    c = Canvas()
    shell = dome(facing, 11)
    c.fill(shell, hexc("#c83c3c"))
    c.fill(rows(shell, 0, 2), hexc("#e05a50"))
    if facing == "up":
        for y in range(1, 11):
            if shell[y, 7]:
                c.put(7, y, hexc("#f4ead6"))
                c.put(8, y, hexc("#f4ead6"))
    else:
        for y in (7, 8, 9):
            for x in range(W):
                if shell[y, x] and front(facing, x) and silhouette(facing)[y, x]:
                    c.put(x, y, hexc("#1a2a3a"))
        xs = np.where(shell[7] & silhouette(facing))[0]
        if len(xs):
            near = int(xs.max()) - 1 if facing == "right" else int(xs.min()) + 1
            c.put(near, 7, hexc("#9fe8f0"))
            c.put(near + (1 if facing != "left" else -1), 7, hexc("#5fb0c8"))
    c.outline()
    return c


# ------------------------------------------------------------------ armour

def torso(facing, inset=0):
    """The chest (rows 12-15); `inset` trims columns from each side to leave the arms bare."""
    mask = rows(silhouette(facing), 12, 15)
    if inset:
        out = mask.copy()
        out[:, 1:] &= mask[:, :-1]
        out[:, :-1] &= mask[:, 1:]
        for _ in range(inset - 1):
            out2 = out.copy()
            out2[:, 1:] &= out[:, :-1]
            out2[:, :-1] &= out[:, 1:]
            out = out2
        return out
    return mask


def cloth_wrap(facing):
    c = Canvas()
    body = torso(facing, 1)
    c.fill(body, hexc("#c8a870"))
    for y in (13, 15):
        for x in range(W):
            if body[y, x]:
                c.put(x, y, hexc("#8a6a3c"))
    if facing in ("down", "up"):  # a sash across the chest
        for step, y in enumerate(range(12, 16)):
            x = 5 + step * 2
            if body[y, x]:
                c.put(x, y, hexc("#b04a3a"))
                c.put(x + 1, y, hexc("#b04a3a"))
    c.outline()
    return c


def tire_vest(facing):
    c = Canvas()
    body = torso(facing, 1)
    c.fill(body, hexc("#34343e"))
    for y in range(12, 16):
        for x in range(W):
            if body[y, x] and (x + y) % 3 == 0:
                c.put(x, y, hexc("#1c1c24"))
    c.fill(rows(body, 12, 12), hexc("#4a4a56"))
    c.outline()
    return c


def scrap_plate(facing):
    c = Canvas()
    body = torso(facing, 1)
    c.fill(body, hexc("#9a9aae"))
    c.fill(rows(body, 12, 12), hexc("#c8c8d8"))
    c.fill(rows(body, 15, 15), hexc("#6a6a7e"))
    pads = rows(silhouette(facing), 12, 13) & ~body
    c.fill(pads, hexc("#7a7a8e"))
    xs = np.where(body[13])[0]
    if len(xs):
        for x in (int(xs.min()), int(xs.max())):
            c.put(x, 14, hexc("#f4ead6"))
    c.outline()
    return c


def riot_jacket(facing):
    c = Canvas()
    body = torso(facing)
    c.fill(body, hexc("#3e6aa0"))
    c.fill(rows(body, 14, 14), hexc("#f08a24"))
    if facing == "down":
        for y in range(12, 16):
            c.put(7, y, hexc("#16243c"))
            c.put(8, y, hexc("#16243c"))
    c.fill(rows(body, 12, 12), hexc("#5a8ac0"))
    c.outline()
    return c


PIECES = {
    "hard_hat": hard_hat, "welding_mask": welding_mask, "crash_helmet": crash_helmet,
    "cloth_wrap": cloth_wrap, "tire_vest": tire_vest, "scrap_plate": scrap_plate, "riot_jacket": riot_jacket,
}


def main():
    out_dir = ROOT / "assets/sprites/worn"
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, draw in PIECES.items():
        strip = np.concatenate([draw(facing).px for facing in FACINGS], axis=1)
        write_png(str(out_dir / f"{name}.png"), strip)
    print(f"drew {len(PIECES)} worn pieces in {out_dir}")


if __name__ == "__main__":
    main()
