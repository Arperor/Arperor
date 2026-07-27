extends Node2D

@export var tamano_celda: float = 64.0  # 64px = 4x menos cálculos que 32px
@export var limite_x: float = 2800.0
@export var limite_y: float = 2800.0
@export var actualizaciones_por_segundo: float = 5.0 # 5 FPS es imperceptible y ahorra muchísima CPU

enum Estado { OSCURO, RECORDADO, VISIBLE }

var celdas_ancho: int
var celdas_alto: int
var grid: PackedByteArray
var grid_anterior: PackedByteArray

var fog_image: Image
var fog_texture: ImageTexture
@onready var sprite_niebla: Sprite2D = $SpriteNiebla

var timer_actualizacion: float = 0.0
var celdas_visibles_actuales: Array[int] = [] # OPTIMIZACIÓN: Solo iterar lo que está visible

func _ready():
	celdas_ancho = int((limite_x * 2) / tamano_celda)
	celdas_alto = int((limite_y * 2) / tamano_celda)
	
	grid.resize(celdas_ancho * celdas_alto)
	grid.fill(Estado.OSCURO)
	grid_anterior = grid.duplicate()
	
	fog_image = Image.create_empty(celdas_ancho, celdas_alto, false, Image.FORMAT_RGBA8)
	fog_image.fill(Color(0, 0, 0, 1.0))
	
	fog_texture = ImageTexture.create_from_image(fog_image)
	sprite_niebla.texture = fog_texture
	
	sprite_niebla.scale = Vector2(tamano_celda, tamano_celda)
	sprite_niebla.position = Vector2(-limite_x, -limite_y)
	sprite_niebla.centered = false
	sprite_niebla.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR # Hace que los cuadros se vean como círculos suaves

func _process(delta):
	timer_actualizacion += delta
	if timer_actualizacion >= (1.0 / actualizaciones_por_segundo):
		timer_actualizacion = 0.0
		_actualizar_niebla()

func _actualizar_niebla():
	# 1. OPTIMIZACIÓN: Solo resetear las celdas que estaban visibles (no las 30.000 del mapa)
	for index in celdas_visibles_actuales:
		grid[index] = Estado.RECORDADO
	celdas_visibles_actuales.clear()
			
	# 2. Calcular nueva visión
	var buenos = get_tree().get_nodes_in_group("buenos")
	for bueno in buenos:
		if not is_instance_valid(bueno) or not bueno.has_node("Stats"):
			continue
		if bueno.get("en_construccion") == true or bueno.get_node("Stats").vida_actual <= 0:
			continue
			
		var rango = bueno.get_node("Stats").get_rango_vision_px()
		var pos = bueno.global_position
		var celda_centro = _pos_a_celda(pos)
		var radio_celdas = int(rango / tamano_celda) + 1
		
		for dx in range(-radio_celdas, radio_celdas + 1):
			for dy in range(-radio_celdas, radio_celdas + 1):
				var cx = celda_centro.x + dx
				var cy = celda_centro.y + dy
				
				if cx >= 0 and cx < celdas_ancho and cy >= 0 and cy < celdas_alto:
					var pos_celda = _celda_a_pos(Vector2(cx, cy))
					if pos.distance_to(pos_celda) <= rango:
						var celda_objetivo = Vector2(cx, cy)
						if _linea_de_vision_libre(celda_centro, celda_objetivo):
							var index = int(cy) * celdas_ancho + int(cx)
							grid[index] = Estado.VISIBLE
							celdas_visibles_actuales.append(index)

	# 3. Ocultar enemigos y pintar
	_ocultar_entidades_en_niebla()
	_pintar_textura_optimizado()
	var spawner = get_node_or_null("/root/Mapa/Spawner")
	if spawner:
		spawner.necesita_actualizar_cache = true

func _pintar_textura_optimizado():
	var cambio_detectado = false
	
	# OPTIMIZACIÓN: Solo cambiar los píxeles que cambiaron de estado
	for i in range(grid.size()):
		if grid[i] != grid_anterior[i]:
			cambio_detectado = true
			var x = i % celdas_ancho
			var y = i / celdas_ancho
			
			var color: Color
			match grid[i]:
				Estado.OSCURO: color = Color(0, 0, 0, 1.0)
				Estado.RECORDADO: color = Color(0, 0, 0, 0.6)
				Estado.VISIBLE: color = Color(0, 0, 0, 0.0)
			
			fog_image.set_pixel(x, y, color)
	
	if cambio_detectado:
		fog_texture.update(fog_image)
		grid_anterior = grid.duplicate()

func _ocultar_entidades_en_niebla():
	var malos = get_tree().get_nodes_in_group("malos")
	for malo in malos:
		if is_instance_valid(malo):
			var celda = _pos_a_celda(malo.global_position)
			var index = int(celda.y) * celdas_ancho + int(celda.x)
			if index >= 0 and index < grid.size():
				malo.visible = (grid[index] == Estado.VISIBLE)

func _pos_a_celda(pos: Vector2) -> Vector2:
	var x = int((pos.x + limite_x) / tamano_celda)
	var y = int((pos.y + limite_y) / tamano_celda)
	return Vector2(clamp(x, 0, celdas_ancho - 1), clamp(y, 0, celdas_alto - 1))

func _celda_a_pos(celda: Vector2) -> Vector2:
	var x = (celda.x * tamano_celda) - limite_x + (tamano_celda / 2)
	var y = (celda.y * tamano_celda) - limite_y + (tamano_celda / 2)
	return Vector2(x, y)

func _linea_de_vision_libre(celda_niebla_origen: Vector2, celda_niebla_destino: Vector2) -> bool:
	var generador = get_node_or_null("/root/Mapa/GeneradorRecursos")
	if not generador:
		return true
	
	# Convertir celdas de niebla (con offset) a posiciones mundiales
	var pos_origen = _celda_a_pos(celda_niebla_origen)
	var pos_destino = _celda_a_pos(celda_niebla_destino)
	
	# Convertir posiciones mundiales a celdas del terreno (sin offset)
	var celda_terreno_origen = generador._pos_a_celda(pos_origen)
	var celda_terreno_destino = generador._pos_a_celda(pos_destino)
	
	# Algoritmo de Bresenham sobre celdas de terreno
	var x0 = int(celda_terreno_origen.x)
	var y0 = int(celda_terreno_origen.y)
	var x1 = int(celda_terreno_destino.x)
	var y1 = int(celda_terreno_destino.y)
	
	var dx = abs(x1 - x0)
	var dy = abs(y1 - y0)
	var sx = 1 if x0 < x1 else -1
	var sy = 1 if y0 < y1 else -1
	var err = dx - dy
	
	var pasos = 0
	var max_pasos = dx + dy + 1
	
	while pasos < max_pasos:
		pasos += 1
		
		# Comprobar la celda actual (excepto la de origen, no se bloquea a sí misma)
		if pasos > 1:
			var terreno = generador.mapa_terrenos.get(Vector2i(x0, y0), GeneradorRecursos.TipoTerreno.NORMAL)
			if terreno == GeneradorRecursos.TipoTerreno.MONTAÑA:
				# NUEVO: Marcar esta celda de montaña como VISIBLE (la pared que vemos)
				var pos_montaña = Vector2(x0 * generador.tamano_tile, y0 * generador.tamano_tile)
				var celda_niebla_montaña = _pos_a_celda(pos_montaña)
				var index = int(celda_niebla_montaña.y) * celdas_ancho + int(celda_niebla_montaña.x)
				if index >= 0 and index < grid.size():
					grid[index] = Estado.VISIBLE
					if index not in celdas_visibles_actuales:
						celdas_visibles_actuales.append(index)
				return false
		
		if x0 == x1 and y0 == y1:
			break
		
		var e2 = 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
	
	return true
