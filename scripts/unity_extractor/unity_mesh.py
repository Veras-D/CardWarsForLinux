#!/usr/bin/env python3
"""
unity_mesh.py — Reusable binary mesh parser & Wavefront .obj exporter for Card Wars Unity .asset meshes.

Handles both:
  - Layout A: Separate vertex streams with 16-byte stream alignment
              (Stream 0 = 12B positions, Stream 1 at ((vc*12)+15)//16*16 = 8B UVs)
  - Layout B: Single 20-byte interleaved stream (<5f: x, y, z, u, v)
  - SkinnedMeshRenderer bindpose unbaking (v_bone = m_BindPose[b] * v_raw)
  - Left-handed Unity to Right-handed Godot reflection:
      v = (x, y, -z)
      vt = (u, v)      # Never flip 1 - v in .obj; Godot's .obj importer flips v automatically!
      f = (a, c, b)    # Reversed triangle winding to preserve outward normals & backface-culled outlines!

Usage examples:
  # Inspect mesh layout, bone counts, and rigid vs soft skinning:
  python3 scripts/unity_extractor/unity_mesh.py --info Assets/Mesh/Cards.asset

  # Export a static mesh to .obj:
  python3 scripts/unity_extractor/unity_mesh.py --export-static Assets/Mesh/SinglePlayer.asset \
      --out godot/assets/models/quests/SinglePlayer.obj

  # Export a rigid SkinnedMeshRenderer mesh into bone-local .obj submeshes:
  python3 scripts/unity_extractor/unity_mesh.py --export-skinned Assets/Mesh/Cards.asset \
      --out-dir godot/assets/models/quests \
      --bone-names Deck01 Deck02 Card01 Knife Card02 Card03 Card04 Card05
"""

import argparse
import os
import re
import struct


def parse_unity_mesh(asset_path: str) -> dict:
    with open(asset_path, "r", encoding="utf-8", errors="replace") as f:
        txt = f.read()

    vc = int(re.search(r"m_VertexCount:\s*(\d+)", txt).group(1))
    td = bytes.fromhex(re.search(r"_typelessdata:\s*([0-9a-fA-F]+)", txt).group(1))
    ib = bytes.fromhex(re.search(r"m_IndexBuffer:\s*([0-9a-fA-F]+)", txt).group(1))
    ntris = len(ib) // 6
    tris = [struct.unpack_from("<3H", ib, i * 6) for i in range(ntris)]

    # Detect UV0 channel stream & offset from m_Channels[3]
    ch_pos = txt.find("m_Channels:")
    ch_sub = txt[ch_pos : txt.find("m_DataSize:", ch_pos)] if ch_pos >= 0 else ""
    ch_matches = re.findall(
        r"stream:\s*(\d+)\s+offset:\s*(\d+)\s+format:\s*(\d+)\s+dimension:\s*(\d+)",
        ch_sub,
    )
    uv_stream = 1
    uv_chan_offset = 0
    s0_stride_from_ch = 0
    if len(ch_matches) >= 4:
        uv_stream = int(ch_matches[3][0])
        uv_chan_offset = int(ch_matches[3][1])
        for st_s, off_s, fmt_s, dim_s in ch_matches:
            st, off, fmt, dim = int(st_s), int(off_s), int(fmt_s), int(dim_s)
            if st == 0 and dim > 0:
                bsize = 4 if fmt == 0 else (2 if fmt == 1 else 1)
                s0_stride_from_ch = max(s0_stride_from_ch, off + dim * bsize)

    if uv_stream == 0 and s0_stride_from_ch > 0 and len(td) == vc * s0_stride_from_ch:
        layout = f"Layout B (Interleaved {s0_stride_from_ch}B/vert in Stream 0, uv_offset={uv_chan_offset})"
        verts = []
        uvs = []
        for i in range(vc):
            base = i * s0_stride_from_ch
            x, y, z = struct.unpack_from("<3f", td, base)
            u, v = struct.unpack_from("<2f", td, base + uv_chan_offset)
            verts.append((x, y, z))
            uvs.append((u, v))
    else:
        stride_s0 = s0_stride_from_ch if s0_stride_from_ch > 0 else 12
        uv_off = ((vc * stride_s0) + 15) // 16 * 16
        if len(td) != uv_off + vc * 8:
            rem = len(td) - vc * 8
            stride_s0 = (rem // vc // 4) * 4
            uv_off = ((vc * stride_s0) + 15) // 16 * 16
        layout = f"Layout A (Separate Streams, s0_stride={stride_s0}B, uv_offset={uv_off})"
        verts = [struct.unpack_from("<3f", td, i * stride_s0) for i in range(vc)]
        uvs = [struct.unpack_from("<2f", td, uv_off + i * 8) for i in range(vc)]

    # Parse m_BindPose if present
    bps = []
    if "  m_BindPose:" in txt and "  m_BoneNameHashes:" in txt:
        bp_sub = txt[txt.index("  m_BindPose:") : txt.index("  m_BoneNameHashes:")]
        mats = re.findall(r"e(\d)(\d): ([-0-9.eE+]+)", bp_sub)
        for b in range(len(mats) // 16):
            m = [[0.0] * 4 for _ in range(4)]
            for r, c, val in mats[b * 16 : (b + 1) * 16]:
                m[int(r)][int(c)] = float(val)
            bps.append(m)

    # Parse m_Skin if present
    weights = []
    bone_indices = []
    if "  m_Skin:" in txt and "  m_VertexData:" in txt:
        sk_sub = txt[txt.index("  m_Skin:") : txt.index("  m_VertexData:")]
        w_all = [float(x) for x in re.findall(r"weight\[\d\]: ([-0-9.eE+]+)", sk_sub)]
        bi_all = [int(x) for x in re.findall(r"boneIndex\[\d\]: (\d+)", sk_sub)]
        weights = [w_all[i : i + 4] for i in range(0, len(w_all), 4)]
        bone_indices = [bi_all[i : i + 4] for i in range(0, len(bi_all), 4)]

    return {
        "path": asset_path,
        "vc": vc,
        "verts": verts,
        "uvs": uvs,
        "tris": tris,
        "layout": layout,
        "bps": bps,
        "weights": weights,
        "bone_indices": bone_indices,
    }


def write_obj(out_path: str, obj_name: str, verts: list[tuple[float, float, float]], uvs: list[tuple[float, float]], tris: list[tuple[int, int, int]]) -> None:
    os.makedirs(os.path.dirname(os.path.abspath(out_path)), exist_ok=True)
    lines = [f"# {obj_name} (Godot Z-reflected)", f"o {obj_name}"]
    for vx, vy, vz in verts:
        lines.append(f"v {vx:.6f} {vy:.6f} {-vz:.6f}")
    for u, v in uvs:
        lines.append(f"vt {u:.6f} {v:.6f}")
    for a, b, c in tris:
        lines.append(f"f {a + 1}/{a + 1} {c + 1}/{c + 1} {b + 1}/{b + 1}")
    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    print(f"Exported {out_path} ({len(verts)} verts, {len(tris)} tris)")


def export_skinned_by_bone(mesh_data: dict, out_dir: str, bone_names: list[str] | None = None) -> None:
    verts = mesh_data["verts"]
    uvs = mesh_data["uvs"]
    tris = mesh_data["tris"]
    bps = mesh_data["bps"]
    bi = mesh_data["bone_indices"]
    nbones = len(bps)

    if bone_names and len(bone_names) != nbones:
        raise ValueError(f"Provided {len(bone_names)} bone names, but mesh has {nbones} bindposes.")

    for b in range(nbones):
        bname = bone_names[b] if bone_names else f"Bone_{b:02d}"
        bp = bps[b]
        b_tris = [t for t in tris if bi[t[0]][0] == b]
        if not b_tris:
            print(f"Skipping bone {b} ({bname}): 0 triangles")
            continue

        used_v = sorted({idx for t in b_tris for idx in t})
        remap = {old_i: new_i for new_i, old_i in enumerate(used_v)}
        b_verts = []
        b_uvs = []
        for old_i in used_v:
            vx, vy, vz = verts[old_i]
            lx = bp[0][0] * vx + bp[0][1] * vy + bp[0][2] * vz + bp[0][3]
            ly = bp[1][0] * vx + bp[1][1] * vy + bp[1][2] * vz + bp[1][3]
            lz = bp[2][0] * vx + bp[2][1] * vy + bp[2][2] * vz + bp[2][3]
            b_verts.append((lx, ly, lz))
            b_uvs.append(uvs[old_i])
        remapped_tris = [(remap[a], remap[b_], remap[c]) for a, b_, c in b_tris]
        out_path = os.path.join(out_dir, f"{bname}.obj")
        write_obj(out_path, bname, b_verts, b_uvs, remapped_tris)


def main() -> None:
    ap = argparse.ArgumentParser(description="Inspect and export Card Wars Unity .asset meshes to Godot .obj.")
    ap.add_argument("--info", metavar="ASSET_PATH", help="Print detailed mesh layout & skinning info.")
    ap.add_argument("--export-static", metavar="ASSET_PATH", help="Export a static mesh to --out .obj.")
    ap.add_argument("--out", metavar="OBJ_PATH", help="Output .obj path for --export-static.")
    ap.add_argument("--export-skinned", metavar="ASSET_PATH", help="Export rigid SkinnedMeshRenderer submeshes to --out-dir.")
    ap.add_argument("--out-dir", metavar="DIR_PATH", help="Output directory for --export-skinned.")
    ap.add_argument("--bone-names", nargs="+", help="Optional bone names (in m_Bones order) for --export-skinned.")
    args = ap.parse_args()

    if args.info:
        d = parse_unity_mesh(args.info)
        w = d["weights"]
        soft = sum(1 for wk in w if wk[1] > 0.0001)
        max_w1 = max((wk[1] for wk in w), default=0.0)
        print(f"Mesh: {d['path']}")
        print(f"  Layout:     {d['layout']}")
        print(f"  Vertices:   {d['vc']}")
        print(f"  Triangles:  {len(d['tris'])}")
        print(f"  Bindposes:  {len(d['bps'])}")
        print(f"  Soft Verts: {soft} (max weight[1] = {max_w1:.4f})")
        if d["bps"] and d["bone_indices"]:
            bi = d["bone_indices"]
            for b in range(len(d["bps"])):
                cnt = sum(1 for t in d["tris"] if bi[t[0]][0] == b)
                print(f"    Bone {b:2d}: {cnt:4d} tris")

    if args.export_static:
        if not args.out:
            ap.error("--export-static requires --out")
        d = parse_unity_mesh(args.export_static)
        obj_name = os.path.splitext(os.path.basename(args.out))[0]
        write_obj(args.out, obj_name, d["verts"], d["uvs"], d["tris"])

    if args.export_skinned:
        if not args.out_dir:
            ap.error("--export-skinned requires --out-dir")
        d = parse_unity_mesh(args.export_skinned)
        export_skinned_by_bone(d, args.out_dir, args.bone_names)


if __name__ == "__main__":
    main()
