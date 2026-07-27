extends Control

@export var tamano_minimapa: Vector2 = Vector2(150, 150)  # Reducido de 200 a 150
@export var resolucion_interna: Vector2 = Vector2(100, 100)  # Generamos a 100x100 y escalamos

@onready var texture_rect: TextureRect = $TextureRect
@onready var input_area: Control = $InputArea
@onready var fondo: ColorRect = $Fondo

var minimap_image: Image
var minimap_texture: ImageTexture
var terreno_base_image: Image
var niebla_base_image: Image  # NUEVO: Caché de niebla

var generador = null
var niebla = null
var camara = null

var mundo_ancho: float = 18000.0
var mundo_alto: float = 18000.0

var timer_actualizacion: float = 0.0
var intervalo_actualizacion: float = 0.5  # Reducido a 2 FPS (era 5 FPS)
var timer_niebla: float = 0.0
var intervalo_niebla: float = 1.0  # La niebla se actualiza cada 1 segundo

func _ready():
	generador = get_node_or_null("/root/Mapa/GeneradorRecursos")
	niebla = get_node_or_null("/root/Mapa/NieblaDeGuerra")
	camara = get_node_or_null("/root/Mapa/CamaraRTS")
	
	if generador:
		mundo_ancho = float(generador.tamano_mapa_x)
		mundo_alto = float(generador.tamano_mapa_y)
	
	# Crear imágenes a resolución interna más baja
	var w = int(resolucion_interna.x)
	var h = int(resolucion_interna.y)
	minimap_image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	terreno_base_image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	niebla_base_image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	niebla_base_image.fill(Color(1, 1, 1, 1))  # Blanco = visible
	
	minimap_texture = ImageTexture.create_from_image(minimap_image)
	texture_rect.texture = minimap_texture
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE  # Escalar al tamaño visual
	
	# Conectar click
	input_area.gui_input.connect(_on_gui_input)
	
	# Generar terreno base una sola vez
	call_deferred("_generar_terreno_base")

func _generar_terreno_base():
	if not generador:
		call_deferred("_generar_terreno_base")
		return
	
	var w = int(resolucion_interna.x)
	var h = int(resolucion_interna.y)
	
	for x in range(w):
		for y in range(h):
			var mundo_x = (float(x) / float(w)) * mundo_ancho - (mundo_ancho / 2.0)
			var mundo_y = (float(y) / float(h)) * mundo_alto - (mundo_alto / 2.0)
			
			var terreno = generador.obtener_terreno_en(Vector2(mundo_x, mundo_y))
			var color = _color_para_terreno(terreno)
			terreno_base_image.set_pixel(x, y, color)
	
	# Generar niebla base inicial
	_actualizar_niebla_base()

func _actualizar_niebla_base():
	if not niebla:
		return
	
	var w = int(resolucion_interna.x)
	var h = int(resolucion_interna.y)
	
	for x in range(w):
		for y in range(h):
			var mundo_x = (float(x) / float(w)) * mundo_ancho - (mundo_ancho / 2.0)
			var mundo_y = (float(y) / float(h)) * mundo_alto - (mundo_alto / 2.0)
			
			var celda_niebla = niebla._pos_a_celda(Vector2(mundo_x, mundo_y))
			var index = int(celda_niebla.y) * niebla.celdas_ancho + int(celda_niebla.x)
			
			var alpha = 1.0
			if index >= 0 and index < niebla.grid.size():
				var estado = niebla.grid[index]
				if estado == 0:  # OSCURO
					alpha = 1.0
				elif estado == 1:  # RECORDADO
					alpha = 0.5
				else:  # VISIBLE
					alpha = 0.0
			
			niebla_base_image.set_pixel(x, y, Color(0, 0, 0, alpha))

func _color_para_terreno(terreno: int) -> Color:
	match terreno:
		GeneradorRecursos.TipoTerreno.NORMAL:
			return Color(0.45, 0.65, 0.35)
		GeneradorRecursos.TipoTerreno.BOSQUE:
			return Color(0.15, 0.45, 0.15)
		GeneradorRecursos.TipoTerreno.MINERAL:
			return Color(0.55, 0.55, 0.7)
		GeneradorRecursos.TipoTerreno.AGUA:
			return Color(0.2, 0.4, 0.75)
		GeneradorRecursos.TipoTerreno.CHATARRA:
			return Color(0.55, 0.45, 0.3)
		GeneradorRecursos.TipoTerreno.MONTAÑA:
			return Color(0.45, 0.35, 0.25)
		_:
			return Color(0.45, 0.65, 0.35)

func _process(delta):
	timer_actualizacion += delta
	timer_niebla += delta
	
	# Actualizar niebla base menos frecuentemente
	if timer_niebla >= intervalo_niebla:
		timer_niebla = 0.0
		_actualizar_niebla_base()
	
	# Actualizar minimapa completo
	if timer_actualizacion >= intervalo_actualizacion:
		timer_actualizacion = 0.0
		_redibujar_minimapa()

func _redibujar_minimapa():
	if not terreno_base_image:
		return
	
	var w = int(resolucion_interna.x)
	var h = int(resolucion_interna.y)
	
	# 1. Copiar terreno base
	minimap_image.blit_rect(terreno_base_image, Rect2i(0, 0, w, h), Vector2i.ZERO)
	
	# 2. Aplicar niebla usando blit_rect (MUY rápido)
	minimap_image.blend_rect(niebla_base_image, Rect2i(0, 0, w, h), Vector2i.ZERO)
	
	# 3. Dibujar edificios buenos (cuadrados azules)
	for bueno in get_tree().get_nodes_in_group("buenos"):
		if is_instance_valid(bueno) and bueno.get("tipo_edificio"):
			if _es_visible_en_minimapa(bueno.global_position):
				var px = _mundo_a_pixel(bueno.global_position)
				_dibujar_cuadrado(px, 2, Color(0.2, 0.6, 1.0))
	
	# 4. Dibujar unidades buenas (puntos verdes)
	for bueno in get_tree().get_nodes_in_group("buenos"):
		if is_instance_valid(bueno) and not bueno.get("tipo_edificio"):
			if _es_visible_en_minimapa(bueno.global_position):
				var px = _mundo_a_pixel(bueno.global_position)
				minimap_image.set_pixel(int(px.x), int(px.y), Color.GREEN)
	
	# 5. Dibujar enemigos visibles (puntos rojos)
	for malo in get_tree().get_nodes_in_group("malos"):
		if is_instance_valid(malo) and malo.visible:
			var px = _mundo_a_pixel(malo.global_position)
			minimap_image.set_pixel(int(px.x), int(px.y), Color.RED)
	
	# 6. Dibujar rectángulo de la cámara
	if camara:
		_dibujar_rectangulo_camara(w, h)
	
	# Actualizar textura
	minimap_texture.update(minimap_image)

func _mundo_a_pixel(pos_mundo: Vector2) -> Vector2:
	var w = resolucion_interna.x
	var h = resolucion_interna.y
	var px = ((pos_mundo.x + mundo_ancho / 2.0) / mundo_ancho) * w
	var py = ((pos_mundo.y + mundo_alto / 2.0) / mundo_alto) * h
	return Vector2(clamp(px, 0, w - 1), clamp(py, 0, h - 1))

func _pixel_a_mundo(px: Vector2) -> Vector2:
	var mundo_x = (px.x / resolucion_interna.x) * mundo_ancho - (mundo_ancho / 2.0)
	var mundo_y = (px.y / resolucion_interna.y) * mundo_alto - (mundo_alto / 2.0)
	return Vector2(mundo_x, mundo_y)

func _es_visible_en_minimapa(pos_mundo: Vector2) -> bool:
	if not niebla:
		return true
	var celda = niebla._pos_a_celda(pos_mundo)
	var index = int(celda.y) * niebla.celdas_ancho + int(celda.x)
	if index >= 0 and index < niebla.grid.size():
		return niebla.grid[index] >= 1
	return false

func _dibujar_cuadrado(centro: Vector2, radio: int, color: Color):
	for dx in range(-radio, radio + 1):
		for dy in range(-radio, radio + 1):
			var px = int(centro.x) + dx
			var py = int(centro.y) + dy
			if px >= 0 and px < resolucion_interna.x and py >= 0 and py < resolucion_interna.y:
				minimap_image.set_pixel(px, py, color)

func _dibujar_rectangulo_camara(w: int, h: int):
	if not camara:
		return
		
	var viewport_size = get_viewport().get_visible_rect().size
	var zoom_actual = camara.zoom.x if camara.zoom.x > 0 else 1.0
	
	var mundo_visible_w = viewport_size.x / zoom_actual
	var mundo_visible_h = viewport_size.y / zoom_actual
	
	var centro_cam = camara.global_position
	var esquina_sup_izq = Vector2(centro_cam.x - mundo_visible_w / 2.0, centro_cam.y - mundo_visible_h / 2.0)
	var esquina_inf_der = Vector2(centro_cam.x + mundo_visible_w / 2.0, centro_cam.y + mundo_visible_h / 2.0)
	
	var px1 = _mundo_a_pixel(esquina_sup_izq)
	var px2 = _mundo_a_pixel(esquina_inf_der)
	
	var color_marco = Color(0.97, 0.597, 0.748, 1.0)
	var grosor = 4
	
	# Dibujar borde superior e inferior
	for x in range(int(px1.x), int(px2.x) + 1):
		if x >= 0 and x < w:
			for g in range(grosor):
				var y_top = int(px1.y) + g
				var y_bot = int(px2.y) - g
				if y_top >= 0 and y_top < h:
					minimap_image.set_pixel(x, y_top, color_marco)
				if y_bot >= 0 and y_bot < h:
					minimap_image.set_pixel(x, y_bot, color_marco)
					
	# Dibujar borde izquierdo y derecho
	for y in range(int(px1.y), int(px2.y) + 1):
		if y >= 0 and y < h:
			for g in range(grosor):
				var x_izq = int(px1.x) + g
				var x_der = int(px2.x) - g
				if x_izq >= 0 and x_izq < w:
					minimap_image.set_pixel(x_izq, y, color_marco)
				if x_der >= 0 and x_der < w:
					minimap_image.set_pixel(x_der, y, color_marco)

func _on_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pos_local = event.position
		# Convertir de posición visual (150x150) a resolución interna (100x100)
		var escala = resolucion_interna / tamano_minimapa
		var pos_interna = pos_local * escala
		var mundo_pos = _pixel_a_mundo(pos_interna)
		if camara:
			camara.global_position = mundo_pos
