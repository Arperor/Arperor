extends Node

# Definición centralizada de todas las unidades del juego
var unidades: Dictionary = {
	"Constructor": {
		"nombre": "Constructor",
		"escena": preload("res://Escenas/BuenoConstructor.tscn"),
		"coste": {"dinero": 50},
		"descripcion": "Construye y repara edificios automáticamente.",
		"icono": "🔨"
	},
	"Explorador": {
		"nombre": "Explorador",
		"escena": preload("res://Escenas/BuenoExploradoror.tscn"),
		"coste": {"dinero": 75},
		"descripcion": "Unidad rápida de reconocimiento.",
		"icono": "🏃"
	},
	"Soldado": {
		"nombre": "Soldado",
		"escena": preload("res://Escenas/BuenoSoldado.tscn"),
		"coste": {"dinero": 100, "mineral": 10},
		"descripcion": "Unidad de combate básica.",
		"icono": "⚔️"
	},
	"Sniper": {
		"nombre": "Sniper",
		"escena": preload("res://Escenas/BuenoSniper.tscn"),
		"coste": {"dinero": 150, "mineral": 20},
		"descripcion": "Unidad de largo alcance y alto daño.",
		"icono": "🎯"
	}
}

func obtener_definicion(tipo: String) -> Dictionary:
	return unidades.get(tipo, {})

func puede_permitirse(tipo: String) -> bool:
	var def = obtener_definicion(tipo)
	if def.is_empty():
		return false
	return EconomiaManager.tiene_recursos(def["coste"])

func formatear_coste(tipo: String) -> String:
	var def = obtener_definicion(tipo)
	if def.is_empty():
		return "???"
	
	var partes = []
	for recurso in def["coste"]:
		var cantidad = def["coste"][recurso]
		var icono = _icono_recurso(recurso)
		partes.append("%s %d" % [icono, cantidad])
	
	return " | ".join(partes)

func _icono_recurso(recurso: String) -> String:
	match recurso:
		"dinero": return "💰"
		"madera": return "🌲"
		"comida": return "🍖"
		"mineral": return "⛏️"
		"chatarra": return "🔩"
		"ciencia": return "🔬"
		_: return recurso
