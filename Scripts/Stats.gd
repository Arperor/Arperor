extends Node

signal muriendo
signal stats_cambiados(vida_actual: int, vida_maxima: int)
@export var vida_maxima: int = 100
var vida_actual: int

@export var dany: int = 10
@export var cooldown_ataque: float = 1.0
@export var rango_ataque_tiles: float = 1.0
@export var escena_proyectil: PackedScene  # Arrastra aquí Proyectil.tscn desde el Inspector
@export var velocidad_movimiento: float = 150.0
@export var rango_vision_tiles: float = 15.0
@export var tamano_tile: float = 64.0

@export var categoria: String = "SinCategoria"

func _ready():
	vida_actual = vida_maxima

func get_rango_vision_px() -> float:
	return rango_vision_tiles * tamano_tile

func get_rango_ataque_px() -> float:
	return rango_ataque_tiles * tamano_tile

func rebre_dany(quantitat: int):
	# NUEVO: Si el padre ya murió, ignorar daño
	if get_parent().get("ya_murio") == true:
		return
	
	vida_actual -= quantitat
	stats_cambiados.emit(vida_actual, vida_maxima)
	
	if vida_actual <= 0:
		morir()

func morir():
	# NUEVO: Si el padre ya murió, no hacer nada
	if get_parent().get("ya_murio") == true:
		return
	
	print(name, " ha mort!")
	Eventos.enemigo_muerto.emit(categoria)
	muriendo.emit()
	
	# Si es un edificio, llamar a su función morir()
	if get_parent().get("tipo_edificio"):
		get_parent().morir()
		return
	
	# Si es una unidad, borrarla normalmente
	if get_parent().is_in_group("buenos"):
		get_parent().queue_free()
		call_deferred("_verificar_game_over")
	else:
		get_parent().queue_free()

func _verificar_game_over():
	# Esperar 1 segundo para que el jugador vea la muerte
	await get_tree().create_timer(1.0).timeout
	
	# Contar cuántos buenos quedan vivos
	var buenos_vivos = get_tree().get_nodes_in_group("buenos")
	
	# Si no queda ninguno, volver al menú
	if buenos_vivos.size() == 0:
		await get_tree().create_timer(1.0).timeout
		GameManager.cambiar_a_menu()
func construir(quantitat: int):
	# Sumar vida en lugar de restar
	vida_actual += quantitat
	stats_cambiados.emit(vida_actual, vida_maxima)
	
	# Limitar a vida máxima
	if vida_actual > vida_maxima:
		vida_actual = vida_maxima
