class_name BoardHitboxButton
extends Button

var hit_tester: Callable = Callable()


func _has_point(point: Vector2) -> bool:
	if not Rect2(Vector2.ZERO, size).has_point(point):
		return false
	if hit_tester.is_valid():
		return bool(hit_tester.call(get_global_transform_with_canvas() * point))
	return true
