extends Button

@onready var dialogo_confirmacion = get_node_or_null("../DialogoConfirmacion")

func _ready():
	pressed.connect(_on_boton_pulsado)
	
	if dialogo_confirmacion:
		# Conectar las señales del diálogo por código para saber qué botón pulsó el jugador
		dialogo_confirmacion.confirmed.connect(_on_confirmar)
		dialogo_confirmacion.canceled.connect(_on_cancelar)
		# Asegurar que empieza oculto
		dialogo_confirmacion.visible = false

func _on_boton_pulsado():
	if dialogo_confirmacion:
		# En Godot 4, los diálogos se abren con popup_centered(), no con visible = true
		dialogo_confirmacion.popup_centered()
	else:
		# Fallback si no existe el diálogo en la escena
		print("🔙 Volviendo al menú principal...")
		GameManager.cambiar_a_menu()

func _on_confirmar():
	# El usuario pulsó "OK/Aceptar" en el diálogo
	print("🔙 Confirmed: Volviendo al menú principal...")
	GameManager.cambiar_a_menu()

func _on_cancelar():
	# El usuario pulsó "Cancelar" (el diálogo se cierra solo, pero lo aseguramos)
	dialogo_confirmacion.visible = false
