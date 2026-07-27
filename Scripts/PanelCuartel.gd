extends VBoxContainer

@onready var btn_explorador: Button = $BotonExplorador
@onready var btn_soldado: Button = $BotonSoldado
@onready var btn_sniper: Button = $BotonSniper

var cuartel_ref = null

# Cache de definiciones (una sola lectura)
var def_explorador: Dictionary = {}
var def_soldado: Dictionary = {}
var def_sniper: Dictionary = {}

func _ready():
	# Cargar definiciones una sola vez
	def_explorador = DefinicionesUnidades.obtener_definicion("Explorador")
	def_soldado = DefinicionesUnidades.obtener_definicion("Soldado")
	def_sniper = DefinicionesUnidades.obtener_definicion("Sniper")
	
	# Conectar señales de pulsación
	btn_explorador.pressed.connect(_on_explorador_pressed)
	btn_soldado.pressed.connect(_on_soldado_pressed)
	btn_sniper.pressed.connect(_on_sniper_pressed)
	
	# Conectar señales de tooltip
	btn_explorador.mouse_entered.connect(_mostrar_tooltip.bind("Explorador", def_explorador))
	btn_explorador.mouse_exited.connect(_ocultar_tooltip)
	btn_soldado.mouse_entered.connect(_mostrar_tooltip.bind("Soldado", def_soldado))
	btn_soldado.mouse_exited.connect(_ocultar_tooltip)
	btn_sniper.mouse_entered.connect(_mostrar_tooltip.bind("Sniper", def_sniper))
	btn_sniper.mouse_exited.connect(_ocultar_tooltip)

func _process(_delta):
	# Actualizar estado visual (disabled y color) de cada botón según recursos y población
	_actualizar_boton(btn_explorador, def_explorador)
	_actualizar_boton(btn_soldado, def_soldado)
	_actualizar_boton(btn_sniper, def_sniper)

func _actualizar_boton(boton: Button, definicion: Dictionary):
	if definicion.is_empty():
		return
	
	var puede = EconomiaManager.tiene_recursos(definicion["coste"])
	var hay_poblacion = EconomiaManager.hay_poblacion_disponible(1)
	
	boton.disabled = not (puede and hay_poblacion)
	
	if puede and hay_poblacion:
		boton.add_theme_color_override("font_color", Color.GREEN)
	else:
		boton.add_theme_color_override("font_color", Color.RED)

func mostrar_panel(cuartel):
	visible = true
	cuartel_ref = cuartel

func ocultar_panel():
	visible = false
	cuartel_ref = null

# --- TOOLTIPS ---
func _mostrar_tooltip(tipo: String, definicion: Dictionary):
	var tooltip = get_node_or_null("/root/Mapa/UI/TooltipGlobal")
	if not tooltip:
		return
	
	var puede = EconomiaManager.tiene_recursos(definicion["coste"])
	var coste_formateado = DefinicionesUnidades.formatear_coste(tipo)
	var color_coste = "green" if puede else "red"
	
	var texto = "[b]%s[/b]\n" % definicion.get("nombre", tipo)
	texto += "%s\n\n" % definicion.get("descripcion", "")
	texto += "[color=%s]Coste: %s[/color]" % [color_coste, coste_formateado]
	
	tooltip.mostrar_tooltip(texto)

func _ocultar_tooltip():
	var tooltip = get_node_or_null("/root/Mapa/UI/TooltipGlobal")
	if tooltip:
		tooltip.ocultar_tooltip()

# --- ACCIONES DE LOS BOTONES ---
func _on_explorador_pressed():
	_crear_unidad(def_explorador)

func _on_soldado_pressed():
	_crear_unidad(def_soldado)

func _on_sniper_pressed():
	_crear_unidad(def_sniper)

func _crear_unidad(definicion: Dictionary):
	if not cuartel_ref:
		return
	if definicion.is_empty():
		return
	
	# Verificar que se puede permitir
	if not EconomiaManager.tiene_recursos(definicion["coste"]):
		return
	if not EconomiaManager.hay_poblacion_disponible(1):
		return
	
	# Gastar recursos y población
	EconomiaManager.gastar_recursos(definicion["coste"])
	EconomiaManager.cambiar_poblacion(1)
	
	# Instanciar la unidad
	var escena = definicion.get("escena")
	if escena:
		var unidad = escena.instantiate()
		unidad.global_position = cuartel_ref.global_position + Vector2(100, 0)
		get_tree().current_scene.add_child(unidad)
		unidad.add_to_group("buenos")
