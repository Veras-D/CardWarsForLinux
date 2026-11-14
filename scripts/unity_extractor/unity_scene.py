#!/usr/bin/env python3
"""
unity_scene.py — Reusable parser & Godot Transform3D converter for AdventureTime.unity.

Usage examples:
  # Inspect a Transform ID and its full hierarchy with resolved asset GUIDs and Godot Transform3D:
  python3 scripts/unity_extractor/unity_scene.py --walk 6014

  # Compute the combined Godot Transform3D from a parent Transform ID to a child Transform ID:
  python3 scripts/unity_extractor/unity_scene.py --chain 6406 5088 --scale 0.005
"""

import argparse
import glob
import math
import re

SCENE_PATH = "Assets/Scene/_hirez/Scenes/AdventureTime.unity"

_objs = None
_guid_map = None


def load_scene(scene_path: str = SCENE_PATH) -> dict[int, tuple[int, str]]:
    global _objs
    if _objs is not None:
        return _objs
    with open(scene_path, "r", encoding="utf-8", errors="replace") as f:
        txt = f.read()
    parts = re.split(r"^--- !u!(\d+) &(\d+)\s*$", txt, flags=re.M)
    _objs = {}
    for i in range(1, len(parts), 3):
        _objs[int(parts[i + 1])] = (int(parts[i]), parts[i + 2])
    return _objs


def load_guid_map(assets_root: str = "Assets") -> dict[str, str]:
    global _guid_map
    if _guid_map is not None:
        return _guid_map
    _guid_map = {}
    for mf in glob.glob(f"{assets_root}/**/*.meta", recursive=True):
        with open(mf, "r", encoding="utf-8", errors="replace") as f:
            m = re.search(r"guid:\s*([0-9a-fA-F]+)", f.read())
            if m:
                _guid_map[m.group(1)] = mf[:-5]
    return _guid_map


def get_raw(file_id: int) -> str:
    objs = load_scene()
    return objs[file_id][1]


def get_transform(tid: int) -> dict:
    t = get_raw(tid)

    def vec(name: str) -> list[float]:
        m = re.search(name + r": \{([^}]+)\}", t)
        return [float(x.split(":")[1]) for x in m.group(1).split(",")]

    r = vec("m_LocalRotation")
    p = vec("m_LocalPosition")
    s = vec("m_LocalScale")
    father = int(re.search(r"m_Father: \{fileID: (-?\d+)\}", t).group(1))
    go = int(re.search(r"m_GameObject: \{fileID: (\d+)\}", t).group(1))
    go_txt = get_raw(go)
    name = re.search(r"m_Name: (.*)", go_txt).group(1).strip()
    act_m = re.search(r"m_IsActive: (\d+)", go_txt)
    active = int(act_m.group(1)) if act_m else 1

    children = []
    in_c = False
    for line in t.splitlines():
        if line.startswith("  m_Children:"):
            if "[]" in line:
                break
            in_c = True
            continue
        if in_c:
            if line.startswith("  - {fileID:"):
                cm = re.search(r"fileID: (\d+)", line)
                if cm:
                    children.append(int(cm.group(1)))
            else:
                break

    return {
        "id": tid,
        "go": go,
        "name": name,
        "active": active,
        "r": r,
        "p": p,
        "s": s,
        "father": father,
        "children": children,
    }


def mat_identity() -> list[list[float]]:
    return [[1.0 if i == j else 0.0 for j in range(4)] for i in range(4)]


def mat_mul(a: list[list[float]], b: list[list[float]]) -> list[list[float]]:
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def quat_to_mat(q: list[float]) -> list[list[float]]:
    x, y, z, w = q
    return [
        [1.0 - 2.0 * (y * y + z * z), 2.0 * (x * y - z * w), 2.0 * (x * z + y * w), 0.0],
        [2.0 * (x * y + z * w), 1.0 - 2.0 * (x * x + z * z), 2.0 * (y * z - x * w), 0.0],
        [2.0 * (x * z - y * w), 2.0 * (y * z + x * w), 1.0 - 2.0 * (x * x + y * y), 0.0],
        [0.0, 0.0, 0.0, 1.0],
    ]


def local_matrix_unity(d: dict) -> list[list[float]]:
    R = quat_to_mat(d["r"])
    s = d["s"]
    M = [[R[i][j] * (s[j] if j < 3 else 1.0) for j in range(4)] for i in range(4)]
    for i in range(3):
        M[i][3] = d["p"][i]
    return M


def unity_mat_to_godot(m: list[list[float]], pos_scale: float = 1.0) -> list[list[float]]:
    """Conjugate 4x4 Unity matrix by S_Z = diag(1, 1, -1) for Godot right-handed space."""
    sz = [1.0, 1.0, -1.0, 1.0]
    out = [[m[i][j] * sz[i] * sz[j] for j in range(4)] for i in range(4)]
    for i in range(3):
        out[i][3] *= pos_scale
    return out


def format_godot_transform3d(m_godot: list[list[float]]) -> str:
    """Format a 4x4 Godot matrix into a Godot Transform3D(...) string."""
    # Godot Transform3D(xx, yx, zx, xy, yy, zy, xz, yz, zz, ox, oy, oz)
    # where column 0 is (xx, xy, xz), column 1 is (yx, yy, yz), column 2 is (zx, zy, zz)
    vals = [
        m_godot[0][0], m_godot[0][1], m_godot[0][2],
        m_godot[1][0], m_godot[1][1], m_godot[1][2],
        m_godot[2][0], m_godot[2][1], m_godot[2][2],
        m_godot[0][3], m_godot[1][3], m_godot[2][3],
    ]
    return "Transform3D(" + ", ".join(f"{v:.6f}".rstrip("0").rstrip(".") if abs(v) >= 1e-6 else "0" for v in vals) + ")"


def chain_matrix_unity(stop_parent_id: int, child_id: int) -> list[list[float]]:
    """Multiply Unity local matrices from stop_parent_id (exclusive) down to child_id (inclusive)."""
    d = get_transform(child_id)
    if d["id"] == stop_parent_id:
        return mat_identity()
    return mat_mul(chain_matrix_unity(stop_parent_id, d["father"]), local_matrix_unity(d))


def resolve_guids_in_line(line: str) -> str:
    gmap = load_guid_map()
    for m in re.finditer(r"guid:\s*([0-9a-fA-F]+)", line):
        g = m.group(1)
        if g in gmap:
            line += f"  # -> {gmap[g]}"
    return line


def walk_hierarchy(tid: int, depth: int = 0) -> None:
    objs = load_scene()
    d = get_transform(tid)
    go_txt = get_raw(d["go"])
    m_godot = unity_mat_to_godot(local_matrix_unity(d))
    t3d_str = format_godot_transform3d(m_godot)
    p = [round(x, 4) for x in d["p"]]
    r = [round(x, 4) for x in d["r"]]
    s = [round(x, 4) for x in d["s"]]
    print("  " * depth + f"{tid} {d['name']} (GO {d['go']}, active={d['active']}) pos={p} rot={r} scale={s}")
    print("  " * (depth + 1) + f"Godot local: {t3d_str}")

    for line in go_txt.splitlines():
        if "fileID:" in line:
            cid = int(line.split("fileID:")[1].split("}")[0].strip())
            if cid != tid and cid in objs:
                ctype, ctxt = objs[cid]
                if ctype in (23, 33, 111, 114, 137):
                    print("  " * (depth + 1) + f"[Comp {ctype} &{cid}]")
                    for cl in ctxt.splitlines():
                        cl_s = cl.strip()
                        if any(k in cl_s for k in ["m_Mesh:", "m_Materials:", "guid:", "m_Animation:", "Animation", "m_Bones:", "- {fileID:"]):
                            print("  " * (depth + 2) + resolve_guids_in_line(cl_s))

    for child_id in d["children"]:
        walk_hierarchy(child_id, depth + 1)


def main() -> None:
    ap = argparse.ArgumentParser(description="Inspect AdventureTime.unity hierarchies and Godot Transform3D.")
    ap.add_argument("--walk", type=int, help="Walk and print the hierarchy starting at Transform fileID.")
    ap.add_argument("--chain", nargs=2, type=int, metavar=("STOP_PARENT_ID", "CHILD_ID"), help="Compute combined Transform3D between parent and child.")
    ap.add_argument("--scale", type=float, default=1.0, help="Position scale factor when using --chain (e.g., 0.0005 from 6478).")
    args = ap.parse_args()

    if args.walk is not None:
        walk_hierarchy(args.walk)
    if args.chain is not None:
        stop_id, child_id = args.chain
        m_u = chain_matrix_unity(stop_id, child_id)
        m_g = unity_mat_to_godot(m_u, pos_scale=args.scale)
        print(f"Combined Godot Transform3D from {stop_id} -> {child_id} (pos_scale={args.scale}):")
        print(" ", format_godot_transform3d(m_g))


if __name__ == "__main__":
    main()
