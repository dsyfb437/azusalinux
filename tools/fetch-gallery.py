#!/usr/bin/env python3
"""fetch-gallery — 从 Danbooru 抓图（自用）

默认只抓全年龄分级。要看别的分级就自己传 --rating，工具不替你决定，
但请确认你所在地区对此类内容的法规。

用法：
    ./tools/fetch-gallery.py                          # 全年龄、单人、横竖不限
    ./tools/fetch-gallery.py --rating general sensitive
    ./tools/fetch-gallery.py --rating general sensitive questionable explicit --limit 50
    ./tools/fetch-gallery.py --tag "azusa_(blue_archive)" --min-width 2000

输出到 out/ 目录，并写一份 manifest.json 记录 id / 尺寸 / 来源页。
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
import urllib.parse
from pathlib import Path

API = "https://danbooru.donmai.us/posts.json"
RATINGS = ("general", "sensitive", "questionable", "explicit")


def fetch(tag: str, rating: str, page: int, limit: int = 200) -> list[dict]:
    params = urllib.parse.urlencode({
        "tags": f"{tag} rating:{rating}",
        "limit": limit,
        "page": page,
    })
    proc = subprocess.run(["curl", "-s", "-m", "40", f"{API}?{params}"],
                          capture_output=True, text=True)
    try:
        data = json.loads(proc.stdout)
    except Exception:
        return []
    return data if isinstance(data, list) else []


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="按分级抓 Danbooru 图")
    ap.add_argument("--tag", default="azusa_(blue_archive) solo")
    ap.add_argument("--rating", nargs="+", default=["general", "sensitive"],
                    choices=RATINGS, help="默认 general sensitive")
    ap.add_argument("--pages", type=int, default=2)
    ap.add_argument("--limit", type=int, default=30, help="每个分级最多下载多少张")
    ap.add_argument("--min-width", type=int, default=1200)
    ap.add_argument("--out", default="out")
    args = ap.parse_args(argv)

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    manifest: list[dict] = []
    seen: set[int] = set()

    for rating in args.rating:
        taken = 0
        for page in range(1, args.pages + 1):
            posts = fetch(args.tag, rating, page)
            if not posts:
                break
            for p in posts:
                if taken >= args.limit:
                    break
                if p["id"] in seen:
                    continue
                if not p.get("image_width") or p["image_width"] < args.min_width:
                    continue
                if p.get("file_ext") in ("mp4", "webm", "zip"):
                    continue
                dest = out / f"{p['id']}_{p['image_width']}x{p['image_height']}.{p['file_ext']}"
                if not dest.exists():
                    subprocess.run(["curl", "-sL", "-m", "90", "-o", str(dest), p["file_url"]])
                    if dest.stat().st_size < 1024:
                        dest.unlink(missing_ok=True)
                        continue
                seen.add(p["id"])
                taken += 1
                manifest.append({
                    "id": p["id"],
                    "rating": rating,
                    "size": [p["image_width"], p["image_height"]],
                    "file": dest.name,
                    "page": f"https://danbooru.donmai.us/posts/{p['id']}",
                })
                print(f"  {rating:12} {dest.name}")
        print(f"  {rating}: {taken} 张")

    (out / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2))
    print(f"\n共 {len(manifest)} 张 → {out}/manifest.json")
    return 0


if __name__ == "__main__":
    sys.exit(main())
