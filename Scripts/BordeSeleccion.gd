extends Node2D

@export var color_borde: Color = Color.GREEN
@export var grosor: float = 3.0
@export var tamano: Vector2 = Vector2(64, 64)

func _ready():
	visible = false
	queue_redraw()

func _draw():
	if visible:
		var rect = Rect2(-tamano / 2, tamano)
		draw_rect(rect, color_borde, false, grosor)

func mostrar():
	visible = true
	queue_redraw()

func ocultar():
	visible = false
