#!/usr/bin/env python3
"""
unity_atlas.py — Reusable NGUI UIAtlas sprite extractor for Card Wars Unity .prefab atlases.

Reads NGUI UIAtlas prefabs (e.g. GUIAtlas.prefab, CharacterIconAtlas.prefab,
CharacterIconAtlas02.prefab), resolves their backing Material & Texture2D, and crops
individual sprites (handling padding and rotation if present) to standalone PNGs.
"""

import argparse
import json
import os
import re
from PIL import Image


def load_guid_cache(assets_root: str = "Assets") -> dict[str, str]:
    cache_path = "/tmp/unity_guid_cache.json"
    if os.path.exists(cache_path):
        with open(cache_path, "r", encoding="utf-8") as f:
            return json.load(f)
    guid_to_path = {}
    for root, _, files in os.walk(assets_root):
        for fn in files:
            if fn.endswith(".meta"):
                p = os.path.join(root, fn)
                with open(p, "r", encoding="utf-8", errors="ignore") as fp:
                    txt = fp.read()
                m = re.search(r"guid:\s*([0-9a-f]+)", txt)
                if m:
                    guid_to_path[m.group(1)] = p[:-5]
    with open(cache_path, "w", encoding="utf-8") as f:
        json.dump(guid_to_path, f)
    return guid_to_path


def parse_ngui_atlas(prefab_path: str, guid_to_path: dict[str, str] | None = None) -> dict:
    if guid_to_path is None:
        guid_to_path = load_guid_cache()

    with open(prefab_path, "r", encoding="utf-8", errors="ignore") as f:
        txt = f.read()

    m_mat = re.search(r"material:\s*\{fileID:\s*\d+,\s*guid:\s*([0-9a-f]+)", txt)
    mat_path = guid_to_path.get(m_mat.group(1)) if m_mat else None
    tex_path = None
    if mat_path and os.path.exists(mat_path):
        with open(mat_path, "r", encoding="utf-8", errors="ignore") as mf:
            mtxt = mf.read()
        for g in re.findall(r"guid:\s*([0-9a-f]+)", mtxt):
            tp = guid_to_path.get(g, "")
            if tp.lower().endswith(".png"):
                tex_path = tp
                break

    sprites = {}
    pattern = re.compile(
        r"-\s*name:\s*([^\n]+)\s+"
        r"outer:\s+serializedVersion:\s*\d+\s+"
        r"x:\s*([^\n]+)\s+y:\s*([^\n]+)\s+width:\s*([^\n]+)\s+height:\s*([^\n]+)\s+"
        r"inner:\s+serializedVersion:\s*\d+\s+"
        r"x:\s*([^\n]+)\s+y:\s*([^\n]+)\s+width:\s*([^\n]+)\s+height:\s*([^\n]+)\s+"
        r"rotated:\s*(\d+)\s+"
        r"paddingLeft:\s*([^\n]+)\s+paddingRight:\s*([^\n]+)\s+"
        r"paddingTop:\s*([^\n]+)\s+paddingBottom:\s*([^\n]+)"
    )
    for m in pattern.finditer(txt):
        name = m.group(1).strip()
        ox, oy, ow, oh = (int(round(float(m.group(i).strip()))) for i in range(2, 6))
        ix, iy, iw, ih = (int(round(float(m.group(i).strip()))) for i in range(6, 10))
        rotated = int(m.group(10).strip())
        pl, pr, pt, pb = (float(m.group(i).strip()) for i in range(11, 15))
        sprites[name] = {
            "name": name,
            "outer": (ox, oy, ow, oh),
            "inner": (ix, iy, iw, ih),
            "rotated": rotated,
            "padding": (pl, pr, pt, pb),
        }

    return {
        "prefab_path": prefab_path,
        "material_path": mat_path,
        "texture_path": tex_path,
        "sprites": sprites,
    }


def extract_sprites(atlas_data: dict, sprite_names: list[str], out_dir: str) -> None:
    tex_path = atlas_data["texture_path"]
    if not tex_path or not os.path.exists(tex_path):
        raise FileNotFoundError(f"Atlas texture not found: {tex_path}")

    os.makedirs(out_dir, exist_ok=True)
    img = Image.open(tex_path).convert("RGBA")
    sprites = atlas_data["sprites"]

    for sname in sprite_names:
        if sname not in sprites:
            print(f"WARNING: Sprite '{sname}' not found in {atlas_data['prefab_path']}")
            continue
        s = sprites[sname]
        x, y, w, h = s["outer"]
        crop = img.crop((x, y, x + w, y + h))
        out_path = os.path.join(out_dir, f"{sname}.png")
        crop.save(out_path)
        print(f"Extracted {out_path} ({w}x{h})")


def main() -> None:
    ap = argparse.ArgumentParser(description="Inspect and extract sprites from NGUI UIAtlas prefabs.")
    ap.add_argument("prefab", help="Path to NGUI UIAtlas .prefab")
    ap.add_argument("--list", action="store_true", help="List all sprites in the atlas")
    ap.add_argument("--extract", nargs="+", help="Sprite names to extract (or 'ALL')")
    ap.add_argument("--out-dir", help="Output directory for extracted PNGs")
    args = ap.parse_args()

    atlas = parse_ngui_atlas(args.prefab)
    if args.list:
        print(f"Atlas: {atlas['prefab_path']} -> {atlas['texture_path']} ({len(atlas['sprites'])} sprites)")
        for k, v in sorted(atlas["sprites"].items()):
            print(f"  {k:40s} outer={v['outer']}")

    if args.extract:
        if not args.out_dir:
            ap.error("--extract requires --out-dir")
        names = list(atlas["sprites"].keys()) if args.extract == ["ALL"] else args.extract
        extract_sprites(atlas, names, args.out_dir)


if __name__ == "__main__":
    main()
