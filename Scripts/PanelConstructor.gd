extends VBoxContainer
@onready var btn_base = $BotonBase
@onready var btn_casa = $BotonCasa
@onready var btn_cuartel = $BotonCuartel
@onready var btn_torre = $BotonTorre
@onready var btn_muro = $BotonMuro
@onready var btn_asserradero = $BotonAsserradero
@onready var btn_granja = $BotonGranja
@onready var btn_puerto = $BotonPuerto
@onready var btn_chatarreria = $BotonChatarreria
@onready var btn_mina = $BotonMina
@onready var btn_almacen = $BotonAlmacen
@onready var btn_reparar = $BotonReparar 
var constructor_ref = null
var costes_edificios: Dictionary = {}
var ruta_base = "res://Escenas/Base.tscn"
var ruta_casa = "res://Escenas/Casa.tscn"
var ruta_cuartel = "res://Escenas/Cuartel.tscn"
var ruta_torre = "res://Escenas/Torre.tscn"
var ruta_muro = "res://Escenas/Muro.tscn"
var ruta_asserradero = "res://Escenas/Asserradero.tscn"
var ruta_granja = "res://Escenas/Granja.tscn"
var ruta_puerto = "res://Escenas/Puerto.tscn"
var ruta_chatarreria = "res://Escenas/Chatarreria.tscn"
var ruta_mina = "res://Escenas/Mina.tscn"
var ruta_almacen = "res://Escenas/Almacen.tscn"

func _ready():
	add_to_group("panel_constructor")
	btn_base.pressed.connect(_construir.bind(ruta_base))
	btn_casa.pressed.connect(_construir.bind(ruta_casa))
	btn_cuartel.pressed.connect(_construir.bind(ruta_cuartel))
	btn_torre.pressed.connect(_construir.bind(ruta_torre))
	btn_muro.pressed.connect(_construir.bind(ruta_muro))
	btn_asserradero.pressed.connect(_construir.bind(ruta_asserradero))
	btn_granja.pressed.connect(_construir.bind(ruta_granja))
	btn_puerto.pressed.connect(_construir.bind(ruta_puerto))
	btn_chatarreria.pressed.connect(_construir.bind(ruta_chatarreria))
	btn_mina.pressed.connect(_construir.bind(ruta_mina))
	btn_almacen.pressed.connect(_construir.bind(ruta_almacen))
		# Cargar costes de edificios una sola vez
	costes_edificios[ruta_base] = _obtener_coste_escena(ruta_base)
	costes_edificios[ruta_casa] = _obtener_coste_escena(ruta_casa)
	costes_edificios[ruta_cuartel] = _obtener_coste_escena(ruta_cuartel)
	costes_edificios[ruta_torre] = _obtener_coste_escena(ruta_torre)
	costes_edificios[ruta_muro] = _obtener_coste_escena(ruta_muro)
	costes_edificios[ruta_asserradero] = _obtener_coste_escena(ruta_asserradero)
	costes_edificios[ruta_granja] = _obtener_coste_escena(ruta_granja)
	costes_edificios[ruta_puerto] = _obtener_coste_escena(ruta_puerto)
	costes_edificios[ruta_chatarreria] = _obtener_coste_escena(ruta_chatarreria)
	costes_edificios[ruta_mina] = _obtener_coste_escena(ruta_mina)
	costes_edificios[ruta_almacen] = _obtener_coste_escena(ruta_almacen)
	visible = false
	
	# Conectar tooltips estáticamente
	_conectar_tooltip(btn_base, "Base", ruta_base)
	_conectar_tooltip(btn_casa, "Casa", ruta_casa)
	_conectar_tooltip(btn_cuartel, "Cuartel", ruta_cuartel)
	_conectar_tooltip(btn_torre, "Torre", ruta_torre)
	_conectar_tooltip(btn_muro, "Muro", ruta_muro)
	_conectar_tooltip(btn_asserradero, "Aserradero", ruta_asserradero)
	_conectar_tooltip(btn_granja, "Granja", ruta_granja)
	_conectar_tooltip(btn_puerto, "Puerto", ruta_puerto)
	_conectar_tooltip(btn_chatarreria, "Chatarrería", ruta_chatarreria)
	_conectar_tooltip(btn_mina, "Mina", ruta_mina)
	_conectar_tooltip(btn_almacen, "Almacén", ruta_almacen)
	btn_reparar.pressed.connect(_on_reparar_pressed)
	btn_reparar.visible = false

func mostrar(constructor):
	constructor_ref = constructor
	visible = true
	_actualizar_botones()

func forzar_actualizacion():
	if visible:
		_actualizar_botones()

func ocultar():
	visible = false
	constructor_ref = null

func _actualizar_botones():
	var hay_base = _hay_base_en_juego()
	# Botón base: solo visible si NO hay base
	btn_base.visible = not hay_base
	# Otros botones: solo visibles si SÍ hay base
	btn_casa.visible = hay_base
	btn_cuartel.visible = hay_base
	btn_torre.visible = hay_base
	btn_muro.visible = hay_base
	btn_asserradero.visible = hay_base
	btn_granja.visible = hay_base
	btn_puerto.visible = hay_base
	btn_chatarreria.visible = hay_base
	btn_mina.visible = hay_base
	btn_almacen.visible = hay_base
	# Actualizar estados de disabled según recursos
	# Actualizar estados de disabled según recursos (OPTIMIZADO)
	if hay_base:
		btn_casa.disabled = not EconomiaManager.tiene_recursos(costes_edificios[ruta_casa])
		btn_cuartel.disabled = not EconomiaManager.tiene_recursos(costes_edificios[ruta_cuartel])
		btn_torre.disabled = not EconomiaManager.tiene_recursos(costes_edificios[ruta_torre])
		btn_muro.disabled = not EconomiaManager.tiene_recursos(costes_edificios[ruta_muro])
		btn_asserradero.disabled = not EconomiaManager.tiene_recursos(costes_edificios[ruta_asserradero])
		btn_granja.disabled = not EconomiaManager.tiene_recursos(costes_edificios[ruta_granja])
		btn_puerto.disabled = not EconomiaManager.tiene_recursos(costes_edificios[ruta_puerto])
		btn_chatarreria.disabled = not EconomiaManager.tiene_recursos(costes_edificios[ruta_chatarreria])
		btn_mina.disabled = not EconomiaManager.tiene_recursos(costes_edificios[ruta_mina])
		btn_almacen.disabled = not EconomiaManager.tiene_recursos(costes_edificios[ruta_almacen])
	else:
		btn_base.disabled = not EconomiaManager.tiene_recursos(costes_edificios[ruta_base])
# En PanelConstructor.gd
func _hay_base_en_juego() -> bool:
	if EconomiaManager.base_construida:
		# Verificar que realmente existe una Base viva (no fantasma)
		for bueno in get_tree().get_nodes_in_group("buenos"):
			if bueno.has_method("get") and bueno.get("tipo_edificio") == "Base":
				var stats = bueno.get_node_or_null("Stats")
				if stats and stats.vida_actual > 0 and bueno.get("en_construccion") != true:
					return true
		# Si llegó aquí, la Base está muerta/ghosteada: resetear flag
		EconomiaManager.base_construida = false
		return false
	return false

func _obtener_coste_escena(ruta: String) -> Dictionary:
	var escena = load(ruta)
	if escena:
		var instancia_temporal = escena.instantiate()
		var coste = instancia_temporal.get("coste_construccion")
		instancia_temporal.free()
		return coste if coste else {}
	return {}

func _process(_delta):
	# Actualizar siempre, no solo cuando está visible
	_actualizar_botones()
	btn_reparar.visible = (constructor_ref != null and _buscar_fantasma_cercano() != null)

func _construir(ruta_escena: String):
	var constructor_script = get_node_or_null("/root/Mapa/Constructor")
	if not constructor_script:
		return
	
	if ruta_escena == ruta_base and _hay_base_en_juego():
		return
	
	var escena = load(ruta_escena)
	if not escena:
		return
	
	var coste = _obtener_coste_escena(ruta_escena)
	if not EconomiaManager.tiene_recursos(coste):
		return

	var modo_multiples = not Input.is_key_pressed(KEY_SHIFT)

	if ruta_escena == ruta_base:
		modo_multiples = false
	constructor_script.iniciar_construccion(escena, modo_multiples, ruta_escena)

func _conectar_tooltip(boton: Button, nombre: String, ruta: String):
	boton.mouse_entered.connect(_mostrar_tooltip_edificio.bind(nombre, ruta))
	boton.mouse_exited.connect(_ocultar_tooltip)

func _mostrar_tooltip_edificio(nombre: String, ruta: String):
	var tooltip = get_node_or_null("/root/Mapa/UI/TooltipGlobal")
	if not tooltip:
		return
	
	var coste = costes_edificios.get(ruta, {})
	var puede = EconomiaManager.tiene_recursos(coste)
	var color_coste = "green" if puede else "red"
	
	var texto = "[b]%s[/b]\n\n" % nombre
	texto += "[color=%s]Coste:[/color]\n" % color_coste
	for recurso in coste:
		var cantidad = coste[recurso]
		var icono = _icono_recurso(recurso)
		texto += "  %s %d\n" % [icono, cantidad]
	
	tooltip.mostrar_tooltip(texto)

func _ocultar_tooltip():
	var tooltip = get_node_or_null("/root/Mapa/UI/TooltipGlobal")
	if tooltip:
		tooltip.ocultar_tooltip()

func _icono_recurso(recurso: String) -> String:
	match recurso:
		"dinero": return "🍻"
		"madera": return "🌲"
		"comida": return "🥧"
		"mineral": return "⛏️"
		"chatarra": return "⚙"
		"ciencia": return "🔬"
		"poblacion": return "👨‍👩‍👧‍👦"
		_: return recurso

func _on_reparar_pressed():
	if not constructor_ref:
		return
	
	var fantasma_cercano = _buscar_fantasma_cercano()
	if fantasma_cercano:
		var ia = constructor_ref.get_node_or_null("IABueno")
		if ia and ia.has_method("construir_edificio"):
			ia.construir_edificio(fantasma_cercano)

func _buscar_fantasma_cercano():
	if not constructor_ref:
		return null
	
	var fantasmas = []
	for bueno in get_tree().get_nodes_in_group("buenos"):
		if bueno.get("en_construccion") == true and bueno.has_node("Stats"):
			var stats = bueno.get_node("Stats")
			if stats.vida_actual < stats.vida_maxima:
				fantasmas.append(bueno)
	
	if fantasmas.size() == 0:
		return null
	
	var mas_cercano = null
	var distancia_minima = INF
	for fantasma in fantasmas:
		var dist = constructor_ref.global_position.distance_to(fantasma.global_position)
		if dist < distancia_minima:
			distancia_minima = dist
			mas_cercano = fantasma
	
	return mas_cercano
