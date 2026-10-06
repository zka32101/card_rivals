"""白(#FFFFFF)背景のアイコン画像を、透過PNGにする。

使い方: python chroma_key.py [入力フォルダ(output)] [出力フォルダ] [サイズ(既定256)]
- 背景の色との距離で透明度を決め（境界はなめらかに）、にじんだマゼンタ色を抑える。
- 外周が背景色でつながっている部分だけを抜く（物体の内側のピンク系は残す）。
"""
import sys
from collections import deque
from pathlib import Path

from PIL import Image

KEY = (255, 255, 255)


def dist(p):
    return ((p[0] - KEY[0]) ** 2 + (p[1] - KEY[1]) ** 2 + (p[2] - KEY[2]) ** 2) ** 0.5


def key_out(im: Image.Image, lo=14.0, hi=46.0) -> Image.Image:
    im = im.convert("RGB")
    w, h = im.size
    px = im.load()
    # 外周から背景色に近い画素をたどって、背景として確定する
    bg = [[False] * w for _ in range(h)]
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if dist(px[x, y]) < hi and not bg[y][x]:
                bg[y][x] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if dist(px[x, y]) < hi and not bg[y][x]:
                bg[y][x] = True
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not bg[ny][nx] and dist(px[nx, ny]) < hi:
                bg[ny][nx] = True
                q.append((nx, ny))
    out = Image.new("RGBA", (w, h))
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if bg[y][x]:
                d = dist((r, g, b))
                a = 0 if d < lo else int(255 * (d - lo) / (hi - lo))
            else:
                a = 255
            if a < 255 and a > 0:
                # 縁の白いにじみを、背景との混ざりを戻して抑える
                af = a / 255.0
                r = max(0, min(255, int((r - 255 * (1 - af)) / af))) if af > 0.05 else r
                g = max(0, min(255, int((g - 255 * (1 - af)) / af))) if af > 0.05 else g
                b = max(0, min(255, int((b - 255 * (1 - af)) / af))) if af > 0.05 else b
            op[x, y] = (r, g, b, a)
    return out


def main():
    src = Path(sys.argv[1] if len(sys.argv) > 1 else "output")
    dst = Path(sys.argv[2] if len(sys.argv) > 2 else "keyed")
    size = int(sys.argv[3]) if len(sys.argv) > 3 else 256
    dst.mkdir(parents=True, exist_ok=True)
    for f in sorted(src.glob("*.png")):
        out = key_out(Image.open(f))
        bbox = out.getchannel("A").point(lambda v: 255 if v > 8 else 0).getbbox()
        if bbox:
            out = out.crop(bbox)
        side = max(out.size)
        canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        canvas.paste(out, ((side - out.width) // 2, (side - out.height) // 2))
        canvas = canvas.resize((size, size), Image.LANCZOS)
        canvas.save(dst / f.name, optimize=True)
        print("keyed:", f.name)


if __name__ == "__main__":
    main()
