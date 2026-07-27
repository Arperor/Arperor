extends Node2D

enum Estado { IDLE, MOVER, ATACAR, CONSTRUIR }
var estado_actual = Estado.IDLE
const tamano_tile_paso: float = 32.0
@onready var stats = get_parent().get_node("Stats")
var objetivo = null
var posicion_destino: Vector2
var edificio_objetivo = null
var timer_ataque = 0.0
var frame_counter = 0
var timer_busqueda_construccion = 0.0
var intervalo_busqueda_construccion = 2.2
var tiempo_ultimo_movimiento: float = 0.0
var posicion_anterior: Vector2 = Vector2.ZERO
var umbral_atasco: float = 2.0  # Segundos sin moverse = atascado
var distancia_minima_movimiento: float = 5.0 
# Pathfinding A*
var camino_actual: Array = []  # Array de Vector2 (posiciones mundiales)
var indice_camino: int = 0
var timer_recalcular_camino: float = 0.0
var intervalo_recalculo: float = 0.5  # Recalcular cada 0.5 segundos
var destino_anterior: Vector2 = Vector2.ZERO

func _ready():
	posicion_destino = get_parent().global_position

func _physics_process(delta):
	if not is_instance_valid(stats):
		return
	
	frame_counter += 1
	
	# Limpiar objetivo si murió
	if objetivo and (not is_instance_valid(objetivo) or objetivo.get_node("Stats").vida_actual <= 0):
		var borde_rojo = objetivo.get_node_or_null("BordeRojo") if is_instance_valid(objetivo) else null
		if borde_rojo: borde_rojo.ocultar()
		objetivo = null
		estado_actual = Estado.IDLE
	
	# Limpiar edificio objetivo si terminó
	if edificio_objetivo and (not is_instance_valid(edificio_objetivo) or 
	(not edificio_objetivo.en_construccion and edificio_objetivo.get_node("Stats").vida_actual >= edificio_objetivo.get_node("Stats").vida_maxima)):
		edificio_objetivo = null
		estado_actual = Estado.IDLE
	
	match estado_actual:
		Estado.IDLE:
			comportamiento_idle(delta)
		Estado.MOVER:
			comportamiento_mover_astar(delta)
		Estado.ATACAR:
			comportamiento_atacar(delta)
		Estado.CONSTRUIR:
			comportamiento_construir(delta)
	
	get_parent().move_and_slide()

# ==================== PATHFINDING A* ====================

func _calcular_camino_astar(inicio: Vector2, fin: Vector2) -> Array:
	var generador = get_node_or_null("/root/Mapa/GeneradorRecursos")
	if not generador:
		return [fin]  # Fallback: ir directo
	
	# Convertir posiciones mundiales a celdas del grid
	var celda_inicio = generador._pos_a_celda(inicio)
	var celda_fin = generador._pos_a_celda(fin)
	
	# Si la celda final no es transitable, buscar la más cercana que sí lo sea
	if not _es_celda_transitable_para_unidad(celda_fin, generador):
		celda_fin = _buscar_celda_transitable_cercana(generador, celda_fin)
		if celda_fin == Vector2i(-1, -1):
			return [fin]  # No hay camino posible
	if celda_inicio == celda_fin:
		return [fin]
	# A* algorithm
	var abierta = []  # Lista de nodos por explorar
	var cerrada = {}  # Nodos ya explorados
	var padres = {}   # Para reconstruir el camino
	var coste_g = {}  # Coste desde el inicio
	var coste_f = {}  # Coste total (g + h)
	
	# Inicializar con el nodo de inicio
	abierta.append(celda_inicio)
	coste_g[celda_inicio] = 0
	coste_f[celda_inicio] = _heuristica(celda_inicio, celda_fin)
	
	var max_iteraciones = 500  # Limitar para evitar loops infinitos
	var iteracion = 0
	
	while abierta.size() > 0 and iteracion < max_iteraciones:
		iteracion += 1
		
		# Encontrar el nodo con menor coste_f
		var actual = abierta[0]
		for nodo in abierta:
			if coste_f[nodo] < coste_f[actual]:
				actual = nodo
		
		# Si llegamos al destino, reconstruir camino
		if actual == celda_fin:
			return _reconstruir_camino(padres, celda_inicio, celda_fin, generador)
		
		abierta.erase(actual)
		cerrada[actual] = true
		
		# Explorar vecinos (8 direcciones)
		# Explorar vecinos (8 direcciones)
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				
				var vecino = Vector2i(actual.x + dx, actual.y + dy)
				
				# Saltar si ya está en cerrada
				if cerrada.has(vecino):
					continue
				
				# NUEVO: Comprobar si el movimiento es válido considerando el volumen
				if not _es_celda_transitable_para_unidad(vecino, generador):
					continue
				
				# NUEVO: Prevenir corner cutting en movimientos diagonales
				if dx != 0 and dy != 0:
					# Verificar que las dos celdas ortogonales adyacentes sean transitables
					var celda_horizontal = Vector2i(actual.x + dx, actual.y)
					var celda_vertical = Vector2i(actual.x, actual.y + dy)
					
					if not _es_celda_transitable_para_unidad(celda_horizontal, generador):
						continue
					if not _es_celda_transitable_para_unidad(celda_vertical, generador):
						continue
				
				# Calcular costes
				var coste_movimiento = 1.0 if (dx == 0 or dy == 0) else 1.414  # Diagonal cuesta más
				var nuevo_g = coste_g[actual] + coste_movimiento
				
				# Si el vecino no está en abierta, añadirlo
				if not abierta.has(vecino):
					abierta.append(vecino)
					padres[vecino] = actual
					coste_g[vecino] = nuevo_g
					coste_f[vecino] = nuevo_g + _heuristica(vecino, celda_fin)
				# Si ya está pero encontramos un camino mejor, actualizar
				elif nuevo_g < coste_g[vecino]:
					padres[vecino] = actual
					coste_g[vecino] = nuevo_g
					coste_f[vecino] = nuevo_g + _heuristica(vecino, celda_fin)
	
	# No se encontró camino, ir directo
	return [fin]

func _heuristica(a: Vector2i, b: Vector2i) -> float:
	# Distancia Manhattan (más rápida que Euclidiana)
	return abs(a.x - b.x) + abs(a.y - b.y)

func _es_celda_transitable_para_unidad(celda: Vector2i, generador) -> bool:
	# Convertir la celda a posición mundial (centro del tile)
	var pos_centro = Vector2(
		celda.x * generador.tamano_tile + generador.tamano_tile * 0.5,
		celda.y * generador.tamano_tile + generador.tamano_tile * 0.5
	)
	
	# 1. Verificar terreno (agua/montaña)
	var tipo_terreno = generador.obtener_terreno_en(pos_centro)
	if tipo_terreno == GeneradorRecursos.TipoTerreno.AGUA or tipo_terreno == GeneradorRecursos.TipoTerreno.MONTAÑA:
		return false
	
	# 2. Verificar si hay un edificio en esta celda
	var espacio = get_tree().current_scene.get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos_centro
	query.collision_mask = 2  # Capa de edificios
	var resultados = espacio.intersect_point(query)
	
	for resultado in resultados:
		var colisionador = resultado.collider
		if colisionador.is_in_group("buenos") and colisionador.has_method("get") and colisionador.get("tipo_edificio"):
			# Es un edificio, no es transitable
			return false
	
	return true

func _reconstruir_camino(padres: Dictionary, inicio: Vector2i, fin: Vector2i, generador) -> Array:
	var camino = []
	var actual = fin
	
	while actual != inicio:
		# Convertir celda a posición mundial (centro del tile)
		var pos_mundial = Vector2(
			actual.x * generador.tamano_tile + generador.tamano_tile * 0.5,
			actual.y * generador.tamano_tile + generador.tamano_tile * 0.5
		)
		camino.append(pos_mundial)
		
		if not padres.has(actual):
			break
		actual = padres[actual]
	
	camino.reverse()
	return camino

func _buscar_celda_transitable_cercana(generador, celda_centro: Vector2i) -> Vector2i:
	var radio_busqueda = 5  # Buscar en un radio de 5 tiles
	
	for radio in range(1, radio_busqueda + 1):
		for dx in range(-radio, radio + 1):
			for dy in range(-radio, radio + 1):
				if abs(dx) != radio and abs(dy) != radio:
					continue  # Solo buscar en el borde del radio actual
				
				var celda = Vector2i(celda_centro.x + dx, celda_centro.y + dy)
				var pos = Vector2(celda.x * generador.tamano_tile, celda.y * generador.tamano_tile)
				
				if _es_celda_transitable_para_unidad(celda, generador):
					return celda
	
	return Vector2i(-1, -1)  # No se encontró

# ==================== COMPORTAMIENTOS ====================

func comportamiento_mover_astar(delta: float):
	var dist_final = get_parent().global_position.distance_to(posicion_destino)
	
	# Si está muy cerca del destino, detenerse
	if dist_final < 4.0:
		get_parent().velocity = Vector2.ZERO
		estado_actual = Estado.IDLE
		camino_actual.clear()
		tiempo_ultimo_movimiento = 0.0
		return
	
	# Detección de atasco
	var posicion_actual = get_parent().global_position
	if posicion_actual.distance_to(posicion_anterior) > distancia_minima_movimiento:
		tiempo_ultimo_movimiento = 0.0
		posicion_anterior = posicion_actual
	else:
		tiempo_ultimo_movimiento += delta
		if tiempo_ultimo_movimiento > umbral_atasco:
			# Atascado: recalcular ruta o saltar waypoint
			if camino_actual.size() > 0 and indice_camino < camino_actual.size():
				# Intentar saltar al siguiente waypoint
				indice_camino += 1
				tiempo_ultimo_movimiento = 0.0
			else:
				# Recalcular ruta completa
				camino_actual = _calcular_camino_astar(get_parent().global_position, posicion_destino)
				indice_camino = 0
				tiempo_ultimo_movimiento = 0.0
			return
	
	# Recalcular camino si es necesario
	timer_recalcular_camino += delta
	var destino_cambio = posicion_destino.distance_to(destino_anterior) > 32.0
	
	if camino_actual.is_empty() or timer_recalcular_camino >= intervalo_recalculo or destino_cambio:
		camino_actual = _calcular_camino_astar(get_parent().global_position, posicion_destino)
		indice_camino = 0
		timer_recalcular_camino = 0.0
		destino_anterior = posicion_destino
	
	# Seguir el camino
	if camino_actual.is_empty():
		get_parent().velocity = Vector2.ZERO
		return
	
	# Obtener el siguiente punto del camino
	if indice_camino >= camino_actual.size():
		indice_camino = camino_actual.size() - 1
	
	var punto_objetivo = camino_actual[indice_camino]
	var dist_punto = get_parent().global_position.distance_to(punto_objetivo)
	
	# Si está cerca del punto actual, avanzar al siguiente
	if dist_punto < 20.0 and indice_camino < camino_actual.size() - 1:
		indice_camino += 1
		punto_objetivo = camino_actual[indice_camino]
	
	# NUEVO: Verificar que el waypoint es transitable antes de moverse
	var pos_siguiente = get_parent().global_position + (punto_objetivo - get_parent().global_position).normalized() * tamano_tile_paso
	if not _puede_moverse_a(pos_siguiente):
		# El waypoint está bloqueado, saltar al siguiente o recalcular
		if indice_camino < camino_actual.size() - 1:
			indice_camino += 1
			return
		else:
			# No hay más waypoints, recalcular
			camino_actual = _calcular_camino_astar(get_parent().global_position, posicion_destino)
			indice_camino = 0
			return
	
	# Moverse hacia el punto objetivo
	var dir = (punto_objetivo - get_parent().global_position).normalized()
	
	# Aplicar velocidad según terreno
	var velocidad_actual = stats.velocidad_movimiento
	var generador = get_node_or_null("/root/Mapa/GeneradorRecursos")
	if generador:
		velocidad_actual *= generador.modificador_velocidad_en(get_parent().global_position)
	
	# Aplicar separación entre unidades
	var separacion = get_parent().get_node_or_null("Separacion")
	if separacion:
		dir = (dir + separacion.get_velocity_separacion() * 1.5).normalized()
	
	get_parent().velocity = dir * velocidad_actual

func construir_edificio(edificio):
	if stats.categoria != "Constructor":
		return
	edificio_objetivo = edificio
	objetivo = null
	estado_actual = Estado.CONSTRUIR

func reparar_edificio(edificio):
	if stats.categoria != "Constructor":
		return
	edificio_objetivo = edificio
	objetivo = null
	estado_actual = Estado.CONSTRUIR

func comportamiento_construir(delta: float) -> void:
	if not is_instance_valid(edificio_objetivo):
		estado_actual = Estado.IDLE
		return

	var dist: float = get_parent().global_position.distance_to(edificio_objetivo.global_position)

	# Calcular rango de construcción dinámico
	var rango_construccion: float = 80.0
	if edificio_objetivo.get("tamano_tiles"):
		var tamano_tiles = edificio_objetivo.get("tamano_tiles")
		var max_dimension_tiles = max(tamano_tiles.x, tamano_tiles.y)
		rango_construccion = (max_dimension_tiles * 64.0 * 0.5) + 64.0
	elif edificio_objetivo.has_node("CollisionShape2D"):
		var shape: Shape2D = edificio_objetivo.get_node("CollisionShape2D").shape
		if shape is RectangleShape2D:
			var max_dimension = max((shape as RectangleShape2D).size.x, (shape as RectangleShape2D).size.y)
			rango_construccion = (max_dimension * 0.5) + 32.0

	if dist <= rango_construccion:
		get_parent().velocity = Vector2.ZERO
		timer_ataque += delta
		if timer_ataque >= stats.cooldown_ataque:
			edificio_objetivo.get_node("Stats").construir(stats.dany)
			timer_ataque = 0
	else:
		if frame_counter % 10 == 0:
			var dir: Vector2 = (edificio_objetivo.global_position - get_parent().global_position).normalized()
			var pos_sig: Vector2 = get_parent().global_position + dir * tamano_tile_paso
			if _puede_moverse_a(pos_sig):
				var velocidad_actual: float = stats.velocidad_movimiento
				var generador = get_node_or_null("/root/Mapa/GeneradorRecursos")
				if generador:
					velocidad_actual *= generador.modificador_velocidad_en(get_parent().global_position)
				get_parent().velocity = dir * velocidad_actual
			else:
				get_parent().velocity = Vector2.ZERO
		timer_ataque = 0

func comportamiento_idle(delta):
	var separacion = get_parent().get_node_or_null("Separacion")
	if separacion:
		var fuerza_separacion = separacion.get_velocity_separacion()
		if fuerza_separacion.length() > 0.1:
			get_parent().velocity = fuerza_separacion * 10
		else:
			get_parent().velocity = Vector2.ZERO
	else:
		get_parent().velocity = Vector2.ZERO
	
	if stats.categoria == "Constructor":
		timer_busqueda_construccion += delta
		if not edificio_objetivo or timer_busqueda_construccion >= intervalo_busqueda_construccion:
			timer_busqueda_construccion = 0.0
			_buscar_edificio_en_construccion()
		return
	
	if not has_node("TimerBusqueda"):
		var timer = Timer.new()
		timer.name = "TimerBusqueda"
		timer.wait_time = 1.0
		timer.one_shot = true
		add_child(timer)
		timer.timeout.connect(_buscar_enemigo_idle)
	
	if not get_node("TimerBusqueda").time_left > 0:
		_buscar_enemigo_idle()
		get_node("TimerBusqueda").start()

func _buscar_enemigo_idle():
	var malos = get_tree().get_nodes_in_group("malos")
	var rango_ataque = stats.get_rango_ataque_px()
	
	for m in malos:
		if m.has_node("Stats") and m.get_node("Stats").vida_actual > 0:
			var dist = get_parent().global_position.distance_to(m.global_position)
			if dist <= rango_ataque:
				objetivo = m
				estado_actual = Estado.ATACAR
				return

func _buscar_edificio_en_construccion():
	if edificio_objetivo and is_instance_valid(edificio_objetivo):
		return
	
	var edificios_en_construccion = []
	for bueno in get_tree().get_nodes_in_group("buenos"):
		if is_instance_valid(bueno) and bueno.get("en_construccion") == true:
			if bueno.has_node("Stats"):
				var stats_edificio = bueno.get_node("Stats")
				if stats_edificio.vida_actual < stats_edificio.vida_maxima:
					edificios_en_construccion.append(bueno)
	
	if edificios_en_construccion.size() == 0:
		return
	
	var edificio_mas_cercano = null
	var distancia_minima = INF
	
	for edificio in edificios_en_construccion:
		var dist = get_parent().global_position.distance_to(edificio.global_position)
		if dist < distancia_minima:
			distancia_minima = dist
			edificio_mas_cercano = edificio
	
	if edificio_mas_cercano:
		construir_edificio(edificio_mas_cercano)

func comportamiento_atacar(delta):
	if not is_instance_valid(objetivo):
		estado_actual = Estado.IDLE
		return
	
	var dist = get_parent().global_position.distance_to(objetivo.global_position)
	var rango_ataque = stats.get_rango_ataque_px()
	
	var borde_rojo = objetivo.get_node_or_null("BordeRojo")
	if borde_rojo:
		borde_rojo.mostrar()
	
	if dist <= rango_ataque:
		get_parent().velocity = Vector2.ZERO
		timer_ataque += delta
		if timer_ataque >= stats.cooldown_ataque:
			if stats.escena_proyectil and stats.rango_ataque_tiles > 0:
				lanzar_proyectil()
			else:
				objetivo.get_node("Stats").rebre_dany(stats.dany)
			timer_ataque = 0
	else:
		if frame_counter % 10 == 0:
			var direccion = (objetivo.global_position - get_parent().global_position).normalized()
			var pos_siguiente = get_parent().global_position + direccion * tamano_tile_paso
			if _puede_moverse_a(pos_siguiente):
				get_parent().velocity = _calcular_velocidad_movimiento(direccion)
			else:
				get_parent().velocity = Vector2.ZERO
		timer_ataque = 0

func lanzar_proyectil():
	var proyectil = stats.escena_proyectil.instantiate()
	get_parent().get_parent().add_child(proyectil)
	proyectil.global_position = get_parent().global_position
	proyectil.objetivo = objetivo
	proyectil.dany = stats.dany
	proyectil.categoria_origen = stats.categoria

func mover_a(destino):
	posicion_destino = destino
	objetivo = null
	edificio_objetivo = null
	camino_actual.clear()  # Limpiar camino anterior
	estado_actual = Estado.MOVER

func atacar_a(enemigo):
	objetivo = enemigo
	estado_actual = Estado.ATACAR

func _calcular_velocidad_movimiento(dir: Vector2) -> Vector2:
	var velocidad_actual: float = stats.velocidad_movimiento
	var generador = get_node_or_null("/root/Mapa/GeneradorRecursos")
	if generador:
		velocidad_actual *= generador.modificador_velocidad_en(get_parent().global_position)
	
	var separacion = get_parent().get_node_or_null("Separacion")
	if separacion:
		dir = (dir + separacion.get_velocity_separacion() * 1.5).normalized()
	
	return dir * velocidad_actual

func _puede_moverse_a(pos: Vector2) -> bool:
	var generador = get_node_or_null("/root/Mapa/GeneradorRecursos")
	if generador:
		return generador.puede_moverse_a(pos)
	return true
