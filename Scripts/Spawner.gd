extends Node2D

@export var escena_enemigo: PackedScene
@export var enemigos_iniciales: int = 10
@export var limite_poblacion_malos: int = 60
@export var limite_x: int = 9000  # ← POSITIVO (magnitud)
@export var limite_y: int = 9000  # ← POSITIVO (magnitud)
@export var incremento_horda: int = 5  # Cuántos enemigos extra se suman en cada horda

# Spawn en borde
@export var spawn_rate_borde: float = 1.0
@export var cantidad_grupo_borde: int = 1

# Spawn en anillo (NUEVO)
@export var spawn_rate_anillo: float = 0.5  # intentos por segundo
@export var cantidad_grupo_anillo: int = 2
@export var min_distancia_anillo: float = 200.0  # Distancia mínima de lo explorado
@export var max_distancia_anillo: float = 400.0  # Distancia máxima de lo explorado

# Variación
@export var variacion_temporizador: float = 0.2
@export var intervalo_horda: float = 60.0  # Segundos entre hordas
@export var tamano_horda: int = 10
@export var tiempo_inicio_hordas: float = 120.0 

@onready var niebla = get_node_or_null("/root/Mapa/NieblaDeGuerra")

var tamano_horda_actual: int = 0
var hordas_lanzadas: int = 0
var celdas_exploradas_cache: Array = []
var necesita_actualizar_cache: bool = true
var temporizador_borde: float = 0.0
var temporizador_anillo: float = 0.0
var siguiente_intervalo_borde: float = 0.0
var siguiente_intervalo_anillo: float = 0.0
var timer_horda: float = 0.0
var hordas_activas: bool = false
var flowfield_manager = null

func _ready():
	for i in range(enemigos_iniciales):
		var pos = _buscar_posicion_spawn_valida()
		if pos != Vector2.ZERO:
			_instanciar_enemigo(pos)
	
	# Inicializar intervalos (tu código existente)
	var base_borde = 1.0 / spawn_rate_borde if spawn_rate_borde > 0 else 999.0
	var base_anillo = 1.0 / spawn_rate_anillo if spawn_rate_anillo > 0 else 999.0
	siguiente_intervalo_borde = base_borde + _variacion(base_borde)
	siguiente_intervalo_anillo = base_anillo + _variacion(base_anillo)
	temporizador_borde = randf_range(0, siguiente_intervalo_borde)
	temporizador_anillo = randf_range(0, siguiente_intervalo_anillo)
	flowfield_manager = get_node_or_null("/root/FlowfieldManager")
	if flowfield_manager:
		call_deferred("_calcular_flowfield_inicial")
		tamano_horda_actual = tamano_horda

func _process(delta):
	var enemigos_actuales = get_tree().get_nodes_in_group("malos").size()
	if enemigos_actuales >= limite_poblacion_malos:
		return

	# Spawn de borde
	temporizador_borde += delta
	if temporizador_borde >= siguiente_intervalo_borde:
		_spawn_grupo_borde()
		temporizador_borde = 0.0
		var base = 1.0 / spawn_rate_borde if spawn_rate_borde > 0 else 999.0
		siguiente_intervalo_borde = base + _variacion(base)

	# Spawn en anillo (NUEVO)
	temporizador_anillo += delta
	if temporizador_anillo >= siguiente_intervalo_anillo:
		_spawn_grupo_anillo()
		temporizador_anillo = 0.0
		var base = 1.0 / spawn_rate_anillo if spawn_rate_anillo > 0 else 999.0
		siguiente_intervalo_anillo = base + _variacion(base)
	if EconomiaManager.base_construida:
		if not hordas_activas:
			# Iniciar temporizador después de construir la base
			timer_horda += delta
			if timer_horda >= tiempo_inicio_hordas:
				hordas_activas = true
				timer_horda = intervalo_horda  # Primera horda inmediata
		else:
			timer_horda += delta
			if timer_horda >= intervalo_horda:
				spawnear_horda()
				timer_horda = 0.0

func _variacion(intervalo_base: float) -> float:
	return randf_range(-variacion_temporizador * intervalo_base, variacion_temporizador * intervalo_base)

# --- Spawn en borde ---
func _spawn_grupo_borde():
	for i in range(cantidad_grupo_borde):
		if get_tree().get_nodes_in_group("malos").size() >= limite_poblacion_malos:
			break
		var pos = _obtener_punto_borde()
		_instanciar_enemigo(pos)

func _obtener_punto_borde() -> Vector2:
	var lado = randi() % 4
	match lado:
		0: return Vector2(randf_range(-limite_x, limite_x), -limite_y)
		1: return Vector2(randf_range(-limite_x, limite_x), limite_y)
		2: return Vector2(-limite_x, randf_range(-limite_y, limite_y))
		_: return Vector2(limite_x, randf_range(-limite_y, limite_y))

# --- Spawn en ANILLO (NUEVO) ---
func _spawn_grupo_anillo():
	if not niebla:
		return
	
	for i in range(cantidad_grupo_anillo):
		if get_tree().get_nodes_in_group("malos").size() >= limite_poblacion_malos:
			break
		
		var pos = _buscar_posicion_en_anillo()
		if pos != Vector2.ZERO:
			_instanciar_enemigo(pos)

# NUEVO: Buscar posición en el anillo alrededor de zonas visibles
func _buscar_posicion_spawn_valida() -> Vector2:
	var intentos = 0
	var max_intentos = 50
	var generador = get_node_or_null("/root/Mapa/GeneradorRecursos")
	
	while intentos < max_intentos:
		intentos += 1
		var pos = Vector2(randf_range(-limite_x, limite_x), randf_range(-limite_y, limite_y))
		
		if generador and generador.puede_moverse_a(pos):
			return pos
	
	# Fallback: devolver una posición cualquiera si no encuentra válida
	return Vector2(randf_range(-limite_x, limite_x), randf_range(-limite_y, limite_y))

func _buscar_posicion_en_anillo() -> Vector2:
	var intentos = 0
	var max_intentos = 30
	var generador = get_node_or_null("/root/Mapa/GeneradorRecursos")
	
	while intentos < max_intentos:
		intentos += 1
		
		var celda_base = _encontrar_celda_explorada_aleatoria()
		if celda_base == Vector2(-1, -1):
			continue
		
		var angulo = randf() * TAU
		var distancia = randf_range(min_distancia_anillo, max_distancia_anillo)
		var pos = niebla._celda_a_pos(celda_base) + Vector2(cos(angulo), sin(angulo)) * distancia
		
		# Verificar que esté en zona OSCURO
		var celda_pos = niebla._pos_a_celda(pos)
		var index = int(celda_pos.y) * niebla.celdas_ancho + int(celda_pos.x)
		
		if index >= 0 and index < niebla.grid.size():
			if niebla.grid[index] == 0:  # OSCURO
				# NUEVO: Verificar que el terreno sea transitable
				if generador and generador.puede_moverse_a(pos):
					return pos
	
	return Vector2.ZERO

# NUEVO: Encontrar una celda VISIBLE o RECORDADO aleatoria
func _encontrar_celda_explorada_aleatoria() -> Vector2:
	if not niebla or niebla.grid.size() == 0:
		return Vector2(-1, -1)
	
	# Recopilar todas las celdas exploradas
	if necesita_actualizar_cache:
		celdas_exploradas_cache.clear()
		for i in range(niebla.grid.size()):
			if niebla.grid[i] == 1 or niebla.grid[i] == 2:
				celdas_exploradas_cache.append(i)
		necesita_actualizar_cache = false
	
	if celdas_exploradas_cache.size() == 0:
		return Vector2(-1, -1)
	
	# Elegir una aleatoria
	var index = celdas_exploradas_cache[randi() % celdas_exploradas_cache.size()]
	var x = index % niebla.celdas_ancho
	var y = index / niebla.celdas_ancho
	return Vector2(x, y)

# --- Instanciar enemigo ---
func _instanciar_enemigo(pos: Vector2):
	if escena_enemigo == null:
		push_warning("Spawner: escena_enemigo es null")
		return
	
	# Verificar que la posición sea válida
	if pos == Vector2.ZERO:
		push_warning("Spawner: posición inválida (0, 0)")
		return
	
	# Verificar límites del mapa
	if pos.x < -limite_x or pos.x > limite_x or pos.y < -limite_y or pos.y > limite_y:
		push_warning("Spawner: posición fuera de límites: ", pos)
		return
	var malo = escena_enemigo.instantiate()
	malo.global_position = pos
	add_child(malo)
	# --- VARIANTE RÁPIDA (10% de probabilidad) ---

	if not malo.is_in_group("malos"):
		malo.add_to_group("malos")
		
	if randf() < 0.1:
		var stats_malo = malo.get_node_or_null("Stats")
		if stats_malo:
			stats_malo.velocidad_movimiento *= 2.0
		# Color rojizo para distinguirlo visualmente
			malo.modulate = Color(1.3, 0.6, 0.6, 1.0)

func spawnear_horda():
	hordas_lanzadas += 1
	for i in range(tamano_horda_actual):
		var pos = _buscar_posicion_en_anillo()
		_instanciar_enemigo_horda(pos)
	# Aumentar el tamaño para la siguiente horda
	tamano_horda_actual += incremento_horda

func _instanciar_enemigo_horda(pos: Vector2):
	if escena_enemigo == null:
		return
	
	var malo = escena_enemigo.instantiate()
	malo.global_position = pos
	add_child(malo)
	
	if not malo.is_in_group("malos"):
		malo.add_to_group("malos")
	
	# Marcar como parte de horda
	if malo.has_node("IA"):
		var ia = malo.get_node("IA")
		ia.es_horda = true
		ia.estado_actual = ia.Estado.HORDA  # NUEVO: Asignar estado HORDA
		
		# NUEVO: Asignar la base como objetivo
		var base = null
		for bueno in get_tree().get_nodes_in_group("buenos"):
			if bueno.get("tipo_edificio") == "Base":
				base = bueno
				break
		
		if base:
			ia.objetivo = base

func _calcular_flowfield_inicial():
	# Esperar a que la base exista
	var base = null
	for bueno in get_tree().get_nodes_in_group("buenos"):
		if bueno.get("tipo_edificio") == "Base":
			base = bueno
			break
	
	if base and flowfield_manager:
		flowfield_manager.calcular_flowfield(base.global_position)
