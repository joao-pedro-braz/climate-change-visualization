extends Node


enum PausedState {
	PAUSED_DRAGGING,
	PAUSED_BUTTON,
	NONE
}


const TEMPERATURE_DATA := preload("res://data/GLB.Ts+dSST.csv").records
const RADIUS := 250.0
const BEZIER_SEGMENTS := 20.0
const ROUNDNESS := 1.2
const COLD_COLOR := Color(0.392157, 0.584314, 0.929412, 0.4)
const NEUTRAL_COLOR := Color(1, 1, 1, 0.4)
const HOT_COLOR := Color(0.862745, 0.0784314, 0.235294, 0.4)


@onready var year_label := $MarginContainer/CenterContainer/VBoxContainer/CenterContainer/Control/YearLabel
@onready var line_2d := $MarginContainer/CenterContainer/VBoxContainer/CenterContainer/Control/Line2D
@onready var slider := $MarginContainer/CenterContainer/VBoxContainer/VBoxContainer/HBoxContainer/HSlider
@onready var play_button := $MarginContainer/CenterContainer/VBoxContainer/VBoxContainer/HBoxContainer/PlayButton
@onready var speed_label := $MarginContainer/CenterContainer/VBoxContainer/VBoxContainer/HBoxContainer2/SpeedLabel
@onready var half_speed_multiplier_button := $MarginContainer/CenterContainer/VBoxContainer/VBoxContainer/HBoxContainer2/HalfSpeedButton
@onready var double_speed_multiplier_button := $MarginContainer/CenterContainer/VBoxContainer/VBoxContainer/HBoxContainer2/DoubleSpeedButton
@onready var background := $MarginContainer/CenterContainer/VBoxContainer/CenterContainer/Control/Background


var _idx := 0
var _paused := PausedState.NONE:
	set(value):
		_paused = value
		play_button.set_pressed_no_signal(_paused != PausedState.NONE)
var _busy := false
var _relative_idx: float:
	get:
		return 1.0 / (TEMPERATURE_DATA.size() * 12.0 - 12.0)
var _speed_multiplier := 1.0:
	set(value):
		value = min(max(value, 1.0), 8.0)
		
		half_speed_multiplier_button.disabled = is_equal_approx(value, 1.0)
		half_speed_multiplier_button.modulate = Color.DARK_GRAY if half_speed_multiplier_button.disabled else Color.WHITE
		double_speed_multiplier_button.disabled = is_equal_approx(value, 8.0)
		double_speed_multiplier_button.modulate = Color.DARK_GRAY if double_speed_multiplier_button.disabled else Color.WHITE
		
		_speed_multiplier = value
		speed_label.text = ("x%s" % int(_speed_multiplier)) if _speed_multiplier > 0 else ("-x%s" % abs(_speed_multiplier))
var _speed: float:
	get:
		return _speed_multiplier * 10.0


func _ready() -> void:
	_speed_multiplier = 1.0
	_paused = PausedState.NONE
	_reset()


func _process(_delta: float) -> void:
	if _idx >= TEMPERATURE_DATA.size():
		_busy = false
		if _paused == PausedState.NONE:
			_paused = PausedState.PAUSED_BUTTON
		return
	
	if _paused != PausedState.NONE or _busy:
		return
	
	_busy = true
	await _build()
	_busy = false
	_idx += 1


func _build(should_wait = true) -> void:
	var data: Dictionary = TEMPERATURE_DATA[_idx]
	year_label.text = str(data.Year)
	for month in 12:
		var variation_from: float = data[data.keys()[month + 1]]
		var variation_to: float = data[data.keys()[month + 2]]
		
		# If this is the last month, we need to handle the next point "specially"
		# Since it belongs to next Year.
		if month == 11 and _idx < TEMPERATURE_DATA.size() - 1:
			variation_to = TEMPERATURE_DATA[_idx + 1][data.keys()[1]]
	
		var direction_from := Vector2.from_angle(
			TAU / 12 * month - PI / 2.0
		) * RADIUS * ((2.0 + variation_from) / 3.0)
		var direction_to := Vector2.from_angle(
			TAU / 12 * (month + 1) - PI / 2.0
		) * RADIUS * ((2.0 + variation_to) / 3.0)
		
		await _make_arc(
			direction_from,
			direction_to,
			month,
			should_wait and _paused == PausedState.NONE
		)
		
		if should_wait and _paused == PausedState.NONE and _speed > BEZIER_SEGMENTS and fmod(month, _speed_multiplier) == 0.0:
			slider.value = _relative_idx * float(_idx * 12 + month) * 100.0
			await get_tree().process_frame


func _reset() -> void:
	year_label.text = str(TEMPERATURE_DATA[0].Year)
	_idx = 0
	line_2d.clear_points()


func _make_arc(p0: Vector2, p1: Vector2, month: int, should_wait: bool) -> void:
	for i in BEZIER_SEGMENTS:
		if _paused == PausedState.PAUSED_DRAGGING:
			return
		
		var point := _quadratic_bezier(
			p0,
			(p0 + p1) * 0.5 * ROUNDNESS,
			p1,
			i / BEZIER_SEGMENTS
		)
		line_2d.add_point(point)
		
		if should_wait and _speed <= BEZIER_SEGMENTS and fmod(i, _speed) == 0.0:
			slider.value = _relative_idx * float(_idx * 12 + month) * 100.0
			await get_tree().process_frame


func _quadratic_bezier(p0: Vector2, p1: Vector2, p2: Vector2, t: float) -> Vector2:
	var q0 = p0.lerp(p1, t)
	var q1 = p1.lerp(p2, t)
	var r = q0.lerp(q1, t)
	return r


func _on_slider_drag_ended(_value_changed: bool) -> void:
	var idx = floori((slider.value / 100.0 / _relative_idx) / 12.0)
	
	if _paused == PausedState.PAUSED_DRAGGING:
		_paused = PausedState.NONE
	
	_busy = true
	_reset()
	for i in idx:
		_idx = i
		await _build(false)
	_idx += 1
	_busy = false


func _on_slider_drag_started() -> void:
	if _paused == PausedState.NONE:
		_paused = PausedState.PAUSED_DRAGGING
	var value: float = slider.value
	await get_tree().process_frame
	slider.value = value


func _on_play_button_toggled(button_pressed: bool) -> void:
	if is_equal_approx(slider.value, 100.0):
		slider.value = 0.0
		_on_slider_drag_ended(false)
	_paused = PausedState.PAUSED_BUTTON if button_pressed else PausedState.NONE


func _on_half_speed_button_pressed() -> void:
	if is_equal_approx(_speed_multiplier, 1.0):
		_speed_multiplier = -1.0
	elif _speed_multiplier <= 1.0:
		_speed_multiplier *= 2.0
	else:
		_speed_multiplier /= 2.0


func _on_double_speed_button_pressed() -> void:
	if is_equal_approx(_speed_multiplier, -1.0):
		_speed_multiplier = 1.0
	elif _speed_multiplier < 1.0:
		_speed_multiplier /= 2.0
	else:
		_speed_multiplier *= 2.0


func _open_url(url) -> void:
	OS.shell_open(url)
