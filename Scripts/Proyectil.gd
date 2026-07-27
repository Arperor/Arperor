extends Area2D

@export var velocidad: float = 400.0
@export var dany: int = 1
@export var categoria_origen: String = ""

var objetivo = null
var direccion = Vector2.ZERO

func _physics_process(delta):
	# Si el objetivo murió o se eliminó, autodestruir el proyectil
	if not is_instance_valid(objetivo) or (objetivo.has_node("Stats") and objetivo.get_node("Stats").vida_actual <= 0):
		queue_free()
		return
	
	# Mover hacia el objetivo
	direccion = (objetivo.global_position - global_position).normalized()
	position += direccion * velocidad * delta
	
	# Rotar el sprite para que mire hacia donde va
	rotation = direccion.angle()
	
	# --- DETECCIÓN DE IMPACTO POR DISTANCIA ---
	var distancia_al_objetivo = global_position.distance_to(objetivo.global_position)
	
	# Si está muy cerca (menos de 20 píxeles), consideramos que impactó
	if distancia_al_objetivo < 20:
		# Aplicar daño
		if objetivo.has_node("Stats"):
			objetivo.get_node("Stats").rebre_dany(dany)
		
		# Destruir el proyectil
		queue_free()
