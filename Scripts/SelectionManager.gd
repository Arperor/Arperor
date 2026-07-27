extends Node2D

@onready var input = $InputHandler
@onready var grupo_buenas = get_node("../UnidadesBuenas")
var unidades_seleccionadas: Array = []

func _ready():
	if input:
		input.clic_simple.connect(_on_clic_izquierdo)
		input.caja_seleccion.connect(_on_caja)
		input.orden_mover.connect(_on_clic_derecho)

func _on_clic_izquierdo(pos):
	var u = _buscar_cercana(pos)
	if u:
		_deseleccionar_todo()
		_seleccionar(u)
	else:
		_deseleccionar_todo()

func _on_clic_derecho(pos):
	if unidades_seleccionadas.is_empty():
		return
	
	# 1. Comprobar si hay un enemigo en la posición (todas atacan)
	var enemigo = detectar_enemigo_en_posicion(pos)
	if enemigo:
		for u in unidades_seleccionadas:
			if is_instance_valid(u) and u.has_node("IABueno"):
				u.get_node("IABueno").atacar_a(enemigo)
		return
	
	# 2. Si no hay enemigo, iterar sobre cada unidad seleccionada
	for u in unidades_seleccionadas:
		if not is_instance_valid(u) or not u.has_node("IABueno"):
			continue
			
		var ia = u.get_node("IABueno")
		var es_constructor = (ia.stats.categoria == "Constructor")
		
		if not es_constructor:
			ia.mover_a(pos)
		else:
			# Lógica especial para constructores (reparar/construir)
			var edificio_construccion = detectar_edificio_en_construccion(pos)
			if edificio_construccion:
				ia.construir_edificio(edificio_construccion)
				continue
				
			var edificio_destruido = detectar_edificio_destruido(pos)
			if edificio_destruido:
				ia.reparar_edificio(edificio_destruido)
				continue
				
			var edificio_dañado = detectar_edificio_dañado(pos)
			if edificio_dañado:
				ia.reparar_edificio(edificio_dañado)
				continue
				
			ia.mover_a(pos)

func detectar_edificio_en_construccion(pos):
	var espacio = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collision_mask = 2   # capa de edificios
	for r in espacio.intersect_point(query):
		var b = r.collider
		if b.get("en_construccion") == true:
			return b
	return null

func detectar_edificio_dañado(pos):
	var espacio = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collision_mask = 2
	for r in espacio.intersect_point(query):
		var b = r.collider
		if b.get("tipo_edificio") and b.has_node("Stats"):
			var s = b.get_node("Stats")
			if s.vida_actual < s.vida_maxima and s.vida_actual > 0:
				return b
	return null

func detectar_edificio_destruido(pos):
	var espacio = get_world_2d().direct_space_state
	var query = PhysicsPointQueryParameters2D.new()
	query.position = pos
	query.collision_mask = 2
	for r in espacio.intersect_point(query):
		var b = r.collider
		if b.get("tipo_edificio") and b.has_node("Stats"):
			if b.get_node("Stats").vida_actual <= 0:
				return b
	return null

func _on_caja(area):
	_deseleccionar_todo()
	
	# Buscar en el grupo "buenos" en lugar de solo en los hijos directos
	for u in get_tree().get_nodes_in_group("buenos"):
		if u is CharacterBody2D and area.has_point(u.global_position):
			_seleccionar(u)

func _buscar_cercana(pos):
	var mejor_unidad = null
	var mejor_distancia = 50.0  # Radio máximo de selección
	
	# Buscar en TODOS los nodos del grupo "buenos", no solo en los hijos de un nodo
	for u in get_tree().get_nodes_in_group("buenos"):
		if u is CharacterBody2D or u.has_method("seleccionar"):
			var dist = pos.distance_to(u.global_position)
			if dist < mejor_distancia:
				mejor_distancia = dist
				mejor_unidad = u
	
	return mejor_unidad

func detectar_enemigo_en_posicion(pos):
	var malos = get_tree().get_nodes_in_group("malos")
	for m in malos:
		if m is Node2D and m.has_node("Stats") and m.get_node("Stats").vida_actual > 0:
			if pos.distance_to(m.global_position) < 64:
				return m
	return null

func _seleccionar(u):
	if not u in unidades_seleccionadas:
		unidades_seleccionadas.append(u)
		u.seleccionar()
	
	# Mostrar panel solo si es una unidad (o el último seleccionado)
	_actualizar_ui(u)

func _deseleccionar_todo():
	for u in unidades_seleccionadas:
		if is_instance_valid(u):
			u.deseleccionar()
	unidades_seleccionadas.clear()
	_ocultar_ui()

func _actualizar_ui(unidad):
	_ocultar_ui()
	
	# Si es un edificio, usar tipo_edificio
	var tipo_edificio = unidad.get("tipo_edificio")
	if tipo_edificio:
		var nombre_panel = "Panel" + tipo_edificio.capitalize()
		var panel = get_node_or_null("../UI/" + nombre_panel)
		if panel and panel.has_method("mostrar_panel"):
			panel.mostrar_panel(unidad)
		return
	
	# Si es una unidad, usar stats.categoria
	var stats = unidad.get_node_or_null("Stats")
	if not stats:
		return
	
	match stats.categoria:
		"Constructor":
			var panel = get_node_or_null("../UI/PanelConstructor")
			if panel:
				panel.mostrar(unidad)
		"Explorador":
			pass

func _ocultar_ui():
	var panel_constructor = get_node_or_null("../UI/PanelConstructor")
	if panel_constructor:
		panel_constructor.ocultar()
	
	var panel_base = get_node_or_null("../UI/PanelBase")
	if panel_base:
		panel_base.ocultar_panel()
