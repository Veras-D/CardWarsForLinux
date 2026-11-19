#!/usr/bin/env python3
"""
unity_glb.py — Reusable Unity Prefab / Scene Subtree + AnimationClip -> glTF 2.0 (.glb) exporter.

Converts Unity left-handed YAML prefabs/subtrees, .asset meshes (static and skinned),
.mat materials + Texture2D PNGs, and .anim Hermite curves into self-contained Godot-ready
binary .glb files with embedded Skeleton3D skinning, KHR_materials_unlit, and AnimationPlayer clips.

Coordinate conversion (Unity LH -> Godot RH via S_Z = diag(1, 1, -1)):
  - Positions:   (x, y, -z)
  - Quaternions: (-x, -y, z, w) normalized
  - Scale:       (sx, sy, sz)
  - Vertices:    (vx, vy, -vz)
  - Triangles:   (a, c, b) reversed winding
  - UVs:         (u, 1.0 - v)  [unless material tiling/offset baked or left raw]
  - BindPose:    S_Z * B_unity * S_Z (negate [0][2], [1][2], [2][0], [2][1], [2][3])
"""

import glob
import io
import json
import math
import os
import re
import struct
import sys
from PIL import Image

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
if SCRIPT_DIR not in sys.path:
    sys.path.insert(0, SCRIPT_DIR)

from unity_mesh import parse_unity_mesh
from unity_anim import parse_clip, is_constant_curve


def _hermite(p0: float, m0: float, p1: float, m1: float, u: float) -> float:
    u2 = u * u
    u3 = u2 * u
    return (2.0 * u3 - 3.0 * u2 + 1.0) * p0 + (u3 - 2.0 * u2 + u) * m0 + (-2.0 * u3 + 3.0 * u2) * p1 + (u3 - u2) * m1


def build_guid_index(assets_root: str) -> dict[str, str]:
    idx: dict[str, str] = {}
    for meta in glob.glob(os.path.join(assets_root, "**", "*.meta"), recursive=True):
        with open(meta, "r", encoding="utf-8", errors="replace") as f:
            txt = f.read(512)
        m = re.search(r"guid:\s*([0-9a-fA-F]+)", txt)
        if m:
            idx[m.group(1)] = meta[:-5]
    return idx


def _parse_vec3(txt: str, field: str, default=(0.0, 0.0, 0.0)) -> tuple[float, float, float]:
    m = re.search(
        rf"{field}:\s*\{{x:\s*([-0-9.eE+]+),\s*y:\s*([-0-9.eE+]+),\s*z:\s*([-0-9.eE+]+)\}}",
        txt,
    )
    if not m:
        return default
    return (float(m.group(1)), float(m.group(2)), float(m.group(3)))


def _parse_quat(txt: str, field: str) -> tuple[float, float, float, float]:
    m = re.search(
        rf"{field}:\s*\{{x:\s*([-0-9.eE+]+),\s*y:\s*([-0-9.eE+]+),\s*z:\s*([-0-9.eE+]+),\s*w:\s*([-0-9.eE+]+)\}}",
        txt,
    )
    if not m:
        return (0.0, 0.0, 0.0, 1.0)
    return (float(m.group(1)), float(m.group(2)), float(m.group(3)), float(m.group(4)))


def _unity_quat_to_gltf(q: tuple[float, float, float, float]) -> list[float]:
    qx, qy, qz, qw = -q[0], -q[1], q[2], q[3]
    n = math.sqrt(qx * qx + qy * qy + qz * qz + qw * qw)
    if n < 1e-12:
        return [0.0, 0.0, 0.0, 1.0]
    return [qx / n, qy / n, qz / n, qw / n]


def _parse_submeshes(mesh_asset_path: str) -> list[tuple[int, int]]:
    with open(mesh_asset_path, "r", encoding="utf-8", errors="replace") as f:
        t = f.read()
    sm = re.findall(r"firstByte:\s*(\d+)\s*\n\s*indexCount:\s*(\d+)", t)
    if not sm:
        return []
    return [(int(fb) // 2, int(ic)) for fb, ic in sm]


def _parse_material(mat_path: str, guid_index: dict[str, str]) -> dict:
    info = {
        "name": os.path.splitext(os.path.basename(mat_path))[0],
        "tex_path": None,
        "uv_scale": (1.0, 1.0),
        "uv_offset": (0.0, 0.0),
        "transparent": False,
        "cutout": False,
        "color": (1.0, 1.0, 1.0, 1.0),
    }
    if not mat_path or not os.path.exists(mat_path):
        return info
    with open(mat_path, "r", encoding="utf-8", errors="replace") as f:
        txt = f.read()
    m_sh = re.search(r"m_Shader:\s*\{fileID:\s*(\d+)(?:,\s*guid:\s*([0-9a-fA-F]+))?", txt)
    if m_sh:
        sid = m_sh.group(1)
        sguid = m_sh.group(2) or ""
        if sid in ("10750", "10512") or sguid in ("7567d051d579bf24a80e47a1b2e37eb4", "451606381668ffe4886a4874a7cc0ea5"):
            info["transparent"] = True
        elif sid == "10752":
            info["cutout"] = True
    m_tex = re.search(r"_MainTex:[\s\S]*?guid:\s*([0-9a-fA-F]+)", txt)
    if m_tex and m_tex.group(1) in guid_index:
        tp = guid_index[m_tex.group(1)]
        bname = os.path.basename(tp)
        if bname.startswith("low_"):
            hires = os.path.join(os.path.dirname(tp), bname[4:])
            if os.path.exists(hires):
                tp = hires
        if os.path.exists(tp):
            info["tex_path"] = tp
    mt_block = txt[txt.find("_MainTex:"):] if "_MainTex:" in txt else ""
    if mt_block:
        ms = re.search(r"m_Scale:\s*\{x:\s*([-0-9.eE+]+),\s*y:\s*([-0-9.eE+]+)\}", mt_block)
        mo = re.search(r"m_Offset:\s*\{x:\s*([-0-9.eE+]+),\s*y:\s*([-0-9.eE+]+)\}", mt_block)
        if ms:
            info["uv_scale"] = (float(ms.group(1)), float(ms.group(2)))
        if mo:
            info["uv_offset"] = (float(mo.group(1)), float(mo.group(2)))
    return info


class GlbBuilder:
    def __init__(self, generator: str = "CardWars-Unity-GLB") -> None:
        self.buf = bytearray()
        self.buffer_views: list[dict] = []
        self.accessors: list[dict] = []
        self.images: list[dict] = []
        self.textures: list[dict] = []
        self.samplers: list[dict] = [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}]
        self.materials: list[dict] = []
        self.meshes: list[dict] = []
        self.nodes: list[dict] = []
        self.skins: list[dict] = []
        self.animations: list[dict] = []
        self._img_cache: dict[str, int] = {}
        self._mat_cache: dict[tuple, int] = {}
        self._tex_alpha_cache: dict[str, bool] = {}
        self.generator = generator

    def _pad4(self) -> None:
        rem = len(self.buf) % 4
        if rem:
            self.buf.extend(b"\x00" * (4 - rem))

    def add_bytes(self, data: bytes, target: int | None = None) -> int:
        self._pad4()
        offset = len(self.buf)
        self.buf.extend(data)
        bv = {"buffer": 0, "byteOffset": offset, "byteLength": len(data)}
        if target is not None:
            bv["target"] = target
        idx = len(self.buffer_views)
        self.buffer_views.append(bv)
        return idx

    def add_accessor(
        self,
        raw_bytes: bytes,
        component_type: int,
        count: int,
        acc_type: str,
        target: int | None = None,
        min_v: list[float] | None = None,
        max_v: list[float] | None = None,
    ) -> int:
        bv = self.add_bytes(raw_bytes, target=target)
        acc: dict = {
            "bufferView": bv,
            "byteOffset": 0,
            "componentType": component_type,
            "count": count,
            "type": acc_type,
        }
        if min_v is not None:
            acc["min"] = min_v
        if max_v is not None:
            acc["max"] = max_v
        idx = len(self.accessors)
        self.accessors.append(acc)
        return idx

    def _tex_has_transparency(self, tex_path: str) -> bool:
        if tex_path in self._tex_alpha_cache:
            return self._tex_alpha_cache[tex_path]
        has_a = False
        try:
            with Image.open(tex_path) as im:
                if im.mode in ("RGBA", "LA", "PA") or (im.mode == "P" and "transparency" in im.info):
                    ext = im.convert("RGBA").getextrema()[3]
                    has_a = ext[0] < 250
        except Exception:
            has_a = False
        self._tex_alpha_cache[tex_path] = has_a
        return has_a

    def get_or_add_material(self, mat_info: dict, double_sided: bool = False) -> int:
        tex_path = mat_info.get("tex_path")
        has_alpha = bool(tex_path and self._tex_has_transparency(tex_path))
        is_blend = bool(mat_info.get("transparent", False) and has_alpha)
        if has_alpha and ("shadow" in mat_info["name"].lower() or "alpha" in mat_info["name"].lower() or "atlas" in mat_info["name"].lower() or "mouth" in mat_info["name"].lower() or "eyes" in mat_info["name"].lower()):
            is_blend = True
        is_cutout = bool(not is_blend and mat_info.get("cutout", False) and has_alpha)
        key = (tex_path or "", is_blend, is_cutout, double_sided)
        if key in self._mat_cache:
            return self._mat_cache[key]

        mat_dict: dict = {
            "name": mat_info["name"],
            "pbrMetallicRoughness": {"metallicFactor": 0.0, "roughnessFactor": 1.0},
            "extensions": {"KHR_materials_unlit": {}},
        }
        if tex_path and os.path.exists(tex_path):
            if tex_path not in self._img_cache:
                # Re-save cleanly as standard PNG bytes so Godot reads all Unity PNG formats smoothly
                with Image.open(tex_path) as im:
                    bio = io.BytesIO()
                    im.save(bio, format="PNG")
                    png_bytes = bio.getvalue()
                bv = self.add_bytes(png_bytes)
                img_idx = len(self.images)
                self.images.append({"bufferView": bv, "mimeType": "image/png", "name": os.path.basename(tex_path)})
                tex_idx = len(self.textures)
                self.textures.append({"sampler": 0, "source": img_idx})
                self._img_cache[tex_path] = tex_idx
            mat_dict["pbrMetallicRoughness"]["baseColorTexture"] = {"index": self._img_cache[tex_path]}
        if is_blend:
            mat_dict["alphaMode"] = "BLEND"
        elif is_cutout:
            mat_dict["alphaMode"] = "MASK"
            mat_dict["alphaCutoff"] = 0.45
        if double_sided:
            mat_dict["doubleSided"] = True

        idx = len(self.materials)
        self.materials.append(mat_dict)
        self._mat_cache[key] = idx
        return idx

    def to_glb_bytes(self, root_nodes: list[int]) -> bytes:
        self._pad4()
        gltf = {
            "asset": {"version": "2.0", "generator": self.generator},
            "extensionsUsed": ["KHR_materials_unlit"],
            "scene": 0,
            "scenes": [{"nodes": root_nodes}],
            "nodes": self.nodes,
            "meshes": self.meshes,
            "materials": self.materials,
            "textures": self.textures,
            "images": self.images,
            "samplers": self.samplers,
            "accessors": self.accessors,
            "bufferViews": self.buffer_views,
            "buffers": [{"byteLength": len(self.buf)}],
        }
        if self.skins:
            gltf["skins"] = self.skins
        if self.animations:
            gltf["animations"] = self.animations
        # Omit empty top-level arrays per glTF spec
        for opt in ("textures", "images", "samplers", "materials"):
            if not gltf[opt]:
                del gltf[opt]

        json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
        j_pad = (4 - (len(json_bytes) % 4)) % 4
        json_bytes += b" " * j_pad

        b_pad = (4 - (len(self.buf) % 4)) % 4
        bin_bytes = bytes(self.buf) + (b"\x00" * b_pad)

        total_len = 12 + 8 + len(json_bytes) + 8 + len(bin_bytes)
        header = struct.pack("<III", 0x46546C67, 2, total_len)
        c_json = struct.pack("<II", len(json_bytes), 0x4E4F534A) + json_bytes
        c_bin = struct.pack("<II", len(bin_bytes), 0x004E4942) + bin_bytes
        return header + c_json + c_bin


def _parse_unity_yaml_objects(yaml_text: str) -> tuple[dict[str, str], dict[str, tuple[str, str]], dict[str, dict], dict[str, str]]:
    """Parses GameObjects, Components, Transforms, and GO->Transform map from a Unity prefab or scene text."""
    blocks = yaml_text.split("--- !u!")
    comp_map: dict[str, tuple[str, str]] = {}
    gos: dict[str, dict] = {}
    trs: dict[str, dict] = {}
    go_to_tr: dict[str, str] = {}

    for blk in blocks[1:]:
        nl = blk.find("\n")
        if nl < 0:
            continue
        hdr = blk[:nl]
        m = re.match(r"(\d+)\s+&(\d+)", hdr)
        if not m:
            continue
        cid, fid = m.group(1), m.group(2)
        comp_map[fid] = (cid, blk)
        if cid == "1":
            mn = re.search(r"m_Name:\s*(.+)", blk)
            ma = re.search(r"m_IsActive:\s*(\d+)", blk)
            comps = re.findall(r"component:\s*\{fileID:\s*(\d+)\}", blk)
            name = mn.group(1).strip() if mn else f"GO_{fid}"
            if len(name) >= 2 and name[0] == "'" and name[-1] == "'":
                name = name[1:-1]
            gos[fid] = {
                "id": fid,
                "name": name,
                "active": (ma.group(1) == "1") if ma else True,
                "comps": comps,
            }
        elif cid == "4":
            mgo = re.search(r"m_GameObject:\s*\{fileID:\s*(\d+)\}", blk)
            mf = re.search(r"m_Father:\s*\{fileID:\s*(\d+)\}", blk)
            children = []
            in_c = False
            for line in blk.splitlines():
                if line.strip().startswith("m_Children:"):
                    if "[]" in line:
                        break
                    in_c = True
                    continue
                if in_c:
                    mc = re.search(r"-\s*\{fileID:\s*(\d+)\}", line)
                    if mc:
                        children.append(mc.group(1))
                    else:
                        break
            go_id = mgo.group(1) if mgo else ""
            trs[fid] = {
                "id": fid,
                "go": go_id,
                "father": mf.group(1) if mf else "0",
                "children": children,
                "pos": _parse_vec3(blk, "m_LocalPosition", (0.0, 0.0, 0.0)),
                "rot": _parse_quat(blk, "m_LocalRotation"),
                "scale": _parse_vec3(blk, "m_LocalScale", (1.0, 1.0, 1.0)),
            }
            if go_id:
                go_to_tr[go_id] = fid
    return gos, comp_map, trs, go_to_tr


def export_unity_subtree_to_glb(
    yaml_path: str,
    out_glb_path: str,
    guid_index: dict[str, str],
    root_go_id: str | None = None,
    scale_factor: float = 1.0,
    extra_clips: list[tuple[str, str]] | None = None,
    skip_name_tokens: tuple[str, ...] = (),
    bake_uv_mat_transforms: bool = False,
    double_sided_mats: bool = False,
    wrap_root_name: str | None = None,
    zero_root_pos: bool = False,
) -> bool:
    """
    Exports a Unity .prefab (root_go_id=None) or subtree of a .unity scene (root_go_id set)
    to a binary .glb file.
    extra_clips: optional list of (clip_name, anim_file_path) to embed alongside any Animation clips found.
    If bake_uv_mat_transforms is True, applies material _MainTex m_Scale/m_Offset into TEXCOORD_0 (skipped for M_MOUTH/M_EYES).
    """
    with open(yaml_path, "r", encoding="utf-8", errors="replace") as f:
        yaml_txt = f.read()

    gos, comp_map, trs, go_to_tr = _parse_unity_yaml_objects(yaml_txt)

    if root_go_id is None:
        m_root = re.search(r"m_RootGameObject:\s*\{fileID:\s*(\d+)\}", yaml_txt)
        if m_root:
            root_go_id = m_root.group(1)
        else:
            # fallback: first transform with father == 0
            for tid, tr in trs.items():
                if tr["father"] == "0":
                    root_go_id = tr["go"]
                    break
    if not root_go_id or root_go_id not in go_to_tr:
        return False

    builder = GlbBuilder()
    tr_to_node: dict[str, int] = {}
    anim_hosts: list[tuple[str, list[str]]] = []  # (host_tr_id, [anim_paths])
    mesh_records: list[dict] = []

    def visit_tr(tr_id: str, parent_is_root: bool = False) -> int:
        tr = trs[tr_id]
        go = gos.get(tr["go"], {"name": f"Node_{tr_id}", "active": True, "comps": []})
        gname = go["name"]

        node_idx = len(builder.nodes)
        px, py, pz = (0.0, 0.0, 0.0) if (zero_root_pos and parent_is_root) else tr["pos"]
        # Scale positions only at root or uniformly everywhere? Best: keep local positions unscaled, put scale_factor on wrapper root!
        nd: dict = {
            "name": gname,
            "translation": [px, py, -pz],
            "rotation": _unity_quat_to_gltf(tr["rot"]),
            "scale": [tr["scale"][0], tr["scale"][1], tr["scale"][2]],
        }
        builder.nodes.append(nd)
        tr_to_node[tr_id] = node_idx

        # Inspect components on this GameObject
        mf_mesh_path = None
        mr_mats: list[str] = []
        smr_block = None
        for cid_ref in go["comps"]:
            ctype, blk = comp_map.get(cid_ref, ("", ""))
            if ctype == "33":
                mm = re.search(r"m_Mesh:\s*\{[^}]*guid:\s*([0-9a-fA-F]+)", blk)
                if mm and mm.group(1) in guid_index:
                    mf_mesh_path = guid_index[mm.group(1)]
            elif ctype == "23":
                for g in re.findall(r"-\s*\{fileID:\s*\d+,\s*guid:\s*([0-9a-fA-F]+)", blk):
                    mr_mats.append(guid_index.get(g, ""))
            elif ctype == "137":
                smr_block = blk
            elif ctype == "111":
                clips = []
                for g in re.findall(r"guid:\s*([0-9a-fA-F]+)", blk):
                    cp = guid_index.get(g, "")
                    if cp.endswith(".anim") and os.path.exists(cp) and cp not in clips:
                        clips.append(cp)
                if clips:
                    anim_hosts.append((tr_id, clips))

        skip = (not go["active"]) or any(tok in gname.lower() for tok in skip_name_tokens)
        if not skip:
            if smr_block:
                mm = re.search(r"m_Mesh:\s*\{[^}]*guid:\s*([0-9a-fA-F]+)", smr_block)
                if mm and mm.group(1) in guid_index:
                    mesh_path = guid_index[mm.group(1)]
                    mats = [guid_index.get(g, "") for g in re.findall(r"-\s*\{fileID:\s*\d+,\s*guid:\s*([0-9a-fA-F]+)", smr_block)]
                    bones_tr = re.findall(r"-\s*\{fileID:\s*(\d+)\}", smr_block[smr_block.find("m_Bones:"):smr_block.find("m_BlendShapeWeights:")]) if "m_Bones:" in smr_block else []
                    m_rb = re.search(r"m_RootBone:\s*\{fileID:\s*(\d+)\}", smr_block)
                    mesh_records.append({
                        "node_idx": node_idx,
                        "go_name": gname,
                        "mesh_path": mesh_path,
                        "mat_paths": mats,
                        "bones_tr": bones_tr,
                        "root_bone_tr": m_rb.group(1) if m_rb else None,
                    })
            elif mf_mesh_path and os.path.exists(mf_mesh_path):
                mesh_records.append({
                    "node_idx": node_idx,
                    "go_name": gname,
                    "mesh_path": mf_mesh_path,
                    "mat_paths": mr_mats,
                    "bones_tr": [],
                    "root_bone_tr": None,
                })

        child_indices = []
        for ch_tr in tr["children"]:
            if ch_tr in trs:
                child_indices.append(visit_tr(ch_tr))
        if child_indices:
            nd["children"] = child_indices
        return node_idx

    top_node_idx = visit_tr(go_to_tr[root_go_id], parent_is_root=True)
    if abs(scale_factor - 1.0) > 1e-6 or wrap_root_name:
        wrapper_idx = len(builder.nodes)
        builder.nodes.append({
            "name": wrap_root_name or builder.nodes[top_node_idx]["name"] + "_Root",
            "scale": [scale_factor, scale_factor, scale_factor],
            "children": [top_node_idx],
        })
        scene_roots = [wrapper_idx]
    else:
        scene_roots = [top_node_idx]

    # Build meshes & skins now that all bone tr_ids are mapped to node indices
    for rec in mesh_records:
        mdata = parse_unity_mesh(rec["mesh_path"])
        verts = mdata["verts"]
        uvs = mdata["uvs"]
        tris = mdata["tris"]
        if not verts or not tris:
            continue

        # Positions (S_Z reflected)
        pos_bytes = bytearray()
        min_p = [1e30, 1e30, 1e30]
        max_p = [-1e30, -1e30, -1e30]
        for vx, vy, vz in verts:
            gz = -vz
            pos_bytes.extend(struct.pack("<3f", vx, vy, gz))
            for k, val in enumerate((vx, vy, gz)):
                if val < min_p[k]: min_p[k] = val
                if val > max_p[k]: max_p[k] = val
        acc_pos = builder.add_accessor(bytes(pos_bytes), 5126, len(verts), "VEC3", target=34962, min_v=min_p, max_v=max_p)

        # Materials & UVs per submesh
        mat_paths = rec["mat_paths"]
        first_mat_info = _parse_material(mat_paths[0], guid_index) if mat_paths else {"name": "Default", "tex_path": None, "uv_scale": (1.0, 1.0), "uv_offset": (0.0, 0.0), "transparent": False, "cutout": False}
        is_face_mesh = ("m_mouth" in rec["go_name"].lower() or "m_eyes" in rec["go_name"].lower())

        uv_sx, uv_sy = first_mat_info["uv_scale"]
        uv_ox, uv_oy = first_mat_info["uv_offset"]
        apply_uv_xform = bake_uv_mat_transforms and not is_face_mesh and (abs(uv_sx - 1.0) > 1e-5 or abs(uv_sy - 1.0) > 1e-5 or abs(uv_ox) > 1e-5 or abs(uv_oy) > 1e-5)

        uv_bytes = bytearray()
        for u, v in uvs:
            if apply_uv_xform:
                u = u * uv_sx + uv_ox
                v = v * uv_sy + uv_oy
            uv_bytes.extend(struct.pack("<2f", u, 1.0 - v))
        acc_uv = builder.add_accessor(bytes(uv_bytes), 5126, len(uvs), "VEC2", target=34962)

        attrs: dict = {"POSITION": acc_pos, "TEXCOORD_0": acc_uv}

        # Skinning if SkinnedMeshRenderer has bones mapped
        bones_tr = rec["bones_tr"]
        bps = mdata["bps"]
        weights = mdata["weights"]
        bone_indices = mdata["bone_indices"]
        if bones_tr and bps and len(weights) == len(verts) and len(bone_indices) == len(verts):
            joint_nodes = [tr_to_node[btr] for btr in bones_tr if btr in tr_to_node]
            if len(joint_nodes) == len(bones_tr):
                # Convert bindposes: S_Z * B * S_Z, stored column-major
                ibm_bytes = bytearray()
                nb = min(len(joint_nodes), len(bps))
                for bi in range(nb):
                    B = [row[:] for row in bps[bi]]
                    # Negate row 2 and col 2
                    for r in range(4):
                        B[r][2] = -B[r][2]
                    for c in range(4):
                        B[2][c] = -B[2][c]
                    for c in range(4):
                        for r in range(4):
                            ibm_bytes.extend(struct.pack("<f", B[r][c]))
                acc_ibm = builder.add_accessor(bytes(ibm_bytes), 5126, nb, "MAT4")

                j_bytes = bytearray()
                w_bytes = bytearray()
                for vi in range(len(verts)):
                    b4 = bone_indices[vi]
                    w4 = list(weights[vi])
                    w4 = [w4[k] if b4[k] < nb else 0.0 for k in range(4)]
                    b4_c = [b4[k] if b4[k] < nb else 0 for k in range(4)]
                    s = sum(w4)
                    if s <= 1e-6:
                        w4 = [1.0, 0.0, 0.0, 0.0]
                    else:
                        w4 = [w / s for w in w4]
                    j_bytes.extend(struct.pack("<4H", *b4_c))
                    w_bytes.extend(struct.pack("<4f", *w4))
                acc_joints = builder.add_accessor(bytes(j_bytes), 5123, len(verts), "VEC4", target=34962)
                acc_weights = builder.add_accessor(bytes(w_bytes), 5126, len(verts), "VEC4", target=34962)
                attrs["JOINTS_0"] = acc_joints
                attrs["WEIGHTS_0"] = acc_weights

                skin_dict: dict = {"inverseBindMatrices": acc_ibm, "joints": joint_nodes}
                if rec["root_bone_tr"] and rec["root_bone_tr"] in tr_to_node:
                    skin_dict["skeleton"] = tr_to_node[rec["root_bone_tr"]]
                skin_idx = len(builder.skins)
                builder.skins.append(skin_dict)
                builder.nodes[rec["node_idx"]]["skin"] = skin_idx

        # Submeshes
        submeshes = _parse_submeshes(rec["mesh_path"])
        if not submeshes or len(submeshes) == 1:
            submeshes = [(0, len(tris) * 3)]

        primitives = []
        for sm_i, (first_idx, icount) in enumerate(submeshes):
            t_start = first_idx // 3
            t_end = min(len(tris), (first_idx + icount) // 3)
            if t_end <= t_start:
                continue
            idx_bytes = bytearray()
            for ti in range(t_start, t_end):
                a, b, c = tris[ti]
                idx_bytes.extend(struct.pack("<3I", a, c, b))
            acc_idx = builder.add_accessor(bytes(idx_bytes), 5125, (t_end - t_start) * 3, "SCALAR", target=34963)
            mp = mat_paths[sm_i] if sm_i < len(mat_paths) else (mat_paths[0] if mat_paths else "")
            minfo = _parse_material(mp, guid_index) if mp else first_mat_info
            mat_idx = builder.get_or_add_material(minfo, double_sided=double_sided_mats)
            primitives.append({"attributes": attrs, "indices": acc_idx, "material": mat_idx})

        if primitives:
            mesh_idx = len(builder.meshes)
            builder.meshes.append({"name": rec["go_name"], "primitives": primitives})
            builder.nodes[rec["node_idx"]]["mesh"] = mesh_idx

    # Helper to resolve relative .anim path from an animation host tr_id
    def resolve_anim_path(host_tr_id: str, anim_path: str) -> int | None:
        clean = anim_path.strip()
        if len(clean) >= 2 and clean[0] == "'" and clean[-1] == "'":
            clean = clean[1:-1]
        if clean == "":
            return tr_to_node.get(host_tr_id)
        cur = host_tr_id
        for seg in clean.split("/"):
            nxt = None
            for ch_tr in trs[cur]["children"]:
                if ch_tr in trs and gos.get(trs[ch_tr]["go"], {}).get("name") == seg:
                    nxt = ch_tr
                    break
            if nxt is None:
                return None
            cur = nxt
        return tr_to_node.get(cur)

    # Collect animations
    clip_jobs: list[tuple[str, str, str]] = []  # (clip_name, anim_path, host_tr_id)
    seen_clip_names: set[str] = set()
    default_host = anim_hosts[0][0] if anim_hosts else go_to_tr[root_go_id]
    for h_tr, clips in anim_hosts:
        for cp in clips:
            cname = os.path.splitext(os.path.basename(cp))[0]
            if cname not in seen_clip_names:
                seen_clip_names.add(cname)
                clip_jobs.append((cname, cp, h_tr))
    if extra_clips:
        for cname, cp in extra_clips:
            if os.path.exists(cp) and cname not in seen_clip_names:
                seen_clip_names.add(cname)
                clip_jobs.append((cname, cp, default_host))

    for cname, cp, host_tr in clip_jobs:
        secs = parse_clip(cp)
        if not secs:
            continue
        samplers = []
        channels = []
        for (kind, apath), keys in sorted(secs.items()):
            if not keys:
                continue
            target_node = resolve_anim_path(host_tr, apath)
            if target_node is None:
                continue
            # Sample Hermite densely at 30fps if sparse (< 10 keys and non-constant) so curves match Unity tangents closely
            if len(keys) >= 2 and not is_constant_curve(keys) and (keys[-1][0] - keys[0][0]) > 0.05 and len(keys) < int((keys[-1][0] - keys[0][0]) * 25.0):
                t0, t1 = keys[0][0], keys[-1][0]
                steps = max(2, int(math.ceil((t1 - t0) * 30.0)))
                sampled_t = [t0 + (t1 - t0) * (k / steps) for k in range(steps + 1)]
                dim = len(keys[0][1])
                sampled_keys = []
                for ts in sampled_t:
                    # Find segment
                    seg_i = len(keys) - 2
                    for i in range(len(keys) - 1):
                        if ts <= keys[i + 1][0]:
                            seg_i = i
                            break
                    ka, kb = keys[seg_i], keys[seg_i + 1]
                    dt = kb[0] - ka[0]
                    u = (ts - ka[0]) / dt if dt > 1e-6 else 0.0
                    vals = [_hermite(ka[1][d], ka[3][d] * dt, kb[1][d], kb[2][d] * dt, u) for d in range(dim)]
                    sampled_keys.append((ts, vals))
                keys_out = sampled_keys
            else:
                keys_out = [(k[0], k[1]) for k in keys]

            t_bytes = bytearray()
            v_bytes = bytearray()
            for tm, v in keys_out:
                t_bytes.extend(struct.pack("<f", max(0.0, tm)))
                if kind == "pos":
                    v_bytes.extend(struct.pack("<3f", v[0], v[1], -v[2]))
                elif kind == "rot":
                    q = _unity_quat_to_gltf((v[0], v[1], v[2], v[3]))
                    v_bytes.extend(struct.pack("<4f", *q))
                else:
                    v_bytes.extend(struct.pack("<3f", v[0], v[1], v[2]))

            acc_t = builder.add_accessor(bytes(t_bytes), 5126, len(keys_out), "SCALAR", min_v=[max(0.0, keys_out[0][0])], max_v=[max(0.0, keys_out[-1][0])])
            v_type = "VEC4" if kind == "rot" else "VEC3"
            acc_v = builder.add_accessor(bytes(v_bytes), 5126, len(keys_out), v_type)
            s_idx = len(samplers)
            samplers.append({"input": acc_t, "interpolation": "LINEAR", "output": acc_v})
            path_prop = "translation" if kind == "pos" else ("rotation" if kind == "rot" else "scale")
            channels.append({"sampler": s_idx, "target": {"node": target_node, "path": path_prop}})

        if channels:
            builder.animations.append({"name": cname, "samplers": samplers, "channels": channels})

    os.makedirs(os.path.dirname(os.path.abspath(out_glb_path)), exist_ok=True)
    with open(out_glb_path, "wb") as f:
        f.write(builder.to_glb_bytes(scene_roots))
    return True
