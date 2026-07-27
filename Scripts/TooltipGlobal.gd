extends PanelContainer

@onready var label = $Label

func _ready():
	visible = false
	z_index = 1000
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	EconomiaManager.recursos_cambiados.connect(_on_recursos_cambiados)

func mostrar_tooltip(texto: String, posicion_mouse: Vector2 = Vector2.ZERO):
	label.text = texto
	visible = true
	
	if posicion_mouse == Vector2.ZERO:
		posicion_mouse = get_global_mouse_position()
	
	# Calcular posición inteligente
	await get_tree().process_frame  # Esperar un frame para que el tamaño se actualice
	var tamano_tooltip = size
	var tamano_ventana = Vector2(DisplayServer.window_get_size())
	var offset = Vector2(15, 15)
	var pos_final = posicion_mouse + offset
	
	# Ajustar si se sale por la derecha
	if pos_final.x + tamano_tooltip.x > tamano_ventana.x:
		pos_final.x = posicion_mouse.x - tamano_tooltip.x - offset.x
	
	# Ajustar si se sale por abajo
	if pos_final.y + tamano_tooltip.y > tamano_ventana.y:
		pos_final.y = posicion_mouse.y - tamano_tooltip.y - offset.y
	
	# Asegurar que no se sale por la izquierda o arriba
	pos_final.x = max(0, pos_final.x)
	pos_final.y = max(0, pos_final.y)
	
	global_position = pos_final

func ocultar_tooltip():
	visible = false

func _on_recursos_cambiados(_d, _pa, _pm):
	# Si está visible, se actualizará cuando el botón lo reconfigure
	pass
