#!/usr/bin/env python3
import os, struct, re, math, glob
import UnityPy
from PIL import Image

GLOBAL_ASSETS = '/home/verivi/Veras/Apps/CardWars/game/CardWars_Data/globalgamemanagers.assets'
SCENE_PATH = 'Assets/Scene/_hirez/Scenes/AdventureTimeEnvironmentChristmas.unity'

def quat_to_matrix(q):
    x, y, z, w = q
    norm = math.sqrt(x*x + y*y + z*z + w*w)
    if norm > 0:
        x, y, z, w = x/norm, y/norm, z/norm, w/norm
    return [
        [1.0 - 2.0*(y*y + z*z), 2.0*(x*y - z*w),       2.0*(x*z + y*w),       0.0],
        [2.0*(x*y + z*w),       1.0 - 2.0*(x*x + z*z), 2.0*(y*z - x*w),       0.0],
        [2.0*(x*z - y*w),       2.0*(y*z + x*w),       1.0 - 2.0*(x*x + y*y), 0.0],
        [0.0,                   0.0,                   0.0,                   1.0]
    ]

def mat_mul(A, B):
    C = [[0.0]*4 for _ in range(4)]
    for i in range(4):
        for j in range(4):
            C[i][j] = sum(A[i][k] * B[k][j] for k in range(4))
    return C

def make_transform(pos, rot_q, scale=(1.0, 1.0, 1.0)):
    M = quat_to_matrix(rot_q)
    for r in range(3):
        M[r][0] *= scale[0]
        M[r][1] *= scale[1]
        M[r][2] *= scale[2]
    M[0][3] = pos[0]
    M[1][3] = pos[1]
    M[2][3] = pos[2]
    return M

def transform_point(M, p):
    x = M[0][0]*p[0] + M[0][1]*p[1] + M[0][2]*p[2] + M[0][3]
    y = M[1][0]*p[0] + M[1][1]*p[1] + M[1][2]*p[2] + M[1][3]
    z = M[2][0]*p[0] + M[2][1]*p[1] + M[2][2]*p[2] + M[2][3]
    return (x, y, z)

def fix_static_objs():
    static_objs = [
        'TreeFort_FloorCeiling.obj',
        'TreeFort_Furniture.obj',
        'TreeFort_Table.obj',
        'TreeFort_Table_Objects.obj',
        'TreeFort_Chair.obj',
        'GameBoard_Boarder.obj',
        'GameBoardGrid_Red.obj',
        'GameBoardGrid_Blue.obj',
    ]
    for fname in static_objs:
        path = os.path.join('godot/assets/models', fname)
        if not os.path.exists(path):
            continue
        with open(path, 'r') as f:
            lines = f.readlines()
        has_z_flip = any('Z_FLIPPED_FOR_GODOT' in l for l in lines[:5])
        has_w_flip = any('WINDING_FLIPPED_FOR_GODOT' in l for l in lines[:5])
        if has_z_flip and has_w_flip:
            print(f'[skip] {fname} already Z_FLIPPED and WINDING_FLIPPED')
            continue
        out_lines = ['# Z_FLIPPED_FOR_GODOT WINDING_FLIPPED_FOR_GODOT\n']
        for l in lines:
            if l.startswith('# Z_FLIPPED_FOR_GODOT'):
                continue
            if not has_z_flip and l.startswith('v '):
                parts = l.strip().split()
                x, y, z = float(parts[1]), float(parts[2]), float(parts[3])
                out_lines.append(f'v {x:.5f} {y:.5f} {-z:.5f}\n')
            elif not has_w_flip and l.startswith('f '):
                parts = l.strip().split()
                out_lines.append(f'f {parts[1]} {parts[3]} {parts[2]}\n')
            else:
                out_lines.append(l)
        with open(path, 'w') as f:
            f.writelines(out_lines)
        print(f'[ok] Fixed Z and winding for {fname}')

def unpack_mesh_data(env, mesh_name):
    mesh_obj = next(obj.read() for obj in env.objects if obj.type.name == 'Mesh' and obj.read().m_Name == mesh_name)
    raw = bytes(mesh_obj.m_VertexData.m_DataSize)
    vc = mesh_obj.m_VertexData.m_VertexCount

    with open(f'Assets/Mesh/{mesh_name}.asset', 'r') as f:
        text = f.read()

    is_skinned = len(mesh_obj.m_Skin) > 0
    if is_skinned:
        pos_bytes = raw[:vc * 12]
        uv_offset = (vc * 12 + 15) & ~15
        uv_bytes = raw[uv_offset:uv_offset + vc * 8]
        verts = [struct.unpack('<fff', pos_bytes[i*12:(i+1)*12]) for i in range(vc)]
        uvs = [struct.unpack('<ff', uv_bytes[i*8:(i+1)*8]) for i in range(vc)]
    else:
        stride = len(raw) // vc
        verts = []
        uvs = []
        for i in range(vc):
            base = i * stride
            verts.append(struct.unpack('<fff', raw[base:base+12]))
            uv_off = 12 if stride == 20 else 24
            uvs.append(struct.unpack('<ff', raw[base+uv_off:base+uv_off+8]))

    idx_m = re.search(r'm_IndexBuffer:\s*([0-9a-fA-F\s]+)', text)
    ic_m = re.search(r'indexCount:\s*(\d+)', text)
    idx_bytes = bytes.fromhex(''.join(idx_m.group(1).split()))
    ic = int(ic_m.group(1))
    indices = [struct.unpack('<H', idx_bytes[i:i+2])[0] for i in range(0, ic * 2, 2)]

    return mesh_obj, verts, uvs, indices

def export_alphas_and_textures(env):
    # 1. Export TreeFort_Alphas.png from Unity Texture2D
    for obj in env.objects:
        if obj.type.name == 'Texture2D':
            d = obj.read()
            if d.m_Name == 'TreeFort_Alphas':
                img = d.image
                print(f'[info] TreeFort_Alphas Texture2D mode={img.mode} size={img.size} extrema={img.getextrema()}')
                out_tex = 'godot/assets/textures/environment/TreeFort_Alphas.png'
                img.save(out_tex)
                print(f'[ok] Saved {out_tex}')
                break

    # 2. Export TreeFort_Alphas.obj and TreeFort_Alphas02.obj
    # Both have localRotation (-0.7071068, 0, 0, 0.7071068) (-90 deg X) in Unity:
    # ux = vx, uy = vz, uz = -vy -> Godot RH (*0.05, -uz): gx = vx*0.05, gy = vz*0.05, gz = vy*0.05 (det = -1)
    for mesh_name in ['TreeFort_Alphas', 'TreeFort_Alphas02']:
        _, verts, uvs, indices = unpack_mesh_data(env, mesh_name)
        out_path = f'godot/assets/models/{mesh_name}.obj'
        with open(out_path, 'w') as out:
            out.write('# Z_FLIPPED_FOR_GODOT WINDING_FLIPPED_FOR_GODOT\n')
            out.write(f'o {mesh_name}\n')
            for vx, vy, vz in verts:
                gx = vx * 0.05
                gy = vz * 0.05
                gz = vy * 0.05
                out.write(f'v {gx:.6f} {gy:.6f} {gz:.6f}\n')
            for u, v in uvs:
                out.write(f'vt {u:.6f} {v:.6f}\n')
            for i in range(0, len(indices), 3):
                i1 = indices[i] + 1
                i2 = indices[i+1] + 1
                i3 = indices[i+2] + 1
                out.write(f'f {i1}/{i1} {i3}/{i3} {i2}/{i2}\n')
        print(f'[ok] Exported {out_path} ({len(verts)} verts)')

def export_logo_meshes(env):
    for mesh_name in ['Logo', 'Logo_Shield']:
        _, verts, uvs, indices = unpack_mesh_data(env, mesh_name)
        out_path = f'godot/assets/models/{mesh_name}.obj'
        with open(out_path, 'w') as out:
            out.write(f'# Exported {mesh_name} (raw vt u v, reversed winding for det=-1)\n')
            out.write(f'o {mesh_name}\n')
            for vx, vy, vz in verts:
                # Map to Godot RH: gx = -vx * 0.05 ("CARD" on left), gy = vz * 0.05, gz = -vy * 0.05 (shield in front of swords)
                gx = -vx * 0.05
                gy = vz * 0.05
                gz = -vy * 0.05
                out.write(f'v {gx:.6f} {gy:.6f} {gz:.6f}\n')
            for u, v in uvs:
                out.write(f'vt {u:.6f} {v:.6f}\n')
            for i in range(0, len(indices), 3):
                i1 = indices[i] + 1
                i2 = indices[i+1] + 1
                i3 = indices[i+2] + 1
                out.write(f'f {i1}/{i1} {i3}/{i3} {i2}/{i2}\n')
        print(f'[ok] Exported {out_path} ({len(verts)} verts)')

def parse_anim_curves(anim_path):
    with open(anim_path, 'r') as f:
        text = f.read()

    rot_curves = {}
    if 'm_RotationCurves:' in text:
        rot_section = text.split('m_RotationCurves:')[1].split('m_CompressedRotationCurves:')[0]
        for c in rot_section.split('- curve:')[1:]:
            p_m = re.search(r'path:\s*([^\n\r]+)', c)
            val_m = re.search(r'time:\s*0\s*\n\s*value:\s*\{x:\s*([^,]+),\s*y:\s*([^,]+),\s*z:\s*([^,]+),\s*w:\s*([^}]+)\}', c)
            if p_m and val_m:
                rot_curves[p_m.group(1).strip()] = (
                    float(val_m.group(1)), float(val_m.group(2)), float(val_m.group(3)), float(val_m.group(4))
                )

    pos_curves = {}
    if 'm_PositionCurves:' in text:
        pos_section = text.split('m_PositionCurves:')[1].split('m_ScaleCurves:')[0]
        for c in pos_section.split('- curve:')[1:]:
            p_m = re.search(r'path:\s*([^\n\r]+)', c)
            val_m = re.search(r'time:\s*0\s*\n\s*value:\s*\{x:\s*([^,]+),\s*y:\s*([^,]+),\s*z:\s*([^}]+)\}', c)
            if p_m and val_m:
                pos_curves[p_m.group(1).strip()] = (
                    float(val_m.group(1)), float(val_m.group(2)), float(val_m.group(3))
                )

    return pos_curves, rot_curves

def parse_scene(scene_path):
    with open(scene_path, 'r') as f:
        text = f.read()

    blocks = text.split('--- !u!')
    go_names = {}
    transforms = {}
    smrs = {}

    for b in blocks:
        if b.startswith('1 &'):
            fid = b.split('\n')[0].split('&')[1].strip()
            name_m = re.search(r'm_Name:\s*([^\n\r]+)', b)
            if name_m:
                go_names[fid] = name_m.group(1).strip()
        elif b.startswith('4 &'):
            fid = b.split('\n')[0].split('&')[1].strip()
            goid_m = re.search(r'm_GameObject:\s*\{fileID:\s*(\d+)\}', b)
            father_m = re.search(r'm_Father:\s*\{fileID:\s*(\d+)\}', b)
            pos_m = re.search(r'm_LocalPosition:\s*\{x:\s*([^,]+),\s*y:\s*([^,]+),\s*z:\s*([^}]+)\}', b)
            rot_m = re.search(r'm_LocalRotation:\s*\{x:\s*([^,]+),\s*y:\s*([^,]+),\s*z:\s*([^,]+),\s*w:\s*([^}]+)\}', b)
            scale_m = re.search(r'm_LocalScale:\s*\{x:\s*([^,]+),\s*y:\s*([^,]+),\s*z:\s*([^}]+)\}', b)
            if goid_m and pos_m and rot_m:
                transforms[fid] = {
                    'goid': goid_m.group(1),
                    'father': father_m.group(1) if father_m else '0',
                    'pos': (float(pos_m.group(1)), float(pos_m.group(2)), float(pos_m.group(3))),
                    'rot': (float(rot_m.group(1)), float(rot_m.group(2)), float(rot_m.group(3)), float(rot_m.group(4))),
                    'scale': (float(scale_m.group(1)), float(scale_m.group(2)), float(scale_m.group(3))) if scale_m else (1.0, 1.0, 1.0),
                }
        elif b.startswith('137 &'):
            fid = b.split('\n')[0].split('&')[1].strip()
            goid_m = re.search(r'm_GameObject:\s*\{fileID:\s*(\d+)\}', b)
            bones_sec = b.split('m_Bones:')[1].split('m_BlendShapeWeights:')[0] if 'm_Bones:' in b else ''
            bone_fids = re.findall(r'fileID:\s*(\d+)', bones_sec)
            smrs[fid] = {
                'goid': goid_m.group(1) if goid_m else '0',
                'bones': bone_fids
            }

    return go_names, transforms, smrs

def bake_scene_characters(env):
    go_names, transforms, smrs = parse_scene(SCENE_PATH)
    finn_pos, finn_rot = parse_anim_curves('Assets/AnimationClip/Finn_CardIdle.anim')
    jake_pos, jake_rot = parse_anim_curves('Assets/AnimationClip/Jake_CardIdle.anim')

    def get_char_and_path(fid):
        parts = []
        curr = fid
        char_root = None
        while curr in transforms:
            if curr in ('229', '147'):
                char_root = curr
                break
            name = go_names.get(transforms[curr]['goid'], '')
            parts.append(name)
            curr = transforms[curr]['father']
        parts.reverse()
        return char_root, '/'.join(parts)

    world_matrices = {}
    def compute_world(fid):
        if fid in world_matrices:
            return world_matrices[fid]
        t = transforms[fid]
        char_root, rel_path = get_char_and_path(fid)
        pos = t['pos']
        rot = t['rot']
        scale = t['scale']
        if char_root == '229':
            if rel_path in finn_pos:
                pos = finn_pos[rel_path]
            if rel_path in finn_rot:
                rot = finn_rot[rel_path]
        elif char_root == '147':
            if rel_path in jake_pos:
                pos = jake_pos[rel_path]
            if rel_path in jake_rot:
                rot = jake_rot[rel_path]

        local_M = make_transform(pos, rot, scale)
        father = t['father']
        if father and father in transforms:
            world_M = mat_mul(compute_world(father), local_M)
        else:
            world_M = local_M
        world_matrices[fid] = world_M
        return world_M

    for fid in transforms:
        compute_world(fid)

    def skin_smr(smr_fid, mesh_name):
        bone_fids = smrs[smr_fid]['bones']
        mesh_obj, bind_verts, uvs, indices = unpack_mesh_data(env, mesh_name)
        bind_poses = []
        for bp in mesh_obj.m_BindPose:
            bind_poses.append([
                [bp.e00, bp.e01, bp.e02, bp.e03],
                [bp.e10, bp.e11, bp.e12, bp.e13],
                [bp.e20, bp.e21, bp.e22, bp.e23],
                [bp.e30, bp.e31, bp.e32, bp.e33],
            ])
        def_matrices = [mat_mul(world_matrices[bone_fids[i]], bind_poses[i]) for i in range(len(bone_fids))]

        posed_verts = []
        for i, v in enumerate(bind_verts):
            skin = mesh_obj.m_Skin[i]
            weights = [skin.weight_0_, skin.weight_1_, skin.weight_2_, skin.weight_3_]
            b_indices = [skin.boneIndex_0_, skin.boneIndex_1_, skin.boneIndex_2_, skin.boneIndex_3_]
            total_w = sum(weights)
            if total_w < 1e-6:
                weights = [1.0, 0.0, 0.0, 0.0]
            ux, uy, uz = 0.0, 0.0, 0.0
            for w, bi in zip(weights, b_indices):
                if w > 0.0001 and bi < len(def_matrices):
                    pt = transform_point(def_matrices[bi], v)
                    ux += pt[0] * w
                    uy += pt[1] * w
                    uz += pt[2] * w
            gx = ux * 0.05
            gy = uy * 0.05
            gz = -uz * 0.05
            posed_verts.append((gx, gy, gz))
        return posed_verts, uvs, indices

    def write_combined_obj(out_path, obj_name, parts):
        with open(out_path, 'w') as out:
            out.write(f'# Baked into Godot World Space from AdventureTimeEnvironmentChristmas.unity\n')
            # Single 'o' group so Godot imports all parts into surface 0!
            out.write(f'o {obj_name}\n')
            v_offset = 0
            for label, verts, uvs, indices in parts:
                for vx, vy, vz in verts:
                    out.write(f'v {vx:.6f} {vy:.6f} {vz:.6f}\n')
                for u, v in uvs:
                    out.write(f'vt {u:.6f} {v:.6f}\n')
                for i in range(0, len(indices), 3):
                    i1 = indices[i] + 1 + v_offset
                    i2 = indices[i+1] + 1 + v_offset
                    i3 = indices[i+2] + 1 + v_offset
                    out.write(f'f {i1}/{i1} {i3}/{i3} {i2}/{i2}\n')
                v_offset += len(verts)
        print(f'[ok] Wrote {out_path} ({v_offset} total verts)')

    # 1. Finn_Sitting.obj (Finn + Finn_Outline in single surface_0)
    finn_v, finn_uv, finn_idx = skin_smr('298', 'Finn')
    finno_v, finno_uv, finno_idx = skin_smr('302', 'Finn_Outline')
    write_combined_obj('godot/assets/models/Finn_Sitting.obj', 'Finn_Sitting', [
        ('Finn', finn_v, finn_uv, finn_idx),
        ('Finn_Outline', finno_v, finno_uv, finno_idx),
    ])

    # 2. Finn_Face.obj (M_MOUTH_0)
    finnf_v, finnf_uv, finnf_idx = skin_smr('304', 'M_MOUTH_0')
    write_combined_obj('godot/assets/models/Finn_Face.obj', 'Finn_Face', [
        ('Finn_Face', finnf_v, finnf_uv, finnf_idx),
    ])

    # 3. Jake_Sitting.obj (Jake + Jake_Outline + Jake_Eyelids + Jake_EyelidsOutline in single surface_0)
    jake_v, jake_uv, jake_idx = skin_smr('299', 'Jake')
    jakeo_v, jakeo_uv, jakeo_idx = skin_smr('303', 'Jake_Outline')
    jakel_v, jakel_uv, jakel_idx = skin_smr('300', 'Jake_Eyelids')
    jakelo_v, jakelo_uv, jakelo_idx = skin_smr('301', 'Jake_EyelidsOutline')
    write_combined_obj('godot/assets/models/Jake_Sitting.obj', 'Jake_Sitting', [
        ('Jake', jake_v, jake_uv, jake_idx),
        ('Jake_Outline', jakeo_v, jakeo_uv, jakeo_idx),
        ('Jake_Eyelids', jakel_v, jakel_uv, jakel_idx),
        ('Jake_EyelidsOutline', jakelo_v, jakelo_uv, jakelo_idx),
    ])

    # 4. Jake_Face.obj (M_MOUTH)
    jakef_v, jakef_uv, jakef_idx = skin_smr('305', 'M_MOUTH')
    write_combined_obj('godot/assets/models/Jake_Face.obj', 'Jake_Face', [
        ('Jake_Face', jakef_v, jakef_uv, jakef_idx),
    ])

    # 5. Finn_CardsHand.obj and Jake_CardsHand.obj (Card_1 .. Card_7 in single surface_0)
    finn_hold_M = world_matrices['171']
    jake_hold_M = mat_mul(world_matrices['242'], make_transform((0.0, 0.0, 0.0), (0.7071066, 0.0, 0.0, -0.707107)))

    for out_name, obj_label, hold_M in [
        ('godot/assets/models/Finn_CardsHand.obj', 'Finn_CardsHand', finn_hold_M),
        ('godot/assets/models/Jake_CardsHand.obj', 'Jake_CardsHand', jake_hold_M),
    ]:
        card_parts = []
        for c_idx in range(1, 8):
            m_name = f'Card_{c_idx}'
            _, c_verts, c_uvs, c_indices = unpack_mesh_data(env, m_name)
            posed_c_verts = []
            for v in c_verts:
                ux, uy, uz = transform_point(hold_M, v)
                posed_c_verts.append((ux * 0.05, uy * 0.05, -uz * 0.05))
            card_parts.append((m_name, posed_c_verts, c_uvs, c_indices))
        write_combined_obj(out_name, obj_label, card_parts)

def extract_dock_icons():
    # Find NGUI UIAtlas prefabs in Assets/ and extract the 2D dock icons
    prefabs = glob.glob('Assets/**/*.prefab', recursive=True)
    for pf in prefabs:
        with open(pf, 'r', errors='ignore') as f:
            txt = f.read()
        if 'mSprites:' not in txt:
            continue
        # Find sprite entries
        sprites = re.findall(
            r'-\s*name:\s*([^\n\r]+)\s*\n\s*x:\s*(\d+)\s*\n\s*y:\s*(\d+)\s*\n\s*width:\s*(\d+)\s*\n\s*height:\s*(\d+)',
            txt
        )
        if sprites:
            matching = [s for s in sprites if any(k in s[0].lower() for k in ('dungeon', 'portal', 'box', 'inventory', 'gem', 'chest', 'gear', 'setting', 'menu', 'icon'))]
            if matching:
                print(f'[atlas] {pf}: {matching[:15]}')

if __name__ == '__main__':
    fix_static_objs()
    env = UnityPy.load(GLOBAL_ASSETS)
    export_alphas_and_textures(env)
    export_logo_meshes(env)
    bake_scene_characters(env)
    extract_dock_icons()
