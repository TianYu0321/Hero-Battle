from __future__ import annotations

from collections import deque
from pathlib import Path

import cv2
import numpy as np
from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
HERO_DIR = ROOT / "assets" / "characters" / "hero"


def load_rgba(path: Path) -> np.ndarray:
    return np.array(Image.open(path).convert("RGBA"))


def save_rgba(path: Path, rgba: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA").save(path)


def green_mask(rgb: np.ndarray) -> np.ndarray:
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    hue = hsv[:, :, 0]
    sat = hsv[:, :, 1]
    val = hsv[:, :, 2]
    r = rgb[:, :, 0].astype(np.float32)
    g = rgb[:, :, 1].astype(np.float32)
    b = rgb[:, :, 2].astype(np.float32)
    hsv_green = (hue >= 38) & (hue <= 92) & (sat > 55) & (val > 55)
    channel_green = (g > r * 1.22 + 18) & (g > b * 1.22 + 18) & (g > 95)
    return hsv_green | channel_green


def connected_to_border(mask: np.ndarray) -> np.ndarray:
    h, w = mask.shape
    out = np.zeros_like(mask, dtype=bool)
    q: deque[tuple[int, int]] = deque()

    def seed(x: int, y: int) -> None:
        if mask[y, x] and not out[y, x]:
            out[y, x] = True
            q.append((x, y))

    for x in range(w):
        seed(x, 0)
        seed(x, h - 1)
    for y in range(h):
        seed(0, y)
        seed(w - 1, y)

    while q:
        x, y = q.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and mask[ny, nx] and not out[ny, nx]:
                out[ny, nx] = True
                q.append((nx, ny))
    return out


def remove_green_screen(rgba: np.ndarray) -> np.ndarray:
    rgb = rgba[:, :, :3]
    # Green-screen generated sprites often leave interior green islands around
    # slash VFX, so remove the full chroma-key mask, not only border-connected
    # regions.
    bg = green_mask(rgb)
    bg = cv2.dilate(bg.astype(np.uint8), np.ones((3, 3), np.uint8), iterations=1).astype(bool)

    alpha = np.where(bg, 0, 255).astype(np.uint8)
    alpha = cv2.GaussianBlur(alpha, (0, 0), 1.1)
    out = rgba.copy()
    out[:, :, 3] = alpha
    return despill_green_edges(out)


def connected_components_touching(mask: np.ndarray, touch: np.ndarray, min_area: int = 1) -> np.ndarray:
    labels_count, labels, stats, _ = cv2.connectedComponentsWithStats(mask.astype(np.uint8), 8)
    keep = np.zeros_like(mask, dtype=bool)
    for label in range(1, labels_count):
        if stats[label, cv2.CC_STAT_AREA] < min_area:
            continue
        component = labels == label
        if np.any(component & touch):
            keep |= component
    return keep


def remove_checker_or_grabcut(rgba: np.ndarray) -> np.ndarray:
    rgb = rgba[:, :, :3]
    h, w = rgb.shape[:2]
    hsv = cv2.cvtColor(rgb, cv2.COLOR_RGB2HSV)
    hue, sat, val = hsv[:, :, 0], hsv[:, :, 1], hsv[:, :, 2]
    gold_effect = ((hue >= 12) & (hue <= 38) & (sat > 70) & (val > 120))
    blue_effect = ((hue >= 85) & (hue <= 112) & (sat > 65) & (val > 115))
    effect_touch = cv2.dilate(
        (gold_effect | blue_effect).astype(np.uint8),
        cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (9, 9)),
        iterations=1,
    ).astype(bool)
    white_effect = connected_components_touching((sat < 38) & (val > 232), effect_touch, min_area=18)

    # Some AI outputs bake the transparent checkerboard into RGB. Treat neutral,
    # border-connected gray as background while preserving bright spell light.
    gray_checker = sat < 68
    gray_checker = gray_checker & ~(gold_effect | blue_effect | white_effect)
    if gray_checker.mean() > 0.12:
        bg = connected_to_border(gray_checker)
        bg = cv2.dilate(bg.astype(np.uint8), np.ones((3, 3), np.uint8), iterations=1).astype(bool)
        alpha = np.where(bg, 0, 255).astype(np.uint8)
        alpha = cv2.GaussianBlur(alpha, (0, 0), 1.0)
        out = rgba.copy()
        out[:, :, 3] = alpha
        return clean_alpha_edges(out)

    corners = np.concatenate(
        [
            rgb[:80, :80].reshape(-1, 3),
            rgb[:80, -80:].reshape(-1, 3),
            rgb[-80:, :80].reshape(-1, 3),
            rgb[-80:, -80:].reshape(-1, 3),
        ],
        axis=0,
    )
    # Baked checkerboards and plain generated backgrounds usually cluster around corner colors.
    corner_dists = np.min(
        np.linalg.norm(rgb[:, :, None, :].astype(np.int16) - corners[:: max(1, len(corners) // 24)][None, None, :, :].astype(np.int16), axis=3),
        axis=2,
    )
    likely_bg = corner_dists < 26

    if likely_bg.mean() > 0.18:
        bg = connected_to_border(likely_bg)
        alpha = np.where(bg, 0, 255).astype(np.uint8)
        alpha = cv2.GaussianBlur(alpha, (0, 0), 1.0)
        out = rgba.copy()
        out[:, :, 3] = alpha
        return clean_alpha_edges(out)

    mask = np.zeros((h, w), np.uint8)
    rect = (int(w * 0.06), int(h * 0.04), int(w * 0.88), int(h * 0.92))
    bgd = np.zeros((1, 65), np.float64)
    fgd = np.zeros((1, 65), np.float64)
    cv2.grabCut(cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR), mask, rect, bgd, fgd, 5, cv2.GC_INIT_WITH_RECT)
    fg = (mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD)

    # Preserve combat effects that grabCut sometimes treats as background.
    fg = fg | gold_effect | blue_effect | white_effect

    alpha = np.where(fg, 255, 0).astype(np.uint8)
    alpha = cv2.GaussianBlur(alpha, (0, 0), 1.2)
    out = rgba.copy()
    out[:, :, 3] = alpha
    return clean_alpha_edges(out)


def despill_green_edges(rgba: np.ndarray) -> np.ndarray:
    out = rgba.copy()
    rgb = out[:, :, :3].astype(np.float32)
    a = out[:, :, 3]
    edge = (a > 0) & (a < 245)
    r, g, b = rgb[:, :, 0], rgb[:, :, 1], rgb[:, :, 2]
    spill = edge & (g > r * 1.12 + 8) & (g > b * 1.12 + 8)
    rgb[:, :, 1][spill] = np.maximum(r[spill], b[spill]) * 0.92
    out[:, :, :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out[:, :, 3][(a < 18) & green_mask(out[:, :, :3])] = 0
    return out


def clean_alpha_edges(rgba: np.ndarray) -> np.ndarray:
    out = despill_green_edges(rgba)
    a = out[:, :, 3]
    out[:, :, 3] = np.where(a < 8, 0, a)
    return out


def remove_background(path: Path) -> np.ndarray:
    rgba = load_rgba(path)
    alpha = rgba[:, :, 3]
    if np.any(alpha < 250):
        return clean_alpha_edges(rgba)
    if green_mask(rgba[:, :, :3]).mean() > 0.08:
        return remove_green_screen(rgba)
    return remove_checker_or_grabcut(rgba)


def content_bbox(rgba: np.ndarray, threshold: int = 16) -> tuple[int, int, int, int]:
    alpha = rgba[:, :, 3] > threshold
    ys, xs = np.where(alpha)
    if len(xs) == 0:
        return (0, 0, rgba.shape[1], rgba.shape[0])
    return (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)


def fit_to_canvas(rgba: np.ndarray, size: tuple[int, int], max_fill: float = 0.88, y_bias: float = 0.56) -> np.ndarray:
    canvas_w, canvas_h = size
    x0, y0, x1, y1 = content_bbox(rgba)
    crop = rgba[y0:y1, x0:x1]
    h, w = crop.shape[:2]
    scale = min((canvas_w * max_fill) / max(w, 1), (canvas_h * max_fill) / max(h, 1))
    new_w = max(1, int(w * scale))
    new_h = max(1, int(h * scale))
    resized = np.array(Image.fromarray(crop, "RGBA").resize((new_w, new_h), Image.Resampling.LANCZOS))

    canvas = np.zeros((canvas_h, canvas_w, 4), dtype=np.uint8)
    x = (canvas_w - new_w) // 2
    y = int(canvas_h * y_bias - new_h * 0.55)
    y = max(0, min(canvas_h - new_h, y))
    canvas[y : y + new_h, x : x + new_w] = resized
    return canvas


def process_shinobi() -> None:
    for path in (HERO_DIR / "shinobi").rglob("*.png"):
        if path.name.endswith(".import"):
            continue
        rgba = clean_alpha_edges(load_rgba(path))
        save_rgba(path, rgba)


def process_saber() -> None:
    saber = HERO_DIR / "saber"
    jobs = [
        (saber / "idle" / "saber_idle_01.png", saber / "idle" / "saber_idle_01.png", (600, 480), 0.88, 0.58),
        (saber / "hit" / "saber_hit_01.png", saber / "hit" / "saber_hit_01.png", (600, 480), 0.88, 0.58),
        (saber / "attack" / "Gemini_Generated_Image_p2554qp2554qp255.png", saber / "attack" / "saber_attack_01.png", (600, 480), 0.92, 0.58),
        (saber / "skill1" / "Gemini_Generated_Image_r1xqjbr1xqjbr1xq.png", saber / "skill1" / "saber_skill1_01-1.png", (600, 480), 0.92, 0.58),
        (saber / "skill1" / "Gemini_Generated_Image_82rqny82rqny82rq.png", saber / "skill1" / "saber_skill1_01-2.png", (600, 480), 0.92, 0.58),
        (saber / "skill1" / "Gemini_Generated_Image_82rqny82rqny82rq.png", saber / "skill1" / "saber_skill1_01-3.png", (1000, 480), 0.92, 0.58),
        (saber / "skill2" / "Gemini_Generated_Image_4m9dlg4m9dlg4m9d.png", saber / "skill2" / "saber_skill2_01.png", (600, 480), 0.82, 0.60),
        (saber / "skill2" / "Gemini_Generated_Image_4m9dlg4m9dlg4m9d.png", saber / "skill2" / "saber_skill2_02.png", (600, 480), 0.94, 0.60),
        (saber / "victory" / "Gemini_Generated_Image_b0fedtb0fedtb0fe.png", saber / "victory" / "saber_victory_01.png", (600, 480), 0.88, 0.58),
    ]
    for src, dst, canvas, fill, y_bias in jobs:
        rgba = remove_background(src)
        fitted = fit_to_canvas(rgba, canvas, fill, y_bias)
        save_rgba(dst, clean_alpha_edges(fitted))


def main() -> None:
    process_shinobi()
    process_saber()
    print("Processed shinobi edges and saber normalized action assets.")


if __name__ == "__main__":
    main()
