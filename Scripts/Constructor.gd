extends Node

var modo_construccion = false
var escena_actual: PackedScene
var fantasma = null
var edificio_a_construir = null
var modo_multiples = false
var ruta_escena_actual = ""
var tamano_celda_tilemap: float = 64.0

func _ready():
	pass

func _process(_delta):
	if modo_construccion and fantasma:
		var pos_mouse = get_parent().get_global_mouse_position()
		fantasma.global_position = _alinear_a_tilemap(pos_mouse)
		
		var puede_construir = _puede_construir_aqui()
		fantasma.modulate = Color(0.5, 1, 0.5, 0.5) if puede_construir else Color(1, 0, 0, 0.5)

func _alinear_a_tilemap(pos: Vector2) -> Vector2:
	var generador = get_node_or_null("/root/Mapa/GeneradorRecursos")
	var tamano = Vector2(1, 1)
	if fantasma and fantasma.has_method("get"):
		tamano = fantasma.get("tamano_tiles") if fantasma.get("tamano_tiles") else Vector2(1, 1)
	
	if not generador or not generador.tilemap_layer:
		var half = tamano * tamano_celda_tilemap * 0.5
		var cx = floori(pos.x / tamano_celda_tilemap)
		var cy = floori(pos.y / tamano_celda_tilemap)
		return Vector2(cx * tamano_celda_tilemap + half.x, cy * tamano_celda_tilemap + half.y)
	
	var tilemap = generador.tilemap_layer
	var local_pos = tilemap.to_local(pos)
	var map_coords = tilemap.local_to_map(local_pos)
	
	# Offset para centrar edificios de múltiples tiles
	var offset_x = floori(tamano.x / 2.0)
	var offset_y = floori(tamano.y / 2.0)
	var celda_origen = Vector2i(map_coords.x - offset_x, map_coords.y - offset_y)
	
	# Convertir a posición mundial (esto da la esquina superior izquierda)
	var pos_esquina = tilemap.to_global(tilemap.map_to_local(celda_origen))
	
	# Sumar medio tile para centrar en el centro del tile
	var half_px = tamano * tamano_celda_tilemap * 0.5
	return pos_esquina

func _unhandled_input(event):
	if not modo_construccion:
		return
	
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if _puede_construir_aqui():
				_construir()
		
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancelar_construccion()
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancelar_construccion()

func iniciar_construccion(escena: PackedScene, multiples: bool = false, ruta: String = ""):
	modo_construccion = true
	escena_actual = escena
	modo_multiples = multiples
	ruta_escena_actual = ruta if ruta != "" else escena.resource_path
	
	if fantasma:
		fantasma.queue_free()
	
	fantasma = escena.instantiate()
	fantasma.en_construccion = true
	fantasma.modulate = Color(0.5, 1, 0.5, 0.5)
	
	for child in fantasma.get_children():
		if child is CollisionShape2D:
			child.disabled = true
	
	if fantasma is CharacterBody2D:
		fantasma.collision_layer = 0
		fantasma.collision_mask = 0
	
	var zona_atraccion = fantasma.get_node_or_null("ZonaAtraccion")
	if zona_atraccion:
		zona_atraccion.monitoring = false
		zona_atraccion.monitorable = false
		zona_atraccion.visible = false
	
	get_parent().add_child(fantasma)
	fantasma.remove_from_group("buenos")
	fantasma.set_physics_process(false)
	fantasma.set_process(false)

func _puede_construir_aqui() -> bool:
	if not fantasma:
		return false
	
	var generador = get_node_or_null("/root/Mapa/GeneradorRecursos")
	if not generador or not generador.tilemap_layer:
		return false
	
	var tamano_tiles: Vector2 = Vector2(1, 1)
	if fantasma.get("tamano_tiles"):
		tamano_tiles = fantasma.get("tamano_tiles")
		
	var tipo_edificio: String = ""
	if fantasma.get("tipo_edificio"):
		tipo_edificio = fantasma.get("tipo_edificio")
	
	var tilemap = generador.tilemap_layer
	var centro = fantasma.global_position
	
	# 1. Obtener la celda central
	var local_pos = tilemap.to_local(centro)
	var map_coords = tilemap.local_to_map(local_pos)
	
	# 2. Calcular la celda de origen (esquina superior izquierda)
	var offset_x = floori(tamano_tiles.x / 2.0)
	var offset_y = floori(tamano_tiles.y / 2.0)
	var celda_origen = Vector2i(map_coords.x - offset_x, map_coords.y - offset_y)
	
	# 3. Recorrer TODA la huella del edificio
	for tx in range(int(tamano_tiles.x)):
		for ty in range(int(tamano_tiles.y)):
			var celda = Vector2i(celda_origen.x + tx, celda_origen.y + ty)
			
			# Consultar directamente el diccionario de terrenos (Súper rápido)
			var tipo = generador.mapa_terrenos.get(celda, GeneradorRecursos.TipoTerreno.NORMAL)
			if tipo != GeneradorRecursos.TipoTerreno.NORMAL:
				return false
	
	# 5. Verificar colisiones físicas con otros edificios
	var espacio = get_parent().get_world_2d().direct_space_state
	var shape_rect = RectangleShape2D.new()
	shape_rect.size = tamano_tiles * tamano_celda_tilemap - Vector2(4, 4)
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = shape_rect
	query.transform = Transform2D(0, centro)
	query.collision_mask = 2
	
	var resultados = espacio.intersect_shape(query)
	for r in resultados:
		if r.collider == fantasma:
			continue
		if r.collider.is_in_group("buenos"):
			return false
	
	return true

func _verificar_requisitos_cercania(celda: Vector2i, tipo_edificio: String, generador) -> bool:
	var pos_centro_celda = generador.tilemap_layer.to_global(generador.tilemap_layer.map_to_local(celda)) + Vector2(tamano_celda_tilemap / 2.0, tamano_celda_tilemap / 2.0)
	match tipo_edificio:
		"serradera", "aserradero", "campamento_leña":
			return generador.hay_recurso_cerca(pos_centro_celda, GeneradorRecursos.TipoTerreno.BOSQUE, generador.radio_extraccion)
		"mina", "extractor_mineral":
			return generador.hay_recurso_cerca(pos_centro_celda, GeneradorRecursos.TipoTerreno.MINERAL, generador.radio_extraccion)
		"deposito_chatarra", "taller_chatarra":
			return generador.hay_recurso_cerca(pos_centro_celda, GeneradorRecursos.TipoTerreno.CHATARRA, generador.radio_extraccion)
		_:
			return true

func _construir():
	if not escena_actual or not fantasma:
		return
	var coste = _obtener_coste_escena(ruta_escena_actual)
	if not EconomiaManager.tiene_recursos(coste):
		_cancelar_construccion()
		return
	var posicion_construccion = fantasma.global_position
	EconomiaManager.gastar_recursos(coste)
	var edificio = escena_actual.instantiate()
	edificio.global_position = posicion_construccion
	edificio.en_construccion = true
	get_parent().add_child(edificio)
	edificio.add_to_group("buenos")
	edificio.modulate = Color(0.5, 1, 0.5, 0.7)
	if edificio.has_node("Stats"):
		edificio.get_node("Stats").vida_actual = int(edificio.get_node("Stats").vida_maxima * 0.1)
	var constructores = get_tree().get_nodes_in_group("buenos")
	for constructor in constructores:
		if constructor.has_node("IABueno") and constructor.has_node("Stats") and constructor.get_node("Stats").categoria == "Constructor":
			var ia = constructor.get_node("IABueno")
			if ia.has_method("construir_edificio"):
				ia.construir_edificio(edificio)
				break
	fantasma.queue_free()
	fantasma = null
	
	# NUEVO: Notificar a todos los paneles de constructor
	for panel in get_tree().get_nodes_in_group("panel_constructor"):
		if panel.has_method("forzar_actualizacion"):
			panel.forzar_actualizacion()
	
	if modo_multiples:
		if EconomiaManager.tiene_recursos(coste):
			fantasma = escena_actual.instantiate()
			fantasma.en_construccion = true
			fantasma.modulate = Color(0.5, 1, 0.5, 0.5)
			for child in fantasma.get_children():
				if child is CollisionShape2D:
					child.disabled = true
			if fantasma is CharacterBody2D:
				fantasma.collision_layer = 0
				fantasma.collision_mask = 0
			var zona_atraccion = fantasma.get_node_or_null("ZonaAtraccion")
			if zona_atraccion:
				zona_atraccion.monitoring = false
				zona_atraccion.monitorable = false
				zona_atraccion.visible = false
			get_parent().add_child(fantasma)
			fantasma.remove_from_group("buenos")
			fantasma.set_physics_process(false)
			fantasma.set_process(false)
		else:
			modo_construccion = false
			modo_multiples = false
	else:
		modo_construccion = false
		modo_multiples = false

func _cancelar_construccion():
	if fantasma:
		fantasma.queue_free()
		fantasma = null
	
	modo_construccion = false
	modo_multiples = false
	ruta_escena_actual = ""

func _obtener_coste_escena(ruta: String) -> Dictionary:
	var escena = load(ruta)
	if escena:
		var instancia_temporal = escena.instantiate()
		var coste = instancia_temporal.get("coste_construccion")
		instancia_temporal.free()
		return coste if coste else {}
	return {}
