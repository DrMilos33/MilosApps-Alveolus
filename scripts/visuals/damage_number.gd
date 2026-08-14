class_name DamageNumber
extends Node2D

signal finished(number: DamageNumber)

const LIFETIME := 0.55

var amount: float = 0.0
var remaining: float = LIFETIME

func configure(value: float) -> void:
	amount = value
	remaining = LIFETIME
	show()
	set_process(true)
	queue_redraw()

func recycle() -> void:
	set_process(false)
	hide()

func _process(delta: float) -> void:
	remaining -= delta
	position.y -= 34.0 * delta
	queue_redraw()
	if remaining <= 0.0:
		recycle()
		finished.emit(self)

func _draw() -> void:
	var alpha := clampf(remaining / LIFETIME, 0.0, 1.0)
	var text := str(roundi(amount))
	draw_string(ThemeDB.fallback_font, Vector2(-18.0, -20.0), text, HORIZONTAL_ALIGNMENT_CENTER, 36.0, 14, Color(0.90, 1.0, 0.98, alpha))
