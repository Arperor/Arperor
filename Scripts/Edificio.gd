extends CharacterBody2D

var timer_produccion: float = 0.0
var esta_seleccionada = false
var en_construccion: bool = false
var timer_dinero: float = 0.0
var ya_murio: bool = false
@export var coste_construccion: Dictionary = {
	"dinero": 100
}
@export var tipo_edificio: String = "Base"
@export var suma_poblacion: int = 5
@export var coste_poblacion: int = 5
@export var generacion_dinero: int = 5
@export var tiempo_generacion: float = 3.0
@export var tamano_tiles: Vector2 = Vector2(2, 2)
@onready var mi_sprite = $Sprite2D
@onready var stats = $Stats
@export var enemigos_al_morir: int = 3
@export_enum("dinero", "madera", "comida", "mineral", "chatarra", "ciencia") var recurso_generado: String = "dinero"
@export var cantidad_base_produccion: int = 5  # Se multiplica por tiles detectados si hay AreaExtraccion
@onready var area_extraccion = get_node_or_null("AreaExtraccion")

func _ready():
	if en_construccion or stats.vida_actual <= 0:
		return
	activar_edificio()

func _process(delta):
	if en_construccion and stats.vida_actual > 0 and stats.vida_actual < stats.vida_maxima:
		pass
	elif en_construccion and stats.vida_actual >= stats.vida_maxima:
		en_construccion = false
		reactivar_edificio()
	
	if not en_construccion:
		timer_produccion += delta
		if timer_produccion >= tiempo_generacion:
			_generar_recurso()
			timer_produccion = 0.0

func reactivar_edificio():
	en_construccion = false
	modulate = Color(1, 1, 1, 1)
	for child in get_children():
		if child is CollisionShape2D:
			child.disabled = false
	if self is CharacterBody2D:
		set_collision_layer_value(2, true)
		set_collision_mask_value(1, true)
		set_collision_mask_value(4, true)
	set_physics_process(true)
	set_process(true)
	add_to_group("buenos")
	
	var zona_atraccion = get_node_or_null("ZonaAtraccion")
	if zona_atraccion:
		zona_atraccion.visible = true
		zona_atraccion.monitoring = true
		zona_atraccion.monitorable = true
		zona_atraccion.set_process(true)
		zona_atraccion.set_physics_process(true)
	
	if has_node("Stats"):
		if stats.stats_cambiados.is_connected(_on_stats_cambiados_fantasma):
			stats.stats_cambiados.disconnect(_on_stats_cambiados_fantasma)
		get_node("Stats").set_process(true)
		get_node("Stats").set_physics_process(true)
	
	ya_murio = false
	
	var barra_vida = get_node_or_null("BarraVida")
	if barra_vida:
		barra_vida.visible = true
	
	if tipo_edificio == "Base" and not EconomiaManager.base_construida:
		EconomiaManager.marcar_base_construida()
	EconomiaManager.aumentar_poblacion_maxima(suma_poblacion)
	EconomiaManager.cambiar_poblacion(coste_poblacion)
	
	# NUEVO Bug 3: Almacén aumenta capacidades también al reactivarse
	if tipo_edificio == "Almacen":
		EconomiaManager.aumentar_capacidad_maxima("madera", 100)
		EconomiaManager.aumentar_capacidad_maxima("comida", 100)
		EconomiaManager.aumentar_capacidad_maxima("mineral", 100)
		EconomiaManager.aumentar_capacidad_maxima("chatarra", 100)
	
	# NUEVO Bug 7: Notificar paneles al reparar la Base
	if tipo_edificio == "Base":
		for panel in get_tree().get_nodes_in_group("panel_constructor"):
			if panel.has_method("forzar_actualizacion"):
				panel.forzar_actualizacion()

func activar_edificio():
	modulate = Color(1, 1, 1, 1)
	for child in get_children():
		if child is CollisionShape2D:
			child.disabled = false
	
	if self is CharacterBody2D:
		set_collision_layer_value(2, true)
		set_collision_mask_value(1, true)
		set_collision_mask_value(4, true)
	
	EconomiaManager.aumentar_poblacion_maxima(suma_poblacion)
	EconomiaManager.cambiar_poblacion(coste_poblacion)
	if tipo_edificio == "Almacen":
		EconomiaManager.aumentar_capacidad_maxima("madera", 100)
		EconomiaManager.aumentar_capacidad_maxima("comida", 100)
		EconomiaManager.aumentar_capacidad_maxima("mineral", 100)
		EconomiaManager.aumentar_capacidad_maxima("chatarra", 100)
	if tipo_edificio == "Base" and not EconomiaManager.base_construida:
		EconomiaManager.marcar_base_construida()
		# NUEVO: Notificar a todos los paneles de constructor
		for panel in get_tree().get_nodes_in_group("panel_constructor"):
			if panel.has_method("forzar_actualizacion"):
				panel.forzar_actualizacion()

func morir():
	if ya_murio:
		return
	ya_murio = true
	if not en_construccion:
		EconomiaManager.aumentar_poblacion_maxima(-suma_poblacion)
		EconomiaManager.cambiar_poblacion(-coste_poblacion)
	convertir_en_fantasma()
	if tipo_edificio == "Base":
		EconomiaManager.base_construida = false
	soltar_enemigos()

func convertir_en_fantasma():
	
	# 1. Desactivar colisiones
	for child in get_children():
		if child is CollisionShape2D:
			child.disabled = true
	
	if self is CharacterBody2D:
		collision_layer = 0
		collision_mask = 0
	
	# 2. Desactivar procesamiento
	set_physics_process(false)
	set_process(false)
	
	# 3. Quitar del grupo "buenos"
	remove_from_group("buenos")
	
	# 4. Desactivar zona de atracción
	var zona_atraccion = get_node_or_null("ZonaAtraccion")
	if zona_atraccion:
		
		# Expulsar malos
		var malos_dentro = zona_atraccion.get("buenos_dentro")
		if malos_dentro:
			for malo in malos_dentro:
				if is_instance_valid(malo) and malo.has_node("IA"):
					malo.get_node("IA").perder_atraccion(self)
			malos_dentro.clear()
		
		# Desactivar
		zona_atraccion.monitoring = false
		zona_atraccion.monitorable = false
		zona_atraccion.visible = false
		zona_atraccion.set_process(false)
		zona_atraccion.set_physics_process(false)

	# 5. Cambiar color
	modulate = Color(0.2, 0.2, 0.2, 0.6)
	
	# 6. Marcar como destruido
	en_construccion = true
	
	# 7. NUEVO: Conectar señal para detectar cuando se rellena la vida
	if has_node("Stats"):
		stats.stats_cambiados.connect(_on_stats_cambiados_fantasma)

func _on_stats_cambiados_fantasma(vida_actual: int, vida_maxima: int):
	if vida_actual >= vida_maxima and en_construccion:
		# Desconectar la señal
		if stats.stats_cambiados.is_connected(_on_stats_cambiados_fantasma):
			stats.stats_cambiados.disconnect(_on_stats_cambiados_fantasma)
		reactivar_edificio()

func soltar_enemigos():
	var spawner = get_node_or_null("/root/Mapa/Spawner")
	if spawner == null:
		spawner = get_parent()
	
	for i in range(enemigos_al_morir):
		var malo = preload("res://Escenas/MaloBase.tscn").instantiate()
		
		var angulo = randf() * TAU
		var distancia = randf_range(10, 25)
		malo.global_position = global_position + Vector2(cos(angulo), sin(angulo)) * distancia
		
		spawner.add_child(malo)

func seleccionar():
	esta_seleccionada = true
	var borde = get_node_or_null("BordeVerde")
	if borde: borde.mostrar()
	
	var nombre_panel = "Panel" + tipo_edificio.capitalize()
	var panel = get_node_or_null("/root/Mapa/UI/" + nombre_panel)
	if panel and panel.has_method("mostrar_panel"):
		panel.mostrar_panel(self)

func deseleccionar():
	esta_seleccionada = false
	var borde = get_node_or_null("BordeVerde")
	if borde: borde.ocultar()
	
	var nombre_panel = "Panel" + tipo_edificio.capitalize()
	var panel = get_node_or_null("/root/Mapa/UI/" + nombre_panel)
	if panel and panel.has_method("ocultar_panel"):
		panel.ocultar_panel()

func _generar_recurso():
	var cantidad_final: int = 0
	
	if area_extraccion and area_extraccion.has_method("get_produccion_multiplicador"):
		# Edificio extractor: cantidad_base × tiles_detectados
		var tiles = area_extraccion.get_produccion_multiplicador()
		cantidad_final = cantidad_base_produccion * tiles
	else:
		# Edificio normal (Base, Casa): usa el valor fijo antiguo
		cantidad_final = generacion_dinero
	
	if cantidad_final <= 0:
		return
	
	# Añadir al gestor de economía
	EconomiaManager.sumar_recurso(recurso_generado, cantidad_final)
	
	# Feedback visual opcional (texto flotante)
	_mostrar_texto_flotante("+" + str(cantidad_final) + " " + _icono_recurso(recurso_generado))

func _icono_recurso(recurso: String) -> String:
	match recurso:
		"dinero": return "🍻"
		"madera": return "🌲"
		"comida": return "🥧"
		"mineral": return "💎"
		"chatarra": return "⚙"
		"ciencia": return "⚗"
		_: return ""

func _mostrar_texto_flotante(texto: String):
	# Opcional: crear un Label temporal que suba y desaparezca
	var label = Label.new()
	label.text = texto
	label.global_position = global_position + Vector2(0, -40)
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color.YELLOW)
	get_parent().add_child(label)
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 40, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.chain().tween_callback(label.queue_free)
