@tool
extends Node


const TEMPERATURE_DATA := preload("res://data/GLB.Ts+dSST.csv").records
const RADIUS := 250.0
const FRAMES_PER_SECOND := 30.0
const ROUNDNESS := 1.2
const COLD_COLOR := Color(0.392157, 0.584314, 0.929412, 0.4)
const NEUTRAL_COLOR := Color(1, 1, 1, 0.4)
const HOT_COLOR := Color(0.862745, 0.0784314, 0.235294, 0.4)


@onready var year_label := $MarginContainer/CenterContainer/VBoxContainer/CenterContainer/Control/YearLabel
@onready var line_2d := $MarginContainer/CenterContainer/VBoxContainer/CenterContainer/Control/Line2D


var _idx := 0
var _last_tick := 0


func _ready() -> void:
	line_2d.clear_points()
	line_2d.gradient = Gradient.new()
	line_2d.gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	
	while _idx < TEMPERATURE_DATA.size() - 1:
		await  _build()
		_idx += 1
	
	if not Engine.is_editor_hint():
		get_tree().quit()


func _build() -> void:
	if _idx >= TEMPERATURE_DATA.size() - 1:
		return
	
	var data: Dictionary = TEMPERATURE_DATA[_idx]
	year_label.text = str(data.Year)
	for month in 11:
		_make_arc(month, month + 1, data)
		if month == 10:
			var variation: float = data[data.keys()[11 + 2]]
			var gradient: Gradient = line_2d.gradient
			gradient.add_point(
				float(_idx + 11 + 2) / float(TEMPERATURE_DATA.size()),
				COLD_COLOR if variation < -0.2 else (HOT_COLOR if variation > 0.2 else (COLD_COLOR.lerp(HOT_COLOR, (variation + 1) / 2.0) + NEUTRAL_COLOR) / 2.0)
			)
		
		if month % 4 == 0:
			await get_tree().create_timer(0.001).timeout
	await get_tree().create_timer(1.0 / FRAMES_PER_SECOND).timeout


func _make_arc(from: float, to: float, data: Dictionary) -> void:
	var variation_from: float = data[data.keys()[from + 1]]
	var variation_to: float = data[data.keys()[from + 2]]
	
	var gradient: Gradient = line_2d.gradient
	gradient.add_point(
		float(_idx + from + 2) / float(TEMPERATURE_DATA.size()),
		COLD_COLOR if variation_from < -0.2 else (HOT_COLOR if variation_from > 0.2 else (COLD_COLOR.lerp(HOT_COLOR, (variation_from + 1) / 2.0) + NEUTRAL_COLOR) / 2.0)
	)
	
	var direction_from := Vector2.from_angle(TAU / 12 * from - PI / 2.0) * RADIUS * (2.0 + variation_from) / 3.0
	var direction_to := Vector2.from_angle(TAU / 12 * to - PI / 2.0) * RADIUS * (2.0 + variation_to) / 3.0
	
	for i in 100:
		var point := _quadratic_bezier(
			direction_from,
			(direction_from + direction_to) * 0.5 * ROUNDNESS,
			direction_to,
			i / 100.0
		)
		line_2d.add_point(point)


func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var q0 = p0.lerp(p1, t)
	var q1 = p1.lerp(p2, t)
	var r = q0.lerp(q1, t)
	return r
