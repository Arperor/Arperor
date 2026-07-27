extends Node2D

@onready var stats = get_parent().get_node("Stats")
var objetivo = null
var timer_ataque = 0.0

func _physics_process(delta):
	if get_parent().get("en_construccion") == true:
		return

	if not is_instance_valid(stats) or stats.vida_actual <= 0:
		return
	
	if not is_instance_valid(objetivo) or objetivo.get_node("Stats").vida_actual <= 0:
		objetivo = _buscar_enemigo_cercano()
	
	if objetivo:
		var dist = get_parent().global_position.distance_to(objetivo.global_position)
		var rango = stats.get_rango_ataque_px()
		
		if dist <= rango:
			timer_ataque += delta
			if timer_ataque >= stats.cooldown_ataque:
				if stats.escena_proyectil:
					lanzar_proyectil()
				else:
					objetivo.get_node("Stats").rebre_dany(stats.dany)
				timer_ataque = 0
		else:
			timer_ataque = 0
	else:
		timer_ataque = 0

func _buscar_enemigo_cercano():
	var enemigos = get_tree().get_nodes_in_group("malos")
	var mas_cercano = null
	# Solo buscar enemigos dentro de su propio rango de ataque
	var rango_busqueda = stats.get_rango_ataque_px() 
	var dist_minima = rango_busqueda
	
	for enemigo in enemigos:
		if is_instance_valid(enemigo) and enemigo.has_node("Stats"):
			if enemigo.get_node("Stats").vida_actual > 0:
				var dist = get_parent().global_position.distance_to(enemigo.global_position)
				if dist < dist_minima:
					dist_minima = dist
					mas_cercano = enemigo
	
	return mas_cercano

func lanzar_proyectil():
	var proyectil = stats.escena_proyectil.instantiate()
	get_parent().get_parent().add_child(proyectil)  # Añadirlo al mismo nivel que el padre (Mapa)
	proyectil.global_position = get_parent().global_position
	proyectil.objetivo = objetivo
	proyectil.dany = stats.dany
	proyectil.categoria_origen = stats.categoria
