extends Node

signal recursos_cambiados(dinero: int, poblacion_actual: int, poblacion_maxima: int)
signal tecnologia_desbloqueada(nivel: int)
signal partida_reseteada()
signal base_construida_signal()

# Recursos
var recursos: Dictionary = {
	"dinero": 1,
	"madera": 0,
	"comida": 0,
	"chatarra": 0,
	"mineral": 0
}
# CAPACIDADES MÁXIMAS DE ALMACENAMIENTO
var capacidades_max: Dictionary = {
	"dinero": 1000,
	"madera": 50,
	"comida": 200,
	"chatarra": 50,
	"mineral": 50
}
var base_construida: bool = false
var poblacion_actual: int = 0
var poblacion_maxima: int = 10
var nivel_tecnologia: int = 1

func _ready():
	recursos_cambiados.emit(recursos["dinero"], poblacion_actual, poblacion_maxima)

# --- RECURSOS GENÉRICOS ---
func sumar_recurso(nombre: String, cantidad: int):
	if not recursos.has(nombre):
		recursos[nombre] = 0
	# NUEVO: Respetar capacidad máxima
	var maximo = capacidades_max.get(nombre, 999999)
	recursos[nombre] = mini(recursos[nombre] + cantidad, maximo)
	recursos_cambiados.emit(recursos["dinero"], poblacion_actual, poblacion_maxima)

func aumentar_capacidad_maxima(recurso: String, cantidad: int):
	if capacidades_max.has(recurso):
		capacidades_max[recurso] += cantidad
		recursos_cambiados.emit(recursos["dinero"], poblacion_actual, poblacion_maxima)

func gastar_recurso(nombre: String, cantidad: int) -> bool:
	if recursos.has(nombre) and recursos[nombre] >= cantidad:
		recursos[nombre] -= cantidad
		recursos_cambiados.emit(recursos["dinero"], poblacion_actual, poblacion_maxima)
		return true
	return false

func tiene_recursos(coste: Dictionary) -> bool:
	for recurso in coste:
		if recurso == "poblacion":
			# Caso especial: población usa el sistema de población
			if not hay_poblacion_disponible(coste[recurso]):
				return false
		else:
			if not recursos.has(recurso) or recursos[recurso] < coste[recurso]:
				return false
	return true

func gastar_recursos(coste: Dictionary) -> bool:
	if not tiene_recursos(coste):
		return false
	for recurso in coste:
		if recurso == "poblacion":
			# Caso especial: población usa el sistema de población
			cambiar_poblacion(coste[recurso])
		else:
			recursos[recurso] -= coste[recurso]
	recursos_cambiados.emit(recursos["dinero"], poblacion_actual, poblacion_maxima)
	return true

# --- COMPATIBILIDAD CON DINERO ---
func sumar_dinero(cantidad: int):
	sumar_recurso("dinero", cantidad)

func gastar_dinero(cantidad: int) -> bool:
	return gastar_recurso("dinero", cantidad)

# --- POBLACIÓN ---
func cambiar_poblacion(cantidad: int):
	poblacion_actual += cantidad
	recursos_cambiados.emit(recursos["dinero"], poblacion_actual, poblacion_maxima)

func aumentar_poblacion_maxima(cantidad: int):
	poblacion_maxima += cantidad
	recursos_cambiados.emit(recursos["dinero"], poblacion_actual, poblacion_maxima)

func hay_poblacion_disponible(cantidad_requerida: int = 1) -> bool:
	return (poblacion_actual + cantidad_requerida) <= poblacion_maxima

func desbloquear_siguiente_nivel():
	nivel_tecnologia += 1
	tecnologia_desbloqueada.emit(nivel_tecnologia)

func marcar_base_construida():
	base_construida = true
	base_construida_signal.emit()  # NUEVO: Notificar al FlowfieldManager

func resetear():
	recursos = {
		"dinero": 100,
		"madera": 0,
		"comida": 0,
		"chatarra": 0,
		"mineral": 0
	}
	base_construida = false
	poblacion_actual = 0
	poblacion_maxima = 10
	nivel_tecnologia = 1
	capacidades_max = {
		"dinero": 1000,
		"madera": 50,
		"comida": 200,
		"chatarra": 50,
		"mineral": 50
	}
	recursos_cambiados.emit(recursos["dinero"], poblacion_actual, poblacion_maxima)
	# NUEVO Bug 8: notificar a contadores persistentes
	partida_reseteada.emit()
