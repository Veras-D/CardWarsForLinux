#!/usr/bin/env python3
"""
export_battle_stage1.py — Extract authentic Stage 1 Battle assets directly from Unity Assets/:
  1. godot/assets/models/battle/banners/Battle_Battle.glb (from BattleScene.unity GO 787 + Take 001_15.anim)
  2. godot/assets/models/battle/props/HoldCards.glb (from Assets/Resources/props/HoldCards.prefab)
  3. godot/assets/models/battle/characters/<Prefab>.glb (all unique prefabs in db_Characters.json, scale 0.05)
  4. godot/assets/models/battle/environments/<Prefab>.glb (all unique Level/Table/Chair in db_Quest.json, scale 0.05)
  5. godot/src/battle/BattleIntroAnims.gd (Hermite splines from BattleIntro_CUT1..4.anim, scale 0.05)
"""

import json
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from unity_glb import build_guid_index, export_unity_subtree_to_glb
from unity_anim import parse_clip, HERMITE_HELPERS_GD


def export_battle_banner(guid_index: dict[str, str]) -> None:
    scene_path = os.path.join(REPO_ROOT, "Assets", "Scene", "_hirez", "Scenes", "BattleScene.unity")
    banner_specs = [
        ("Battle_Battle.glb", "787", "Take 001_15"),
        ("Battle_YourTurn.glb", "9", "Take 001_18"),
        ("Battle_OpponentsTurn.glb", "423", "Take 001_19"),
        ("Battle_Attack.glb", "2008", "Battle_Attack"),
        ("Battle_Defend.glb", "1916", "Battle_Defend"),
    ]
    for filename, go_id, clip_name in banner_specs:
        out_path = os.path.join(REPO_ROOT, "godot", "assets", "models", "battle", "banners", filename)
        anim_path = os.path.join(REPO_ROOT, "Assets", "AnimationClip", f"{clip_name}.anim")
        ok = export_unity_subtree_to_glb(
            yaml_path=scene_path,
            out_glb_path=out_path,
            guid_index=guid_index,
            root_go_id=go_id,
            scale_factor=1.0,
            extra_clips=[(clip_name, anim_path)],
            double_sided_mats=True,
        )
        print(f"[{'OK' if ok else 'FAIL'}] {filename} -> {out_path}")


def export_props(guid_index: dict[str, str]) -> None:
    for pname in ("HoldCards", "PlayingCard"):
        prefab_path = os.path.join(REPO_ROOT, "Assets", "Resources", "props", f"{pname}.prefab")
        out_path = os.path.join(REPO_ROOT, "godot", "assets", "models", "battle", "props", f"{pname}.glb")
        ok = export_unity_subtree_to_glb(
            yaml_path=prefab_path,
            out_glb_path=out_path,
            guid_index=guid_index,
            scale_factor=1.0,
            double_sided_mats=True,
        )
        print(f"[{'OK' if ok else 'FAIL'}] {pname}.glb -> {out_path}")


def export_characters(guid_index: dict[str, str]) -> None:
    db_path = os.path.join(REPO_ROOT, "godot", "data", "db_Characters.json")
    with open(db_path, "r", encoding="utf-8") as f:
        chars = json.load(f)

    prefabs = sorted({c.get("Prefab", "").strip() for c in chars if c.get("Prefab", "").strip()})
    out_dir = os.path.join(REPO_ROOT, "godot", "assets", "models", "battle", "characters")
    ok_cnt = 0
    for pf in prefabs:
        pfile = os.path.join(REPO_ROOT, "Assets", "Resources", "characters", f"{pf}.prefab")
        if not os.path.exists(pfile):
            print(f"[SKIP] Missing character prefab: {pfile}")
            continue
        out_glb = os.path.join(out_dir, f"{pf}.glb")
        ok = export_unity_subtree_to_glb(
            yaml_path=pfile,
            out_glb_path=out_glb,
            guid_index=guid_index,
            scale_factor=0.05,
            bake_uv_mat_transforms=False,
        )
        if ok:
            ok_cnt += 1
        print(f"[{'OK' if ok else 'FAIL'}] Character {pf}.glb")
    print(f"Characters exported: {ok_cnt}/{len(prefabs)}")


def export_environments(guid_index: dict[str, str]) -> None:
    db_path = os.path.join(REPO_ROOT, "godot", "data", "db_Quest.json")
    with open(db_path, "r", encoding="utf-8") as f:
        quests = json.load(f)

    prefab_names: set[str] = {"TreeFort", "TreeFort_Table", "TreeFort_Chair"}
    items = quests if isinstance(quests, list) else quests.values()
    for q in items:
        if not isinstance(q, dict):
            continue
        for key in ("LevelPrefab", "TablePrefab", "ChairPrefab"):
            val = str(q.get(key, "")).strip()
            if val:
                prefab_names.add(val)

    out_dir = os.path.join(REPO_ROOT, "godot", "assets", "models", "battle", "environments")
    ok_cnt = 0
    for pf in sorted(prefab_names):
        pfile = os.path.join(REPO_ROOT, "Assets", "Resources", "environment", f"{pf}.prefab")
        if not os.path.exists(pfile):
            print(f"[SKIP] Missing environment prefab: {pfile}")
            continue
        out_glb = os.path.join(out_dir, f"{pf}.glb")
        ok = export_unity_subtree_to_glb(
            yaml_path=pfile,
            out_glb_path=out_glb,
            guid_index=guid_index,
            scale_factor=0.05,
            bake_uv_mat_transforms=True,
            double_sided_mats=True,
        )
        if ok:
            ok_cnt += 1
        print(f"[{'OK' if ok else 'FAIL'}] Environment {pf}.glb")
    print(f"Environments exported: {ok_cnt}/{len(prefab_names)}")


def export_intro_camera_anims() -> None:
    out_gd = os.path.join(REPO_ROOT, "godot", "src", "battle", "BattleIntroAnims.gd")
    lines = [
        "# Auto-generated by scripts/unity_extractor/export_battle_stage1.py",
        "# Exact Hermite keyframes from Assets/AnimationClip/BattleIntro_CUT1..4.anim",
        "# Converted with S_Z reflection and 0.05 world scale to match BattleArena3D.",
        "class_name BattleIntroAnims",
        "extends RefCounted",
        "",
    ]

    durations = {}
    for idx in range(1, 5):
        clip_path = os.path.join(REPO_ROOT, "Assets", "AnimationClip", f"BattleIntro_CUT{idx}.anim")
        secs = parse_clip(clip_path)
        pos_keys = secs.get(("pos", ""), [])
        rot_keys = secs.get(("rot", ""), [])
        dur = max(
            pos_keys[-1][0] if pos_keys else 0.0,
            rot_keys[-1][0] if rot_keys else 0.0,
        )
        durations[idx] = dur

        lines.append(f"const CUT{idx}_DURATION: float = {dur:.6f}")
        lines.append(f"const CUT{idx}_POS := [")
        for tm, v, ins, outs in pos_keys:
            lines.append(
                f"\t[{tm:.6f}, "
                f"Vector3({v[0]*0.05:.6f}, {v[1]*0.05:.6f}, {-v[2]*0.05:.6f}), "
                f"Vector3({ins[0]*0.05:.6f}, {ins[1]*0.05:.6f}, {-ins[2]*0.05:.6f}), "
                f"Vector3({outs[0]*0.05:.6f}, {outs[1]*0.05:.6f}, {-outs[2]*0.05:.6f})],"
            )
        lines.append("]")
        lines.append("")

        lines.append(f"const CUT{idx}_ROT := [")
        for tm, v, ins, outs in rot_keys:
            lines.append(
                f"\t[{tm:.6f}, "
                f"Vector4({-v[0]:.6f}, {-v[1]:.6f}, {v[2]:.6f}, {v[3]:.6f}), "
                f"Vector4({-ins[0]:.6f}, {-ins[1]:.6f}, {ins[2]:.6f}, {ins[3]:.6f}), "
                f"Vector4({-outs[0]:.6f}, {-outs[1]:.6f}, {outs[2]:.6f}, {outs[3]:.6f})],"
            )
        lines.append("]")
        lines.append("")

    lines.append(HERMITE_HELPERS_GD.strip())
    lines.append("")
    lines.extend([
        "static func eval_cut_transform(cut_idx: int, t: float) -> Transform3D:",
        "\tvar pos_keys: Array",
        "\tvar rot_keys: Array",
        "\tmatch cut_idx:",
        "\t\t1:",
        "\t\t\tpos_keys = CUT1_POS",
        "\t\t\trot_keys = CUT1_ROT",
        "\t\t2:",
        "\t\t\tpos_keys = CUT2_POS",
        "\t\t\trot_keys = CUT2_ROT",
        "\t\t3:",
        "\t\t\tpos_keys = CUT3_POS",
        "\t\t\trot_keys = CUT3_ROT",
        "\t\t_:",
        "\t\t\tpos_keys = CUT4_POS",
        "\t\t\trot_keys = CUT4_ROT",
        "\tvar pos := _eval_vec3(pos_keys, t)",
        "\tvar rot := _eval_quat(rot_keys, t)",
        "\treturn Transform3D(Basis(rot), pos)",
        "",
        "static func get_cut_duration(cut_idx: int) -> float:",
        "\tmatch cut_idx:",
        "\t\t1: return CUT1_DURATION",
        "\t\t2: return CUT2_DURATION",
        "\t\t3: return CUT3_DURATION",
        "\t\t_: return CUT4_DURATION",
        "",
    ])

    with open(out_gd, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"[OK] BattleIntroAnims.gd -> {out_gd} (durations: {durations})")


def main() -> None:
    banners_only = "--banners-only" in sys.argv[1:]
    print("Building Assets GUID index...")
    guid_index = build_guid_index(os.path.join(REPO_ROOT, "Assets"))
    print(f"Indexed {len(guid_index)} GUIDs.")
    export_battle_banner(guid_index)
    if banners_only:
        return
    export_intro_camera_anims()
    export_props(guid_index)
    export_characters(guid_index)
    export_environments(guid_index)


if __name__ == "__main__":
    main()
