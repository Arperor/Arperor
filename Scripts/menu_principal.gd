extends Control

func _ready():
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	# Conectar los botones manualmente
	$ButtonJugar.pressed.connect(_on_jugar_presionado)
	$ButtonSalir.pressed.connect(_on_salir_presionado)

func _on_jugar_presionado():
	# Llamar directamente al GameManager
	GameManager.cambiar_a_juego()

func _on_salir_presionado():
	# Salir del juego
	get_tree().quit()
