extends Area2D
class_name AreaExtraccion

@export var tipo_recurso_buscado: GeneradorRecursos.TipoTerreno = GeneradorRecursos.TipoTerreno.BOSQUE
@export var radio_busqueda_px: float = 192.0  # 3 tiles por defecto

var tiles_detectados: int = 0
var generador = null

@onready var sprite_visual = $SpriteVisual  # Un Sprite2D hijo para mostrar el área

func _ready():
	generador = get_node_or_null("/root/Mapa/GeneradorRecursos")
	
	# Crear el sprite semitransparente si no existe
	if not has_node("SpriteVisual"):
		var sv = Sprite2D.new()
		sv.name = "SpriteVisual"
		sv.modulate = Color(0.3, 0.8, 0.3, 0.25)  # Verde semitransparente
		add_child(sv)
		sprite_visual = sv
	
	# Configurar tamaño visual
	if sprite_visual:
		sprite_visual.scale = Vector2(radio_busqueda_px * 2 / 64.0, radio_busqueda_px * 2 / 64.0)
	
	# Escanear una vez al activarse
	esperar_generador_y_contar()

func esperar_generador_y_contar():
	if not generador or not generador.mapa_terrenos.size() > 0:
		# Reintentar en el siguiente frame
		call_deferred("esperar_generador_y_contar")
		return
	contar_recursos()

func contar_recursos():
	if not generador:
		return
	
	tiles_detectados = 0
	var pos_centro = global_position
	var radio_celdas = int(radio_busqueda_px / generador.tamano_tile) + 1
	var celda_centro = generador._pos_a_celda(pos_centro)
	
	for dx in range(-radio_celdas, radio_celdas + 1):
		for dy in range(-radio_celdas, radio_celdas + 1):
			var celda = celda_centro + Vector2i(dx, dy)
			# Solo contar dentro del radio circular
			var distancia_px = Vector2(dx, dy).length() * generador.tamano_tile
			if distancia_px <= radio_busqueda_px:
				var tipo = generador.mapa_terrenos.get(celda, -1)
				if tipo == tipo_recurso_buscado:
					tiles_detectados += 1
	
	print("🔍 ", get_parent().name, " detectó ", tiles_detectados, " tiles del tipo ", tipo_recurso_buscado)

func get_produccion_multiplicador() -> int:
	return max(0, tiles_detectados)
