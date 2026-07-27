# GeneradorRecursos.gd
class_name GeneradorRecursos
extends Node

# ENUM DE TERRENOS
enum TipoTerreno { NORMAL, BOSQUE, MINERAL, AGUA, CHATARRA, MONTAÑA }

# CONFIGURACIÓN VISUAL DE TILES
@export_group("Tile NORMAL")
@export var normal_source_id: int = 0
@export var normal_atlas: Vector2i = Vector2i(0, 0)

@export_group("Tile BOSQUE")
@export var bosque_source_id: int = 1
@export var bosque_atlas: Vector2i = Vector2i(0, 0)

@export_group("Tile MINERAL")
@export var mineral_source_id: int = 2
@export var mineral_atlas: Vector2i = Vector2i(0, 0)

@export_group("Tile AGUA")
@export var agua_source_id: int = 3
@export var agua_atlas: Vector2i = Vector2i(0, 0)

@export_group("Tile CHATARRA")
@export var chatarra_source_id: int = 4
@export var chatarra_atlas: Vector2i = Vector2i(0, 0)

@export_group("Tile MONTAÑA")
@export var montaña_source_id: int = 5
@export var montaña_atlas: Vector2i = Vector2i(0, 0)

# GENERACIÓN
@export_group("Generación")
@export var tamano_mapa_x: int = 18000
@export var tamano_mapa_y: int = 18000
@export var tamano_tile: float = 64.0
@export var semilla: int = 12345

# GAMEPLAY
@export_group("Gameplay")
@export var velocidad_bosque: float = 0.3
@export var velocidad_montaña: float = 0.2
@export var radio_extraccion: float = 192.0

@export_group("Frecuencias (menor = más grande)")
@export var freq_bosque: float = 0.04
@export var freq_montaña: float = 0.05
@export var freq_agua: float = 0.03
@export var freq_mineral: float = 0.012
@export var freq_chatarra: float = 0.015

@export_group("Umbrales (mayor = menos frecuente)")
@export var umbral_agua: float = 0.85
@export var umbral_montaña: float = 0.85
@export var umbral_bosque: float = 0.85
@export var umbral_mineral: float = 0.70
@export var umbral_chatarra: float = 0.70

@export_group("Octavas (detalle de bordes)")
@export var octavas_agrupados: int = 3  # Bosque, agua, montaña
@export var octavas_dispersos: int = 2  # Mineral, chatarra

# ESTADO INTERNO
var mapa_terrenos: Dictionary = {}
@onready var tilemap_layer: TileMapLayer = null

func _ready() -> void:
	randomize()
	if semilla == 0:
		semilla = randi()
	
	var suelo = get_parent().get_node_or_null("Suelo")
	if suelo:
		for child in suelo.get_children():
			if child is TileMapLayer:
				tilemap_layer = child
				break
	
	if not tilemap_layer:
		push_error("GeneradorRecursos: No se encontró TileMapLayer dentro de 'Suelo'.")
		return
	
	_generar_recursos()

func _generar_recursos() -> void:
	print("🌍 Generando recursos procedurales...")
	
	var rb = _nuevo_ruido(semilla,       freq_bosque,    octavas_agrupados)
	var rm = _nuevo_ruido(semilla + 1,   freq_montaña,   octavas_agrupados)
	var ra = _nuevo_ruido(semilla + 2,   freq_agua,      octavas_agrupados)
	var rmi = _nuevo_ruido(semilla + 3,  freq_mineral,   octavas_dispersos)
	var rc = _nuevo_ruido(semilla + 4,   freq_chatarra,  octavas_dispersos)
	var celdas_x := int(tamano_mapa_x / tamano_tile)
	var celdas_y := int(tamano_mapa_y / tamano_tile)
	var ox := int(celdas_x / 2.0)
	var oy := int(celdas_y / 2.0)
	var contador := {
		TipoTerreno.BOSQUE: 0, TipoTerreno.MINERAL: 0,
		TipoTerreno.AGUA: 0,   TipoTerreno.CHATARRA: 0,
		TipoTerreno.MONTAÑA: 0
	}
	
	for x in range(celdas_x):
		for y in range(celdas_y):
			var cx := x - ox
			var cy := y - oy
			var wx := float(cx) * tamano_tile
			var wy := float(cy) * tamano_tile
			
			var tipo := TipoTerreno.NORMAL
			
			if ra.get_noise_2d(wx, wy) > umbral_agua:
				tipo = TipoTerreno.AGUA
			elif rm.get_noise_2d(wx, wy) > umbral_montaña:
				tipo = TipoTerreno.MONTAÑA
			elif rb.get_noise_2d(wx, wy) > umbral_bosque:
				tipo = TipoTerreno.BOSQUE
			elif rmi.get_noise_2d(wx, wy) > umbral_mineral:
				tipo = TipoTerreno.MINERAL
			elif rc.get_noise_2d(wx, wy) > umbral_chatarra:
				tipo = TipoTerreno.CHATARRA
			
			mapa_terrenos[Vector2i(cx, cy)] = tipo
			_colocar_tile(cx, cy, tipo)
			if tipo != TipoTerreno.NORMAL:
				contador[tipo] += 1
	
	print("✅ Generados → 🌲", contador[TipoTerreno.BOSQUE],
		  "  ⛏", contador[TipoTerreno.MINERAL],
		  "  💧", contador[TipoTerreno.AGUA],
		  "  🔩", contador[TipoTerreno.CHATARRA],
		  "  🏔️", contador[TipoTerreno.MONTAÑA])

func _nuevo_ruido(s: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = s
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.frequency = freq
	n.fractal_octaves = octaves
	return n

func _colocar_tile(x: int, y: int, tipo: int) -> void:
	if not tilemap_layer:
		return
	
	var src: int
	var atl: Vector2i
	
	match tipo:
		TipoTerreno.NORMAL:
			src = normal_source_id
			atl = normal_atlas
		TipoTerreno.BOSQUE:
			src = bosque_source_id
			atl = bosque_atlas
		TipoTerreno.MINERAL:
			src = mineral_source_id
			atl = mineral_atlas
		TipoTerreno.AGUA:
			src = agua_source_id
			atl = agua_atlas
		TipoTerreno.CHATARRA:
			src = chatarra_source_id
			atl = chatarra_atlas
		TipoTerreno.MONTAÑA:
			src = montaña_source_id
			atl = montaña_atlas
		_:
			src = normal_source_id
			atl = normal_atlas
	
	tilemap_layer.set_cell(Vector2i(x, y), src, atl)

# CONSULTAS PÚBLICAS
func obtener_terreno_en(pos: Vector2) -> int:
	var celda := _pos_a_celda(pos)
	return mapa_terrenos.get(celda, TipoTerreno.NORMAL)

func puede_moverse_a(pos: Vector2) -> bool:
	var terreno = obtener_terreno_en(pos)
	return terreno != TipoTerreno.AGUA and terreno != TipoTerreno.MONTAÑA

func modificador_velocidad_en(pos: Vector2) -> float:
	match obtener_terreno_en(pos):
		TipoTerreno.AGUA:
			return -30.0
		TipoTerreno.MONTAÑA:
			return -30.0
		TipoTerreno.BOSQUE:
			return velocidad_bosque
		_:
			return 1.0

func hay_recurso_cerca(pos: Vector2, tipo_recurso: int, radio: float = 128.0) -> bool:
	var celdas_radio := int(radio / tamano_tile) + 1
	var centro := _pos_a_celda(pos)
	for dx in range(-celdas_radio, celdas_radio + 1):
		for dy in range(-celdas_radio, celdas_radio + 1):
			if mapa_terrenos.get(centro + Vector2i(dx, dy), -1) == tipo_recurso:
				return true
	return false

func _pos_a_celda(pos: Vector2) -> Vector2i:
	return Vector2i(floori(pos.x / tamano_tile), floori(pos.y / tamano_tile))
