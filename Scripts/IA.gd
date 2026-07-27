extends Node2D

# Máquina de estados
enum Estado { DEAMBULAR, PERSEGUIR, INACTIVO, HORDA }
var estado_actual = Estado.DEAMBULAR

# Referencias
@onready var stats = get_parent().get_node("Stats")
var objetivo = null
var buenos_atrayentes = []
var intensidad_actual: float = 0.0
@export var umbral_cambio: float = 0.15  # Diferencia mínima para "robar" atención
# Configuración
@export var limite_x: float = 2800.0
@export var limite_y: float = 2800.0
@export var distancia_activacion: float = 1500.0
@export var intervalo_despertar: float = 8.0
@export var probabilidad_despertar: float = 0.3
@export var duracion_despertar: float = 2.0

# Variables internas
var direccion = Vector2.ZERO
var timer_ataque: float = 0.0
var timer_verificacion: float = 0.0
var timer_despertar: float = 0.0
var tiempo_despierto: float = 0.0
var esta_despierto_temporal: bool = false
var es_horda: bool = false
var flowfield_manager = null

func _ready():
	direccion = Vector2(randf() * 2 - 1, randf() * 2 - 1).normalized()
	flowfield_manager = get_node_or_null("/root/FlowfieldManager")

func _physics_process(delta):
	if not is_instance_valid(stats):
		return
	
	timer_verificacion += delta
	if timer_verificacion > 0.5:
		_verificar_activacion()
		timer_verificacion = 0.0
	
	if estado_actual == Estado.INACTIVO:
		_gestionar_despertar_temporal(delta)
		return
	
	if estado_actual == Estado.DEAMBULAR:
		deambular()
		get_parent().velocity = direccion * _obtener_velocidad_real()
	elif estado_actual == Estado.PERSEGUIR:
		perseguir(delta)
	elif estado_actual == Estado.HORDA:
		comportamiento_horda(delta)
	
	get_parent().move_and_slide()

func _gestionar_despertar_temporal(delta):
	if esta_despierto_temporal:
		tiempo_despierto -= delta
		deambular()
		
		# NUEVO: Verificar si puede moverse
		var pos_siguiente = get_parent().global_position + direccion * 32.0
		if _puede_moverse_a(pos_siguiente):
			get_parent().velocity = direccion * _obtener_velocidad_real() * 0.5
			get_parent().move_and_slide()
		else:
			get_parent().velocity = Vector2.ZERO
		
		if tiempo_despierto <= 0:
			esta_despierto_temporal = false
			get_parent().velocity = Vector2.ZERO
	else:
		timer_despertar += delta
		if timer_despertar >= intervalo_despertar:
			timer_despertar = 0.0
			if randf() < probabilidad_despertar:
				esta_despierto_temporal = true
				tiempo_despierto = duracion_despertar
				direccion = Vector2(randf() * 2 - 1, randf() * 2 - 1).normalized()

func _verificar_activacion():
	# NUEVO: Las hordas SIEMPRE están activas
	if es_horda:
		if estado_actual == Estado.INACTIVO:
			estado_actual = Estado.DEAMBULAR
		return
	
	# Código original para enemigos normales
	var hay_bueno_cerca = false
	for bueno in get_tree().get_nodes_in_group("buenos"):
		if is_instance_valid(bueno):
			var dist = get_parent().global_position.distance_to(bueno.global_position)
			if dist < distancia_activacion:
				hay_bueno_cerca = true
				break
	
	if hay_bueno_cerca and estado_actual == Estado.INACTIVO:
		estado_actual = Estado.DEAMBULAR
	elif not hay_bueno_cerca and estado_actual != Estado.INACTIVO:
		estado_actual = Estado.INACTIVO
		get_parent().velocity = Vector2.ZERO

func recibir_atraccion(bueno, intensidad: float):
	if bueno not in buenos_atrayentes:
		buenos_atrayentes.append(bueno)
	
	if objetivo == null or intensidad > intensidad_actual + umbral_cambio:
		objetivo = bueno
		intensidad_actual = intensidad
		estado_actual = Estado.PERSEGUIR

func perder_atraccion(bueno):
	buenos_atrayentes.erase(bueno)
	if objetivo == bueno:
		if buenos_atrayentes.size() > 0:
			objetivo = buenos_atrayentes[0]
			intensidad_actual = 0.0
		else:
			objetivo = null
			intensidad_actual = 0.0
			estado_actual = Estado.DEAMBULAR

# --- COMPORTAMIENTOS ---
func deambular():
	var pos = get_parent().global_position
	
	# Verificar límites del mapa
	if pos.x < -limite_x:
		direccion.x = abs(direccion.x)
		if direccion.x < 2.5: direccion.x = 2.5
	elif pos.x > limite_x:
		direccion.x = -abs(direccion.x)
		if abs(direccion.x) < 2.5: direccion.x = -2.5
	if pos.y < -limite_y:
		direccion.y = abs(direccion.y)
		if direccion.y < 2.5: direccion.y = 2.5
	elif pos.y > limite_y:
		direccion.y = -abs(direccion.y)
		if abs(direccion.y) < 2.5: direccion.y = -2.5
	
	# NUEVO: Verificar si puede moverse en la dirección actual
	var pos_siguiente = pos + direccion * 32.0
	if not _puede_moverse_a(pos_siguiente):
		# Si no puede, cambiar dirección aleatoriamente
		direccion = Vector2(randf() * 2 - 1, randf() * 2 - 1).normalized()
		return
	
	direccion = direccion.normalized()
	
	# Cambio aleatorio de dirección
	if randf() < 0.02:
		var nueva_direccion = Vector2(randf() * 2 - 1, randf() * 2 - 1).normalized()
		var pos_nueva = pos + nueva_direccion * 32.0
		if _puede_moverse_a(pos_nueva):
			direccion = nueva_direccion

func perseguir(delta):
	if not is_instance_valid(objetivo):
		estado_actual = Estado.DEAMBULAR
		return
	
	var dist = get_parent().global_position.distance_to(objetivo.global_position)
	var rango_ataque = stats.get_rango_ataque_px()
	
	var rango_efectivo = rango_ataque
	if objetivo.has_node("CollisionShape2D"):
		var shape = objetivo.get_node("CollisionShape2D").shape
		if shape is RectangleShape2D:
			rango_efectivo = rango_ataque + max(shape.size.x, shape.size.y) * 0.5
	
	# NUEVO: Detectar y atacar edificios cercanos (muros)
	var edificio_cercano = _detectar_edificio_cercano()
	if edificio_cercano and edificio_cercano.has_node("Stats"):
		var dist_edificio = get_parent().global_position.distance_to(edificio_cercano.global_position)
		if dist_edificio <= rango_efectivo:
			# Atacar el edificio
			get_parent().velocity = Vector2.ZERO
			timer_ataque += delta
			if timer_ataque >= stats.cooldown_ataque:
				edificio_cercano.get_node("Stats").rebre_dany(stats.dany)
				timer_ataque = 0
			return
	
	if dist <= rango_efectivo:
		# EN RANGO: Detenerse y atacar
		get_parent().velocity = Vector2.ZERO
		timer_ataque += delta
		if timer_ataque >= stats.cooldown_ataque:
			objetivo.get_node("Stats").rebre_dany(stats.dany)
			timer_ataque = 0
	else:
		# FUERA DE RANGO: Acercarse usando flowfield si es horda
		timer_ataque = 0
		
		if es_horda and flowfield_manager:
			# Usar flowfield para navegación
			var dir_flowfield = flowfield_manager.obtener_direccion(get_parent().global_position)
			if dir_flowfield != Vector2.ZERO:
				direccion = dir_flowfield
			else:
				direccion = (objetivo.global_position - get_parent().global_position).normalized()
		else:
			direccion = (objetivo.global_position - get_parent().global_position).normalized()
		
		# Sprint corto
		var multiplicador_sprint = 1.0
		if dist < 120.0 and dist > rango_efectivo:
			multiplicador_sprint = 2.0
		
		var pos_siguiente = get_parent().global_position + direccion * 32.0
		if _puede_moverse_a(pos_siguiente):
			get_parent().velocity = direccion * _obtener_velocidad_real() * multiplicador_sprint
		else:
			# Terreno (agua/montaÃ±a) bloquea el paso, intentar rodearlo
			var dir_alternativa = Vector2.ZERO
			for angulo in [30.0, -30.0, 60.0, -60.0, 90.0, -90.0, 120.0, -120.0]:
				var dir_alt = direccion.rotated(deg_to_rad(angulo))
				if _puede_moverse_a(get_parent().global_position + dir_alt * 32.0):
					dir_alternativa = dir_alt
					break
			
			if dir_alternativa != Vector2.ZERO:
				get_parent().velocity = dir_alternativa * _obtener_velocidad_real() * multiplicador_sprint
			else:
				get_parent().velocity = Vector2.ZERO

func comportamiento_horda(delta):
	if not flowfield_manager:
		estado_actual = Estado.DEAMBULAR
		return
	
	# Obtener dirección del flowfield
	var dir_flowfield = flowfield_manager.obtener_direccion(get_parent().global_position)
	
	if dir_flowfield == Vector2.ZERO:
		# No hay flowfield, deambular
		estado_actual = Estado.DEAMBULAR
		return
	
	# Moverse según el flowfield
	direccion = dir_flowfield
	
	# Verificar si hay un edificio enemigo cerca para atacar
	var edificio_cercano = _detectar_edificio_cercano()
	if edificio_cercano and edificio_cercano.has_node("Stats"):
		var dist_edificio = get_parent().global_position.distance_to(edificio_cercano.global_position)
		var rango_ataque = stats.get_rango_ataque_px()
		
		if dist_edificio <= rango_ataque:
			# Atacar el edificio
			get_parent().velocity = Vector2.ZERO
			timer_ataque += delta
			if timer_ataque >= stats.cooldown_ataque:
				edificio_cercano.get_node("Stats").rebre_dany(stats.dany)
				timer_ataque = 0
			return
	
	# Si no hay edificio cercano, seguir el flowfield
	timer_ataque = 0
	var pos_siguiente = get_parent().global_position + direccion * 32.0
	
	# Verificar si puede moverse
	if _puede_moverse_a(pos_siguiente):
		get_parent().velocity = direccion * _obtener_velocidad_real()
	else:
		# Intentar rodear el obstáculo
		var dir_alternativa = Vector2.ZERO
		for angulo in [30.0, -30.0, 60.0, -60.0, 90.0, -90.0]:
			var dir_alt = direccion.rotated(deg_to_rad(angulo))
			if _puede_moverse_a(get_parent().global_position + dir_alt * 32.0):
				dir_alternativa = dir_alt
				break
		
		if dir_alternativa != Vector2.ZERO:
			get_parent().velocity = dir_alternativa * _obtener_velocidad_real()
		else:
			get_parent().velocity = Vector2.ZERO

func _obtener_velocidad_real() -> float:
	var generador := get_node_or_null("/root/Mapa/GeneradorRecursos") as GeneradorRecursos
	if generador:
		var mult := generador.modificador_velocidad_en(get_parent().global_position)
		if mult <= 0.0:
			# En agua no debería llegar aquí porque _puede_moverse_a lo bloquea,
			# pero por seguridad devolvemos velocidad mínima.
			return stats.velocidad_movimiento * 0.05
		return stats.velocidad_movimiento * mult
	return stats.velocidad_movimiento

func _puede_moverse_a(pos: Vector2) -> bool:
	var generador := get_node_or_null("/root/Mapa/GeneradorRecursos") as GeneradorRecursos
	if not generador:
		return true
	
	# 1. Comprobar el centro
	if not generador.puede_moverse_a(pos):
		return false
		
	# 2. Comprobar el volumen del cuerpo (8 puntos alrededor del centro)
	# Para un sprite de 32x32, el radio real es 16. Usamos 20 para dar un pequeño margen de seguridad.
	var radio: float = 23.0
	var puntos_a_comprobar = [
		pos + Vector2(radio, 0),    # Este
		pos + Vector2(-radio, 0),   # Oeste
		pos + Vector2(0, radio),    # Sur
		pos + Vector2(0, -radio),   # Norte
		pos + Vector2(radio, radio),    # Sureste
		pos + Vector2(-radio, radio),   # Suroeste
		pos + Vector2(radio, -radio),   # Noreste
		pos + Vector2(-radio, -radio)   # Noroeste
	]
	
	for punto in puntos_a_comprobar:
		if not generador.puede_moverse_a(punto):
			return false
			
	return true

func _detectar_edificio_cercano():
	var espacio = get_tree().current_scene.get_world_2d().direct_space_state
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 80.0  # Radio de detección de edificios
	query.shape = shape
	query.transform = Transform2D(0, get_parent().global_position)
	query.collision_mask = 2  # Capa de edificios
	
	var resultados = espacio.intersect_shape(query)
	for r in resultados:
		if r.collider.is_in_group("buenos"):
			return r.collider
	
	return null
