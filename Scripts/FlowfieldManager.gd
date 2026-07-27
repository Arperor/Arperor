extends Node

# Grid de direcciones del flowfield
var flowfield_grid: Dictionary = {}
var celda_objetivo: Vector2i = Vector2i(-1, -1)
var generador = null
var tamano_celda: float = 64.0

func _ready():
	generador = get_node_or_null("/root/Mapa/GeneradorRecursos")
	
	# Conectar señal de construcción de base
	if generador:
		# Esperar a que EconomiaManager esté disponible
		call_deferred("_conectar_senal_base")

func _conectar_senal_base():
	var economia = get_node_or_null("/root/EconomiaManager")
	if economia and economia.has_signal("base_construida_signal"):
		economia.base_construida_signal.connect(_on_base_construida)
	
	# También intentar calcular al inicio por si la base ya existe
	call_deferred("_on_base_construida")

	# También intentar calcular al inicio por si la base ya existe
func calcular_flowfield(posicion_objetivo: Vector2):
	if not generador:
		return
	flowfield_grid.clear()
	celda_objetivo = generador._pos_a_celda(posicion_objetivo)
	
	var cola = []
	var visitados = {}
	var costes = {}
	
	cola.append(celda_objetivo)
	visitados[celda_objetivo] = true
	costes[celda_objetivo] = 0
	
	while cola.size() > 0:
		var celda_actual = cola.pop_front()
		var coste_actual = costes[celda_actual]
		
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				
				var vecino = Vector2i(celda_actual.x + dx, celda_actual.y + dy)
				
				if visitados.has(vecino):
					continue
				
				# Prevenir corner cutting en diagonales
				if dx != 0 and dy != 0:
					var celda_horizontal = Vector2i(celda_actual.x + dx, celda_actual.y)
					var celda_vertical = Vector2i(celda_actual.x, celda_actual.y + dy)
					var pos_horizontal = Vector2(celda_horizontal.x * tamano_celda + tamano_celda * 0.5, celda_horizontal.y * tamano_celda + tamano_celda * 0.5)
					var pos_vertical = Vector2(celda_vertical.x * tamano_celda + tamano_celda * 0.5, celda_vertical.y * tamano_celda + tamano_celda * 0.5)
					if not _es_transitable(pos_horizontal) or not _es_transitable(pos_vertical):
						continue
				
				var pos_vecino = Vector2(vecino.x * tamano_celda + tamano_celda * 0.5, vecino.y * tamano_celda + tamano_celda * 0.5)
				if not _es_transitable(pos_vecino):
					continue
				
				visitados[vecino] = true
				costes[vecino] = coste_actual + 1
				cola.append(vecino)
				
	for celda in visitados:
		var mejor_dir = Vector2.ZERO
		var mejor_coste = INF
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var vecino_dir = Vector2i(celda.x + dx, celda.y + dy)
				if costes.has(vecino_dir):
					if costes[vecino_dir] < mejor_coste:
						mejor_coste = costes[vecino_dir]
						mejor_dir = Vector2(dx, dy).normalized()
		flowfield_grid[celda] = mejor_dir

func _es_transitable(pos: Vector2) -> bool:
	if not generador:
		return true
	var terreno = generador.obtener_terreno_en(pos)
	if terreno == GeneradorRecursos.TipoTerreno.AGUA or terreno == GeneradorRecursos.TipoTerreno.MONTAÑA:
		return false
	return true

func obtener_direccion(pos: Vector2) -> Vector2:
	if not generador:
		return Vector2.ZERO
	var celda = generador._pos_a_celda(pos)
	return flowfield_grid.get(celda, Vector2.ZERO)

func _on_base_construida():
	# Buscar la base y calcular flowfield
	var base = null
	for bueno in get_tree().get_nodes_in_group("buenos"):
		if bueno.get("tipo_edificio") == "Base":
			base = bueno
			break
	
	if base:
		calcular_flowfield(base.global_position)
