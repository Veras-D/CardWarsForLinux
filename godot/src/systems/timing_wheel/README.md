# Timing Wheel System (Standalone Godot 4 Module)

A completely decoupled, customizable reaction roulette and timing wheel minigame system for Godot 4.

Designed following the **Systems-First** architecture: zero project-specific coupling, fully unit-testable in isolation, and ready to be dropped directly into any other Godot project (RPGs, casino minigames, combat clash wheels, loot spinners).

---

## Features

- **Custom Vector Graphics**: Procedural pie slice rendering with customizable colors, boundary lines, and animated needle with drop shadow.
- **Data-Driven Configuration (`WheelConfig.gd`)**:
  - Arbitrary number of sectors with custom IDs, names, ratios, multipliers, and colors.
  - Built-in factory presets for Card Wars Attacker, Defender, 50/50 Coin Flip, and RPG Loot Wheel.
  - Rotational speed control (degrees per second, clockwise or counter-clockwise).
- **Smooth Kinetics & Deceleration**:
  - Minimum spin duration to prevent premature instant taps.
  - Smooth deceleration curve when stopping.
- **Quick-Resolve Mode**:
  - Deterministic instantaneous roll mode for AI, automated simulations, or players who want to skip the spinner animation.
- **Isolated Testbed Scene (`testbed_wheel.tscn`)**:
  - Run the testbed directly to tweak parameters, test presets, and run 1,000-spin Monte Carlo tests.

---

## Quick Start / Integration

### 1. Instantiate the Spinner
```gdscript
var wheel_scene = preload("res://src/systems/timing_wheel/WheelSpinner.tscn")
var wheel = wheel_scene.instantiate() as WheelSpinner
add_child(wheel)
```

### 2. Configure Sectors & Speed
```gdscript
# Card Wars Attacker Reel (80% Hit, 7% Crit, 13% Miss)
var config = WheelConfig.create_card_wars_attacker(0.80, 0.07)
wheel.setup(config)

# Connect signals
wheel.spin_completed.connect(_on_wheel_result)
wheel.start_spin()
```

### 3. Handle the Result
```gdscript
func _on_wheel_result(result: Dictionary) -> void:
    print("Landed on: ", result.name)        # "CRITICAL HIT!"
    print("Damage Multiplier: ", result.multiplier) # 2.0
    print("Final Angle: ", result.angle_deg) # 45.2°
```

---

## Extracting to Another Godot Project

Simply copy the entire `godot/src/systems/timing_wheel/` directory into your new project's folder. No external dependencies or addons required!
