extends Node2D

@export var radio_separacion: float = 22.0  # Aumentado de 50 a 70
@export var fuerza_separacion: float = 600.0  # Aumentado de 400 a 600
@export var skip_frames: int = 3  # Reducido de 5 a 3 (calcula más seguido)
@export var masa: float = 1.0  # 1.0 es el peso estándar.
@export var capas_a_detectar: int = 1

var velocity_separacion: Vector2 = Vector2.ZERO
var tick_offset: int
var query: PhysicsShapeQueryParameters2D
var circle_shape: CircleShape2D

func _ready():
	tick_offset = randi() % 60
	circle_shape = CircleShape2D.new()
	circle_shape.radius = radio_separacion
	
	query = PhysicsShapeQueryParameters2D.new()
	query.collide_with_bodies = true  # Cambiado a true para detectar edificios y unidades
	query.collide_with_areas = false
	# Máscara: Capa 1 (Unidades) y Capa 2 (Edificios)
	query.collision_mask = capas_a_detectar
	query.shape = circle_shape
	query.transform = Transform2D.IDENTITY

func _physics_process(_delta: float):
	if (Engine.get_physics_frames() + tick_offset) % (skip_frames + 1) == 0:
		velocity_separacion = Vector2.ZERO
		query.transform.origin = get_parent().global_position
		
		# Detectar hasta 12 vecinos cercanos
		var query_result = get_world_2d().direct_space_state.intersect_shape(query, 12)
		
		for item in query_result:
			# Evitar empujarse a sí mismo
			if item.collider == get_parent():
				continue
				
			var otra_unidad = item.collider
			var otra_pos = otra_unidad.global_position
			var vec = get_parent().global_position - otra_pos
			var dist = vec.length()
			
						# --- CORRECCIÓN: Solo aplicar fuerza si están DENTRO del radio ---
			if dist < radio_separacion and dist > 0.1:
				var fuerza = (radio_separacion - dist) / radio_separacion
				
				# Obtener la masa del otro (si no tiene, asumimos 1.0)
				var otra_masa = 1.0
				if otra_unidad.has_node("Separacion"):
					otra_masa = otra_unidad.get_node("Separacion").masa
				
				# Factor de masa: si el otro pesa más, me empuja más. Si yo peso más, me muevo menos.
				var factor_masa = otra_masa / masa
				
				# Multiplicador por movimiento (el que se mueve empuja más)
				var multiplicador = 1.0
				if otra_unidad is CharacterBody2D and otra_unidad.velocity.length() > 5.0:
					multiplicador = 4.0
				
				velocity_separacion += vec.normalized() * fuerza * fuerza_separacion * multiplicador * factor_masa

func get_velocity_separacion() -> Vector2:
	return velocity_separacion
