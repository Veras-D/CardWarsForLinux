#!/usr/bin/env python3
"""
export_battle_meshes.py — Batch extract 3D meshes & diffuse textures for Card Wars combat:
  - Landscapes: Assets/PrefabInstance/Land_{Corn,Plain,Cotton,Sand,Swamp}{1..4}.prefab
  - Summons:    db_Creatures.json ObjectName -> Assets/Resources/summons/<ObjectName>.prefab
  - Buildings:  db_Buildings.json ObjectName -> Assets/Resources/building/<ObjectName>.prefab

Outputs:
  - godot/assets/models/battle/landscapes/*.obj
  - godot/assets/models/battle/summons/*.glb
  - godot/assets/models/battle/buildings/*.glb
  - godot/assets/models/battle/textures/*.png
  - godot/assets/audio/sfx/*.wav (SummonScript SpawnAudio)
  - godot/assets/textures/fx/*.png (Summon / Building FX textures)
  - godot/data/battle_meshes.json
"""

import glob
import json
import os
import re
import shutil
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
sys.path.insert(0, SCRIPT_DIR)

from unity_glb import build_guid_index as build_glb_guid_index
from unity_glb import _parse_unity_yaml_objects, export_unity_subtree_to_glb
from unity_mesh import parse_unity_mesh, write_obj

GODOT_DATA = os.path.join(REPO_ROOT, "godot", "data")
OUT_BASE = os.path.join(REPO_ROOT, "godot", "assets", "models", "battle")
OUT_LAND = os.path.join(OUT_BASE, "landscapes")
OUT_SUMMON = os.path.join(OUT_BASE, "summons")
OUT_BUILD = os.path.join(OUT_BASE, "buildings")
OUT_TEX = os.path.join(OUT_BASE, "textures")
OUT_SFX = os.path.join(REPO_ROOT, "godot", "assets", "audio", "sfx")
OUT_FX_TEX = os.path.join(REPO_ROOT, "godot", "assets", "textures", "fx")

SKIP_MESH_TOKENS = ("outline", "0utline", "shadow", "blast", "halo", "alpha", "facez_")


def build_guid_index() -> dict[str, str]:
    idx: dict[str, str] = {}
    assets_root = os.path.join(REPO_ROOT, "Assets")
    for meta in glob.glob(os.path.join(assets_root, "**", "*.meta"), recursive=True):
        with open(meta, "r", encoding="utf-8", errors="replace") as f:
            txt = f.read(512)
        m = re.search(r"guid:\s*([0-9a-fA-F]+)", txt)
        if m:
            idx[m.group(1)] = meta[:-5]
    return idx


def _parse_vec3(block: str, field: str, default: tuple[float, float, float]) -> tuple[float, float, float]:
    m = re.search(rf"{field}:\s*\{{x:\s*([-0-9.eE+]+),\s*y:\s*([-0-9.eE+]+),\s*z:\s*([-0-9.eE+]+)\}}", block)
    if not m:
        return default
    return (float(m.group(1)), float(m.group(2)), float(m.group(3)))


def _parse_quat(block: str, field: str) -> tuple[float, float, float, float]:
    m = re.search(rf"{field}:\s*\{{x:\s*([-0-9.eE+]+),\s*y:\s*([-0-9.eE+]+),\s*z:\s*([-0-9.eE+]+),\s*w:\s*([-0-9.eE+]+)\}}", block)
    if not m:
        return (0.0, 0.0, 0.0, 1.0)
    return (float(m.group(1)), float(m.group(2)), float(m.group(3)), float(m.group(4)))


def _rot_quat(v: tuple[float, float, float], q: tuple[float, float, float, float]) -> tuple[float, float, float]:
    qx, qy, qz, qw = q
    vx, vy, vz = v
    tx = 2.0 * (qy * vz - qz * vy)
    ty = 2.0 * (qz * vx - qx * vz)
    tz = 2.0 * (qx * vy - qy * vx)
    return (
        vx + qw * tx + (qy * tz - qz * ty),
        vy + qw * ty + (qz * tx - qx * tz),
        vz + qw * tz + (qx * ty - qy * tx),
    )


def _apply_transform(v: tuple[float, float, float], tr: dict) -> tuple[float, float, float]:
    sx, sy, sz = tr["scale"]
    vs = (v[0] * sx, v[1] * sy, v[2] * sz)
    vr = _rot_quat(vs, tr["rot"])
    px, py, pz = tr["pos"]
    return (vr[0] + px, vr[1] + py, vr[2] + pz)


def parse_prefab_components(prefab_path: str, guid_index: dict[str, str]) -> dict:
    with open(prefab_path, "r", encoding="utf-8", errors="replace") as f:
        txt = f.read()

    game_objects: dict[str, str] = {}
    transforms_by_id: dict[str, dict] = {}
    transforms_by_go: dict[str, dict] = {}
    mesh_renderers_by_go: dict[str, list[str]] = {}
    candidates: list[dict] = []

    blocks = txt.split("--- !u!")
    for blk in blocks[1:]:
        hdr_end = blk.find("\n")
        if hdr_end < 0:
            continue
        hdr = blk[:hdr_end]
        m_hdr = re.match(r"(\d+)\s+&(\d+)", hdr)
        if not m_hdr:
            continue
        cid, fid = m_hdr.group(1), m_hdr.group(2)

        if cid == "1":
            m_name = re.search(r"m_Name:\s*(.+)", blk)
            game_objects[fid] = m_name.group(1).strip() if m_name else ""
        elif cid == "4":
            m_go = re.search(r"m_GameObject:\s*\{fileID:\s*(\d+)\}", blk)
            m_f = re.search(r"m_Father:\s*\{fileID:\s*(\d+)\}", blk)
            if m_go:
                tr = {
                    "id": fid,
                    "go": m_go.group(1),
                    "father": m_f.group(1) if m_f else "0",
                    "pos": _parse_vec3(blk, "m_LocalPosition", (0.0, 0.0, 0.0)),
                    "rot": _parse_quat(blk, "m_LocalRotation"),
                    "scale": _parse_vec3(blk, "m_LocalScale", (1.0, 1.0, 1.0)),
                }
                transforms_by_id[fid] = tr
                transforms_by_go[tr["go"]] = tr
        elif cid == "23":
            m_go = re.search(r"m_GameObject:\s*\{fileID:\s*(\d+)\}", blk)
            if m_go:
                mats = re.findall(r"-\s*\{fileID:\s*\d+,\s*guid:\s*([0-9a-fA-F]+)", blk)
                mesh_renderers_by_go[m_go.group(1)] = [guid_index.get(g, "") for g in mats if g in guid_index]
        elif cid in ("33", "137"):
            m_go = re.search(r"m_GameObject:\s*\{fileID:\s*(\d+)\}", blk)
            m_mesh = re.search(r"m_Mesh:\s*\{[^}]*guid:\s*([0-9a-fA-F]+)", blk)
            if m_go and m_mesh and m_mesh.group(1) in guid_index:
                mats = []
                if cid == "137":
                    mats = [guid_index.get(g, "") for g in re.findall(r"-\s*\{fileID:\s*\d+,\s*guid:\s*([0-9a-fA-F]+)", blk) if g in guid_index]
                candidates.append({
                    "cid": cid,
                    "go": m_go.group(1),
                    "mesh_path": guid_index[m_mesh.group(1)],
                    "mats": mats,
                })

    # Pair MeshFilter materials from sibling MeshRenderer
    for c in candidates:
        if not c["mats"] and c["go"] in mesh_renderers_by_go:
            c["mats"] = mesh_renderers_by_go[c["go"]]
        c["go_name"] = game_objects.get(c["go"], "")

        # Resolve Transform chain to prefab root
        chain = []
        tr = transforms_by_go.get(c["go"])
        while tr:
            chain.append(tr)
            fid = tr.get("father", "0")
            tr = transforms_by_id.get(fid) if fid != "0" else None
        c["chain"] = chain  # child -> ... -> root

    return {"candidates": candidates}


def resolve_material_texture(mat_path: str, guid_index: dict[str, str]) -> str:
    if not mat_path or not os.path.exists(mat_path):
        return ""
    with open(mat_path, "r", encoding="utf-8", errors="replace") as f:
        txt = f.read()
    m = re.search(r"_MainTex:[\s\S]{0,200}?guid:\s*([0-9a-fA-F]+)", txt)
    if not m:
        return ""
    tex_path = guid_index.get(m.group(1), "")
    if not tex_path or not os.path.exists(tex_path):
        return ""
    bname = os.path.basename(tex_path)
    if bname.startswith("low_"):
        hires = os.path.join(os.path.dirname(tex_path), bname[4:])
        if os.path.exists(hires):
            return hires
    return tex_path


def copy_texture(src_tex: str) -> str:
    if not src_tex or not os.path.exists(src_tex):
        return ""
    os.makedirs(OUT_TEX, exist_ok=True)
    bname = os.path.basename(src_tex)
    dst = os.path.join(OUT_TEX, bname)
    if not os.path.exists(dst):
        shutil.copy2(src_tex, dst)
    return f"res://assets/models/battle/textures/{bname}"


def choose_primary_candidate(candidates: list[dict], target_name: str) -> dict | None:
    filtered = []
    for c in candidates:
        mesh_base = os.path.splitext(os.path.basename(c["mesh_path"]))[0].lower()
        go_low = c["go_name"].lower()
        if any(tok in mesh_base or tok in go_low for tok in SKIP_MESH_TOKENS):
            continue
        if not c["mesh_path"].endswith(".asset"):
            continue
        filtered.append(c)

    if not filtered:
        # Relax filter slightly (allow alpha if nothing else)
        for c in candidates:
            mesh_base = os.path.splitext(os.path.basename(c["mesh_path"]))[0].lower()
            if "outline" in mesh_base or "0utline" in mesh_base or not c["mesh_path"].endswith(".asset"):
                continue
            filtered.append(c)

    if not filtered:
        return None
    if len(filtered) == 1:
        return filtered[0]

    t_low = target_name.lower()
    best = None
    best_score = (-1, -1)
    for c in filtered:
        mesh_base = os.path.splitext(os.path.basename(c["mesh_path"]))[0].lower()
        go_low = c["go_name"].lower()
        name_score = 3 if mesh_base == t_low else (2 if t_low in mesh_base or mesh_base in t_low or t_low in go_low else (1 if "shadow" not in go_low else 0))
        d = parse_unity_mesh(c["mesh_path"])
        score = (name_score, len(d["tris"]))
        if score > best_score:
            best_score = score
            best = c
    return best


def export_candidate(cand: dict, out_obj_path: str, guid_index: dict[str, str], is_landscape: bool = False) -> tuple[bool, str]:
    mesh_data = parse_unity_mesh(cand["mesh_path"])
    verts = mesh_data["verts"]
    uvs = mesh_data["uvs"]
    tris = mesh_data["tris"]
    if not verts or not tris:
        return False, ""

    # Apply prefab hierarchy transforms (child -> root)
    xformed = []
    det_sign = 1
    for tr in cand["chain"]:
        sx, sy, sz = tr["scale"]
        if sx * sy * sz < 0:
            det_sign *= -1
    for v in verts:
        p = v
        for tr in cand["chain"]:
            if is_landscape and tr.get("father") == "0":
                # Unity's LandscapeManagerScript overwrites the instantiated prefab root's localPosition to Vector3.zero.
                root_tr = {"scale": tr["scale"], "rot": tr["rot"], "pos": (0.0, 0.0, 0.0)}
                p = _apply_transform(p, root_tr)
            else:
                p = _apply_transform(p, tr)
        xformed.append(p)

    # All Land_* prefabs (slabs and foliage/rocks/trees props) sit under P1Lane*mass which applies -90 deg around X in BattleScene.unity
    if is_landscape:
        rot_x_m90 = (-0.70710678, 0.0, 0.0, 0.70710678)
        xformed = [_rot_quat(p, rot_x_m90) for p in xformed]
    else:
        # Fallback: if prefab had identity rotation on a raw Maya Z-up mesh and SkinnedMeshRenderer had no -90X, check ratio
        # Wait: check if none of the chain had rotation and mesh Z range looks vertical
        has_rot = any(abs(tr["rot"][0]) > 0.1 or abs(tr["rot"][1]) > 0.1 or abs(tr["rot"][2]) > 0.1 for tr in cand["chain"])
        if not has_rot and cand["cid"] == "137":
            rot_x_m90 = (-0.70710678, 0.0, 0.0, 0.70710678)
            xformed = [_rot_quat(p, rot_x_m90) for p in xformed]

    if det_sign < 0:
        tris = [(a, c, b) for a, b, c in tris]

    obj_name = os.path.splitext(os.path.basename(out_obj_path))[0]
    write_obj(out_obj_path, obj_name, xformed, uvs, tris)

    tex_res = ""
    for mat in cand["mats"]:
        src_tex = resolve_material_texture(mat, guid_index)
        if src_tex:
            tex_res = copy_texture(src_tex)
            break
    return True, tex_res


def find_prefab_case_insensitive(directory: str, obj_name: str) -> str:
    exact = os.path.join(directory, f"{obj_name}.prefab")
    if os.path.exists(exact):
        return exact
    low_target = f"{obj_name}.prefab".lower()
    for fn in os.listdir(directory):
        if fn.lower() == low_target and not fn.lower().startswith("low_"):
            return os.path.join(directory, fn)
    return ""


def export_landscapes(manifest: dict, guid_index: dict[str, str]) -> None:
    os.makedirs(OUT_LAND, exist_ok=True)
    for faction in ("Corn", "Plain", "Cotton", "Sand", "Swamp"):
        entries = []
        for idx in (1, 2, 3, 4):
            pref = os.path.join(REPO_ROOT, "Assets", "PrefabInstance", f"Land_{faction}{idx}.prefab")
            if not os.path.exists(pref):
                continue
            parsed = parse_prefab_components(pref, guid_index)
            cand = choose_primary_candidate(parsed["candidates"], f"{faction}{idx}")
            if not cand:
                continue
            out_name = f"Land_{faction}{idx}.obj"
            ok, tex_res = export_candidate(cand, os.path.join(OUT_LAND, out_name), guid_index, is_landscape=True)
            if ok:
                entry = {
                    "mesh": f"res://assets/models/battle/landscapes/{out_name}",
                    "texture": tex_res,
                }
                detail_cands = [c for c in parsed["candidates"] if c is not cand and c["mesh_path"].endswith(".asset")]
                if detail_cands:
                    detail_cand = detail_cands[0]
                    detail_out = f"Land_{faction}{idx}_Props.obj"
                    d_ok, d_tex = export_candidate(detail_cand, os.path.join(OUT_LAND, detail_out), guid_index, is_landscape=True)
                    if d_ok:
                        entry["detail_mesh"] = f"res://assets/models/battle/landscapes/{detail_out}"
                        entry["detail_texture"] = d_tex or "res://assets/models/battle/textures/Landscape_Props.png"
                entries.append(entry)
        manifest["landscapes"][faction] = entries
    if "Plain" in manifest["landscapes"]:
        manifest["landscapes"]["Plains"] = manifest["landscapes"]["Plain"]


def main() -> None:
    landscapes_only = "--landscapes-only" in sys.argv[1:]
    print("Indexing Unity GUIDs...")
    guid_index = build_guid_index()
    print(f"Indexed {len(guid_index)} GUIDs.")

    manifest_path = os.path.join(GODOT_DATA, "battle_meshes.json")
    if landscapes_only and os.path.exists(manifest_path):
        with open(manifest_path, "r", encoding="utf-8") as f:
            manifest = json.load(f)
        manifest["landscapes"] = {}
    else:
        manifest = {
            "landscapes": {},
            "summons": {},
            "buildings": {},
        }

    # 1. Landscapes
    export_landscapes(manifest, guid_index)

    if landscapes_only:
        with open(manifest_path, "w", encoding="utf-8") as f:
            json.dump(manifest, f, indent=2)
        print(f"Done (landscapes only)! Landscapes={sum(len(v) for k, v in manifest['landscapes'].items() if k != 'Plains')}")
        return

    # 2. Creatures / Summons (animated GLBs + SummonScript metadata)
    os.makedirs(OUT_SUMMON, exist_ok=True)
    creatures_json = os.path.join(GODOT_DATA, "db_Creatures.json")
    summon_dir = os.path.join(REPO_ROOT, "Assets", "Resources", "summons")
    with open(creatures_json, "r", encoding="utf-8") as f:
        creatures = json.load(f)
    obj_names_c = sorted({str(r.get("ObjectName", "")).strip() for r in creatures if isinstance(r, dict) and r.get("ObjectName")})
    _export_entity_group("summons", summon_dir, OUT_SUMMON, obj_names_c, manifest["summons"], guid_index)

    # 3. Buildings (animated GLBs + SummonScript metadata)
    os.makedirs(OUT_BUILD, exist_ok=True)
    buildings_json = os.path.join(GODOT_DATA, "db_Buildings.json")
    build_dir = os.path.join(REPO_ROOT, "Assets", "Resources", "building")
    with open(buildings_json, "r", encoding="utf-8") as f:
        buildings = json.load(f)
    obj_names_b = sorted({str(r.get("ObjectName", "")).strip() for r in buildings if isinstance(r, dict) and r.get("ObjectName")})
    _export_entity_group("buildings", build_dir, OUT_BUILD, obj_names_b, manifest["buildings"], guid_index)

    # 4. Copy original Summon/Building VFX textures if present in Unity Assets/Texture2D
    os.makedirs(OUT_FX_TEX, exist_ok=True)
    for fx_tex in (
        "FX_Scan_Hex_Outline.png",
        "FX_BurstBubble_NoGlow_PNG.png",
        "FX_Scan.png",
        "FX_Flare3_TGA.png",
        "FX_Battle_ExclamationMark_PNG.png",
        "FX_Land_HighlightA_PNG.png",
        "FX_Land_HighlightB_PNG.png",
        "FX_Land_HighlightC_PNG.png",
        "FX_Land_HighlightD_PNG.png",
        "FX_StarBurst4_PNG.png",
        "FX_Skull2_PNG.png",
    ):
        src_fx = os.path.join(REPO_ROOT, "Assets", "Texture2D", fx_tex)
        dst_fx = os.path.join(OUT_FX_TEX, fx_tex)
        if os.path.exists(src_fx) and not os.path.exists(dst_fx):
            shutil.copy2(src_fx, dst_fx)

    manifest_path = os.path.join(GODOT_DATA, "battle_meshes.json")
    with open(manifest_path, "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
    print(f"Done! Landscapes={sum(len(v) for k, v in manifest['landscapes'].items() if k != 'Plains')}, Summons={len(manifest['summons'])}, Buildings={len(manifest['buildings'])}")
    print(f"Manifest written to {manifest_path}")


def _extract_summon_meta(prefab_path: str, guid_index: dict[str, str], is_building: bool) -> dict:
    with open(prefab_path, "r", encoding="utf-8", errors="replace") as f:
        txt = f.read()
    _, comp_map, _, _ = _parse_unity_yaml_objects(txt)
    meta: dict = {
        "intro": "",
        "idle": "",
        "intro_length": 2.0 if is_building else 1.5,
        "ambient": "",
        "spawn_audio": "",
        "spawn_audio_delay": 0.0,
    }
    os.makedirs(OUT_SFX, exist_ok=True)
    all_clips: list[str] = []
    play_auto_clips: list[str] = []
    for _, (ctype, blk) in comp_map.items():
        if ctype == "111":
            m_auto = re.search(r"m_PlayAutomatically:\s*(\d+)", blk)
            auto = bool(m_auto and m_auto.group(1) == "1")
            for g in re.findall(r"guid:\s*([0-9a-fA-F]+)", blk):
                cp = guid_index.get(g, "")
                if cp.endswith(".anim"):
                    cname = os.path.splitext(os.path.basename(cp))[0]
                    all_clips.append(cname)
                    if auto:
                        play_auto_clips.append(cname)
        elif ctype == "114" and "IntroLength:" in blk:
            mi = re.search(r"(?m)^[ \t]*Intro:[ \t]*(.*)$", blk)
            md = re.search(r"(?m)^[ \t]*Idle:[ \t]*(.*)$", blk)
            mil = re.search(r"(?m)^[ \t]*IntroLength:[ \t]*([0-9.eE+\-]+)", blk)
            msd = re.search(r"(?m)^[ \t]*SpawnAudioDelaySecs:[ \t]*([0-9.eE+\-]+)", blk)
            msa = re.search(r"SpawnAudio:.*guid:\s*([0-9a-fA-F]+)", blk)
            if mi:
                meta["intro"] = mi.group(1).strip()
            if md:
                meta["idle"] = md.group(1).strip()
            if mil:
                meta["intro_length"] = float(mil.group(1))
            if msd:
                meta["spawn_audio_delay"] = float(msd.group(1))
            if msa:
                ap = guid_index.get(msa.group(1), "")
                if ap and os.path.exists(ap):
                    bname = os.path.basename(ap)
                    dst = os.path.join(OUT_SFX, bname)
                    if not os.path.exists(dst):
                        shutil.copy2(ap, dst)
                    meta["spawn_audio"] = f"res://assets/audio/sfx/{bname}"

    if is_building:
        # Buildings like GhostWindmill ('Take 001_21') & SpiritTower ('SpiritTower') loop an idle clip automatically.
        for cname in play_auto_clips + all_clips:
            if cname not in ("Floop", "Derez", "Death", "Crash", "Hammer"):
                meta["ambient"] = cname
                break
    return meta


def _export_entity_group(
    bucket_name: str,
    src_dir: str,
    out_dir: str,
    obj_names: list[str],
    out_manifest: dict,
    guid_index: dict[str, str],
) -> None:
    is_building = (bucket_name == "buildings")
    # Remove legacy static .obj files (and their .obj.import sidecars) now replaced by animated .glb
    for old_obj in glob.glob(os.path.join(out_dir, "*.obj*")):
        os.remove(old_obj)

    for oname in obj_names:
        pref = find_prefab_case_insensitive(src_dir, oname)
        if not pref:
            print(f"[WARN] Missing {bucket_name} prefab for ObjectName={oname}")
            continue
        out_name = f"{oname}.glb"
        out_path = os.path.join(out_dir, out_name)
        ok = export_unity_subtree_to_glb(
            pref,
            out_path,
            guid_index,
            scale_factor=0.05,
            skip_name_tokens=("outline", "0utline"),
            bake_uv_mat_transforms=True,
            zero_root_pos=True,
        )
        if ok:
            entry = {
                "scene": f"res://assets/models/battle/{bucket_name}/{out_name}",
            }
            entry.update(_extract_summon_meta(pref, guid_index, is_building))
            out_manifest[oname] = entry


if __name__ == "__main__":
    main()
