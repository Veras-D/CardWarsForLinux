class_name FionnaCakeBook
extends Node3D

@onready var book_spine: MeshInstance3D = get_node_or_null("BookSpine")
@onready var book_end: MeshInstance3D = get_node_or_null("BookEnd")
@onready var book_page3: MeshInstance3D = get_node_or_null("BookPage3")
@onready var book_page2: MeshInstance3D = get_node_or_null("BookPage2")
@onready var book_page1: MeshInstance3D = get_node_or_null("BookPage1")
@onready var book_cover: MeshInstance3D = get_node_or_null("BookCover")

var open_tween: Tween = null
var is_open: bool = false

# Target open angles (in degrees, negative around X opens towards left)
const COVER_OPEN_ANGLE := -115.0
const PAGE1_OPEN_ANGLE := -110.0
const PAGE2_OPEN_ANGLE := -106.0
const PAGE3_OPEN_ANGLE := -102.0

func _ready() -> void:
	close_book(0.0)

func open_book(duration: float = 0.55) -> void:
	is_open = true
	if open_tween and open_tween.is_valid():
		open_tween.kill()
	
	open_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	if book_cover:
		open_tween.tween_property(book_cover, "rotation_degrees:x", COVER_OPEN_ANGLE, duration).set_delay(0.0)
	if book_page1:
		open_tween.tween_property(book_page1, "rotation_degrees:x", PAGE1_OPEN_ANGLE, duration * 0.95).set_delay(duration * 0.05)
	if book_page2:
		open_tween.tween_property(book_page2, "rotation_degrees:x", PAGE2_OPEN_ANGLE, duration * 0.90).set_delay(duration * 0.10)
	if book_page3:
		open_tween.tween_property(book_page3, "rotation_degrees:x", PAGE3_OPEN_ANGLE, duration * 0.85).set_delay(duration * 0.15)

func close_book(duration: float = 0.22) -> void:
	is_open = false
	if open_tween and open_tween.is_valid():
		open_tween.kill()
	
	if duration <= 0.0:
		if book_cover: book_cover.rotation_degrees.x = 0.0
		if book_page1: book_page1.rotation_degrees.x = 0.0
		if book_page2: book_page2.rotation_degrees.x = 0.0
		if book_page3: book_page3.rotation_degrees.x = 0.0
		return
	
	open_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if book_cover:
		open_tween.tween_property(book_cover, "rotation_degrees:x", 0.0, duration)
	if book_page1:
		open_tween.tween_property(book_page1, "rotation_degrees:x", 0.0, duration)
	if book_page2:
		open_tween.tween_property(book_page2, "rotation_degrees:x", 0.0, duration)
	if book_page3:
		open_tween.tween_property(book_page3, "rotation_degrees:x", 0.0, duration)
