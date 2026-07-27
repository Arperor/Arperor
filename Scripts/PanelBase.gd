extends HBoxContainer

@export var coste_constructor: int = 50
@export var coste_explorador: int = 75
@export var escena_constructor: PackedScene
@export var escena_explorador: PackedScene

@onready var boton_constructor = $BotonConstructor

var base_seleccionada = null

func _ready():
	boton_constructor.pressed.connect(_on_constructor_pressed)
	boton_constructor.mouse_entered.connect(_mostrar_tooltip_constructor)
	boton_constructor.mouse_exited.connect(_ocultar_tooltip)
	visible = false  # Oculto por defecto

func mostrar_panel(base):
	base_seleccionada = base
	visible = true
	_actualizar_botones()

func ocultar_panel():
	base_seleccionada = null
	visible = false

func _actualizar_botones():
	# Cambia todas las líneas así:
	if EconomiaManager.recursos["dinero"] < coste_constructor or not EconomiaManager.hay_poblacion_disponible(1):
		boton_constructor.disabled = true
	else:
		boton_constructor.disabled = false

func _process(_delta):
	if visible:
		_actualizar_botones()

func _on_constructor_pressed():
	if not base_seleccionada:
		return
	if EconomiaManager.gastar_dinero(coste_constructor) and EconomiaManager.hay_poblacion_disponible(1):
		_crear_unidad(escena_constructor)

func _on_explorador_pressed():
	if not base_seleccionada:
		return
	if EconomiaManager.gastar_dinero(coste_explorador) and EconomiaManager.hay_poblacion_disponible(1):
		_crear_unidad(escena_explorador)

func _crear_unidad(escena: PackedScene):
	var unidad = escena.instantiate()
	# Posicionar al lado de la base
	unidad.global_position = base_seleccionada.global_position + Vector2(100, 0)
	base_seleccionada.get_parent().add_child(unidad)
	unidad.add_to_group("buenos")
	
	# Aumentar población actual
	EconomiaManager.cambiar_poblacion(1)
func _mostrar_tooltip_constructor():
	var tooltip = get_node_or_null("/root/Mapa/UI/TooltipGlobal")
	if not tooltip:
		return
	
	var coste = {"dinero": coste_constructor}
	var puede = EconomiaManager.tiene_recursos(coste) and EconomiaManager.hay_poblacion_disponible(1)
	var color_coste = "green" if puede else "red"
	
	var texto = "[b]Constructor[/b]\n"
	texto += "Construye y repara edificios.\n\n"
	texto += "[color=%s]Coste:[/color]\n" % color_coste
	texto += "  💰 %d\n" % coste_constructor
	texto += "  👤 1\n"
	
	tooltip.mostrar_tooltip(texto)

func _ocultar_tooltip():
	var tooltip = get_node_or_null("/root/Mapa/UI/TooltipGlobal")
	if tooltip:
		tooltip.ocultar_tooltip()
