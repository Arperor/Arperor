extends CharacterBody2D

var esta_seleccionada = false

@onready var mi_sprite = $Sprite2D

func seleccionar():
	esta_seleccionada = true
	if mi_sprite: mi_sprite.modulate = Color.WHITE
	var borde = get_node_or_null("BordeVerde")
	if borde: borde.mostrar()

func deseleccionar():
	esta_seleccionada = false
	if mi_sprite: mi_sprite.modulate = Color.WHITE
	var borde = get_node_or_null("BordeVerde")
	if borde: borde.ocultar()

# En BuenoConstructor.gd
func orden_mover_a(posicion_mundo: Vector2):
	var ia = get_node_or_null("IABueno")
	if ia:
		ia.mover_a(posicion_mundo)
