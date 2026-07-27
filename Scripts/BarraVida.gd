extends Node2D

@onready var fondo = $Fondo
@onready var relleno = $Relleno

# Guardamos el ancho original para calcular el porcentaje
var ancho_maximo: float = 0.0

func _ready():
	ancho_maximo = relleno.size.x
	# Ocultar la barra al empezar (solo se muestra si hay daño)
	visible = false
	
	# Conectarnos a la señal de nuestro hermano "Stats"
	var stats = get_parent().get_node("Stats")
	if stats:
		stats.stats_cambiados.connect(_on_stats_cambiados)
		# Llamar una vez al inicio por si acaso
		_on_stats_cambiados(stats.vida_actual, stats.vida_maxima)

func _on_stats_cambiados(vida_actual: int, vida_maxima: int):
	# Si la vida está al 100%, ocultamos la barra
	if vida_actual >= vida_maxima:
		visible = false
	else:
		# Si está dañada, la mostramos y ajustamos el tamaño
		visible = true
		var porcentaje = vida_actual / float(vida_maxima)
		relleno.size.x = ancho_maximo * porcentaje
		# Aseguramos que el relleno empiece desde la izquierda
		relleno.position.x = -20 
