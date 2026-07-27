extends Camera2D

var velocidad_camara = 500

# Variables de Zoom
@export var velocidad_zoom: float = 0.2
@export var zoom_minimo: float = 0.5
@export var zoom_maximo: float = 2.5

# Límites del mapa (deben coincidir con Spawner y MaloBase)
@export var limite_x: float = 2000.0
@export var limite_y: float = 2000.0

func _process(delta):
	var direccion = Vector2.ZERO
	
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direccion.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direccion.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direccion.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direccion.x += 1
	
	# Mover la cámara
	position += direccion.normalized() * velocidad_camara * delta
	
	# Limitar la posición a los bordes del mapa
	position.x = clamp(position.x, -limite_x, limite_x)
	position.y = clamp(position.y, -limite_y, limite_y)

func _unhandled_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom -= Vector2(velocidad_zoom, velocidad_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom += Vector2(velocidad_zoom, velocidad_zoom)
		
		var zoom_min = Vector2(zoom_minimo, zoom_minimo)
		var zoom_max = Vector2(zoom_maximo, zoom_maximo)
		zoom = zoom.clamp(zoom_min, zoom_max)
