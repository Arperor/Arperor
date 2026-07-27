extends Node2D

# Señales para el SelectionManager
signal clic_simple(posicion)
signal caja_seleccion(area)
signal orden_mover(posicion) # Nueva señal para el clic derecho

var arrastrando = false
var inicio = Vector2.ZERO
var fin = Vector2.ZERO

var tiempo_click = 0.0
var tiempo_espera = 0.15 # Tus 500ms

func _unhandled_input(event):
	# --- CLIC IZQUIERDO (Selección) ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			arrastrando = false
			tiempo_click = Time.get_ticks_msec() / 500.0
			inicio = get_global_mouse_position()
			fin = inicio
		else:
			arrastrando = false
			_finalizar_seleccion()
			queue_redraw()
			
	elif event is InputEventMouseMotion:
		var tiempo_actual = Time.get_ticks_msec() / 500.0
		if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and (tiempo_actual - tiempo_click) > tiempo_espera:
			if not arrastrando:
				arrastrando = true
			fin = get_global_mouse_position()
			queue_redraw()

	# --- CLIC DERECHO (Acción/Mover) ---
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			orden_mover.emit(get_global_mouse_position())

func _draw():
	if arrastrando:
		var rect = Rect2(inicio, fin - inicio).abs()
		draw_rect(rect, Color(0, 1, 0, 0.3))
		draw_rect(rect, Color(0, 1, 0, 1), false, 2)

func _finalizar_seleccion():
	var area = Rect2(inicio, fin - inicio).abs()
	if area.size.length() < 10:
		clic_simple.emit(inicio)
	else:
		caja_seleccion.emit(area)
