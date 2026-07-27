extends Label

var texto_base: String = "🍻 "

func _ready():
	# Conectarse al gestor de economía global
	EconomiaManager.recursos_cambiados.connect(_on_recursos_cambiados)
	_actualizar_texto()

func _on_recursos_cambiados(_dinero: int, _poblacion_actual: int, _poblacion_maxima: int):
	_actualizar_texto()

func _actualizar_texto():
	text = texto_base + str(EconomiaManager.recursos["dinero"]) + "/" + str(EconomiaManager.capacidades_max["dinero"])
