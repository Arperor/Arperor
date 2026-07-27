extends Label

# Categoría que este contador va a mostrar (editable desde Inspector)
@export var categoria_a_contar: String = "MaloBase"

var contador: int = 0

func _ready():
	Eventos.enemigo_muerto.connect(_on_enemigo_muerto)
	# NUEVO Bug 8: reiniciar al empezar nueva partida
	if EconomiaManager.has_signal("partida_reseteada"):
		EconomiaManager.partida_reseteada.connect(_on_partida_reseteada)
	_actualizar_texto()

func _on_partida_reseteada():
	contador = 0
	_actualizar_texto()

func _on_enemigo_muerto(categoria: String):
	# Solo sumar si la categoría coincide con la que estamos contando
	if categoria == categoria_a_contar:
		contador += 1
		_actualizar_texto()

func _actualizar_texto():
	text = "💀 " + str(contador)
