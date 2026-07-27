extends Node

var menu_scene = preload("res://Escenas/menu_principal.tscn")
var juego_scene = preload("res://Escenas/mapa.tscn")
var estado_actual = "MENU"

# NO llames a cambiar_a_menu() en _ready()

func cambiar_a_menu():
	estado_actual = "MENU"
	# Limpiar estado global antes de cambiar de escena
	if EconomiaManager:
		EconomiaManager.resetear()
	get_tree().change_scene_to_packed.call_deferred(menu_scene)

func cambiar_a_juego():
	estado_actual = "PLAYING"
	get_tree().change_scene_to_packed.call_deferred(juego_scene)
