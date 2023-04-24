@tool
extends Node2D


const DefaultLabelSettings := preload("res://main/background/resources/label_settings/default.tres")
const ExpectedtLabelSettings := preload("res://main/background/resources/label_settings/expected.tres")
const DefaultLine2D := preload("res://main/background/resources/line2d/default.tscn")
const ExpectedLine2D := preload("res://main/background/resources/line2d/expected.tscn")

const RADIUS := 250.0
const MONTH_RADIUS := RADIUS + 40.0
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const UPPER_VARIATION := "  +1°C  "
const NO_VARIATION := "  0°C  "
const LOWER_VARIATION := "  -1°C  "


@export var rebuild: bool:
	set(value):
		_build()


func _ready() -> void:
	_build()


func _build() -> void:
	$Labels.get_children().map(func(child: Node): child.queue_free())
	$Lines.get_children().map(func(child: Node): child.queue_free())

	for month_idx in MONTHS.size():
		var label := _make_label(MONTHS[month_idx])
		$Labels.add_child(label)
		label.position = Vector2.from_angle(TAU / MONTHS.size() * month_idx - PI / 2.0) \
			* MONTH_RADIUS - label.size * 0.5
	
	var circles := [
		[LOWER_VARIATION, [DefaultLabelSettings, DefaultLine2D]],
		[NO_VARIATION, [ExpectedtLabelSettings, ExpectedLine2D]],
		[UPPER_VARIATION, [DefaultLabelSettings, DefaultLine2D]],
	]
	for circle_idx in circles.size():
		var line: Line2D = (circles[circle_idx][1][1] as PackedScene).instantiate()
		$Lines.add_child(line)
		
		var radius := RADIUS * (float(circle_idx + 1) / circles.size())
		
		var label := _make_label(circles[circle_idx][0], circles[circle_idx][1][0])
		$Labels.add_child(label)
		label.position = Vector2(0.0, -radius) - label.size * 0.5
	
		var segments := ceili(TAU * radius * 2.0)
		for i in (segments + 2):
			var point := Vector2.from_angle(TAU / segments * (i % segments) - PI / 2.0) * radius
			if label.get_rect().has_point(point):
				continue
			line.add_point(point, i)


func _make_label(text: String, label_settings: LabelSettings = DefaultLabelSettings) -> Label:
	var label := Label.new()
	label.label_settings = label_settings
	label.text = text
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label
