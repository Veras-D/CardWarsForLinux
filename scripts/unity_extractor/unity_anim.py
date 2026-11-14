#!/usr/bin/env python3
"""
unity_anim.py — Reusable Unity .anim curve parser & Godot GDScript Hermite spline generator.

Applies left-handed Unity to right-handed Godot S_Z reflection:
  - Rotation quaternion (x, y, z, w) & tangents -> Vector4(-x, -y, z, w)
  - Position Vector3 (x, y, z) & tangents        -> Vector3(x, y, -z)
  - Scale Vector3 (x, y, z) & tangents           -> Vector3(x, y, z)

Usage examples:
  # Inspect all curves in an .anim file (including root path "" and animated vs constant curves):
  python3 scripts/unity_extractor/unity_anim.py --info "Assets/AnimationClip/SinglePlayer_Idle(copy).anim"

  # Emit Godot GDScript const keyframe tables & Hermite evaluators for an .anim file:
  python3 scripts/unity_extractor/unity_anim.py --emit-gd "Assets/AnimationClip/SinglePlayer_Idle(copy).anim" --prefix IDLE
"""

import argparse
import re


def parse_clip(path: str) -> dict[tuple[str, str], list[tuple[float, list[float], list[float], list[float]]]]:
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        t = f.read()

    secs = {}
    section_Order = [
        "  m_RotationCurves:",
        "  m_CompressedRotationCurves:",
        "  m_EulerCurves:",
        "  m_PositionCurves:",
        "  m_ScaleCurves:",
        "  m_FloatCurves:",
        "  m_PPtrCurves:",
        "  m_SampleRate:",
    ]

    for short_name, header in (("rot", "  m_RotationCurves:"), ("pos", "  m_PositionCurves:"), ("scale", "  m_ScaleCurves:")):
        if header not in t:
            continue
        s = t.index(header)
        nxt_candidates = [t.index(h, s + len(header)) for h in section_Order if h != header and h in t[s + len(header) :]]
        nxt = min(nxt_candidates) if nxt_candidates else len(t)
        body = t[s:nxt]
        blocks = body.split("  - curve:")[1:]
        for b in blocks:
            pm = re.search(r"path:[ \t]*(.*)", b)
            path_str = pm.group(1).strip() if pm else ""
            keys = []
            for kb in re.split(r"\n\s*- serializedVersion: 2", b)[1:]:
                tm = float(re.search(r"time: ([-0-9.eE+]+)", kb).group(1))

                def vec(n: str) -> list[float]:
                    m = re.search(n + r": \{([^}]+)\}", kb)
                    return [float(x.split(":")[1]) for x in m.group(1).split(",")]

                keys.append((tm, vec("value"), vec("inSlope"), vec("outSlope")))
            secs[(short_name, path_str)] = keys
    return secs


def is_constant_curve(keys: list[tuple[float, list[float], list[float], list[float]]], tol: float = 1e-5) -> bool:
    if len(keys) <= 1:
        return True
    v0 = keys[0][1]
    for _, v, ins, outs in keys:
        if any(abs(v[i] - v0[i]) > tol for i in range(len(v0))):
            return False
        if any(abs(ins[i]) > tol or abs(outs[i]) > tol for i in range(len(v0))):
            return False
    return True


def sanitize_ident(path_str: str) -> str:
    if not path_str:
        return "ROOT"
    clean = re.sub(r"[^A-Za-z0-9_]", "_", path_str.split("/")[-1])
    return clean.upper()


def format_gd_curve(const_name: str, kind: str, keys: list) -> str:
    lines = [f"const {const_name} := ["]
    for tm, v, ins, outs in keys:
        if kind == "rot":
            lines.append(
                f"\t[{tm:.6f}, "
                f"Vector4({-v[0]:.6f}, {-v[1]:.6f}, {v[2]:.6f}, {v[3]:.6f}), "
                f"Vector4({-ins[0]:.6f}, {-ins[1]:.6f}, {ins[2]:.6f}, {ins[3]:.6f}), "
                f"Vector4({-outs[0]:.6f}, {-outs[1]:.6f}, {outs[2]:.6f}, {outs[3]:.6f})],"
            )
        elif kind == "pos":
            lines.append(
                f"\t[{tm:.6f}, "
                f"Vector3({v[0]:.6f}, {v[1]:.6f}, {-v[2]:.6f}), "
                f"Vector3({ins[0]:.6f}, {ins[1]:.6f}, {-ins[2]:.6f}), "
                f"Vector3({outs[0]:.6f}, {outs[1]:.6f}, {-outs[2]:.6f})],"
            )
        else:
            lines.append(
                f"\t[{tm:.6f}, "
                f"Vector3({v[0]:.6f}, {v[1]:.6f}, {v[2]:.6f}), "
                f"Vector3({ins[0]:.6f}, {ins[1]:.6f}, {ins[2]:.6f}), "
                f"Vector3({outs[0]:.6f}, {outs[1]:.6f}, {outs[2]:.6f})],"
            )
    lines.append("]")
    return "\n".join(lines)


HERMITE_HELPERS_GD = """
static func _eval_quat(keys: Array, t: float) -> Quaternion:
\tif t <= keys[0][0]:
\t\tvar v0: Vector4 = keys[0][1]
\t\treturn Quaternion(v0.x, v0.y, v0.z, v0.w).normalized()
\tvar last_idx := keys.size() - 1
\tif t >= keys[last_idx][0]:
\t\tvar vl: Vector4 = keys[last_idx][1]
\t\treturn Quaternion(vl.x, vl.y, vl.z, vl.w).normalized()
\tfor i in range(last_idx):
\t\tvar t0: float = keys[i][0]
\t\tvar t1: float = keys[i + 1][0]
\t\tif t >= t0 and t <= t1:
\t\t\tvar dt := t1 - t0
\t\t\tif dt <= 0.000001:
\t\t\t\tvar vc: Vector4 = keys[i][1]
\t\t\t\treturn Quaternion(vc.x, vc.y, vc.z, vc.w).normalized()
\t\t\tvar u := (t - t0) / dt
\t\t\tvar u2 := u * u
\t\t\tvar u3 := u2 * u
\t\t\tvar h00 := 2.0 * u3 - 3.0 * u2 + 1.0
\t\t\tvar h10 := u3 - 2.0 * u2 + u
\t\t\tvar h01 := -2.0 * u3 + 3.0 * u2
\t\t\tvar h11 := u3 - u2
\t\t\tvar p0: Vector4 = keys[i][1]
\t\t\tvar m0: Vector4 = keys[i][3] * dt
\t\t\tvar p1: Vector4 = keys[i + 1][1]
\t\t\tvar m1: Vector4 = keys[i + 1][2] * dt
\t\t\tvar r := p0 * h00 + m0 * h10 + p1 * h01 + m1 * h11
\t\t\treturn Quaternion(r.x, r.y, r.z, r.w).normalized()
\tvar vf: Vector4 = keys[0][1]
\treturn Quaternion(vf.x, vf.y, vf.z, vf.w).normalized()


static func _eval_vec3(keys: Array, t: float) -> Vector3:
\tif t <= keys[0][0]:
\t\treturn keys[0][1]
\tvar last_idx := keys.size() - 1
\tif t >= keys[last_idx][0]:
\t\treturn keys[last_idx][1]
\tfor i in range(last_idx):
\t\tvar t0: float = keys[i][0]
\t\tvar t1: float = keys[i + 1][0]
\t\tif t >= t0 and t <= t1:
\t\t\tvar dt := t1 - t0
\t\t\tif dt <= 0.000001:
\t\t\t\treturn keys[i][1]
\t\t\tvar u := (t - t0) / dt
\t\t\tvar u2 := u * u
\t\t\tvar u3 := u2 * u
\t\t\tvar h00 := 2.0 * u3 - 3.0 * u2 + 1.0
\t\t\tvar h10 := u3 - 2.0 * u2 + u
\t\t\tvar h01 := -2.0 * u3 + 3.0 * u2
\t\t\tvar h11 := u3 - u2
\t\t\tvar p0: Vector3 = keys[i][1]
\t\t\tvar m0: Vector3 = keys[i][3] * dt
\t\t\tvar p1: Vector3 = keys[i + 1][1]
\t\t\tvar m1: Vector3 = keys[i + 1][2] * dt
\t\t\treturn p0 * h00 + m0 * h10 + p1 * h01 + m1 * h11
\treturn keys[0][1]
"""


def main() -> None:
    ap = argparse.ArgumentParser(description="Inspect Unity .anim clips and emit Godot GDScript Hermite spline tables.")
    ap.add_argument("--info", metavar="ANIM_PATH", help="Print summary of all curves in the .anim file.")
    ap.add_argument("--emit-gd", metavar="ANIM_PATH", help="Emit GDScript const arrays for animated curves.")
    ap.add_argument("--prefix", default="ANIM", help="Prefix for emitted GDScript const names (default: ANIM).")
    ap.add_argument("--include-const", action="store_true", help="Also emit constant curves when using --emit-gd.")
    args = ap.parse_args()

    if args.info:
        secs = parse_clip(args.info)
        max_t = max((keys[-1][0] for keys in secs.values() if keys), default=0.0)
        print(f"AnimationClip: {args.info} (duration = {max_t:.6f}s, total curves = {len(secs)})")
        for (kind, path_str), keys in sorted(secs.items()):
            const = is_constant_curve(keys)
            status = "CONST" if const else "ANIM "
            v0 = [round(x, 4) for x in keys[0][1]]
            label = path_str if path_str else '<ROOT "">'
            print(f"  [{status}] {kind:5s}  {label:48s}  keys={len(keys):3d}  t={keys[0][0]:.3f}..{keys[-1][0]:.3f}  v0={v0}")

    if args.emit_gd:
        secs = parse_clip(args.emit_gd)
        max_t = max((keys[-1][0] for keys in secs.values() if keys), default=0.0)
        print(f"const {args.prefix}_DURATION := {max_t:.6f}\n")
        for (kind, path_str), keys in sorted(secs.items()):
            if not args.include_const and is_constant_curve(keys):
                continue
            cname = f"{args.prefix}_{kind.upper()}_{sanitize_ident(path_str)}"
            print(format_gd_curve(cname, kind, keys))
            print()
        print(HERMITE_HELPERS_GD)


if __name__ == "__main__":
    main()
