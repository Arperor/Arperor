extends Area2D

var buenos_dentro = []
var timer_emision: float = 0.0
@export var intervalo_emision: float = 1.0
@export var prioridad_base: float = 1.0

var radio_area: float = 100.0

func _ready():
	body_entered.connect(_on_malo_entro)
	body_exited.connect(_on_malo_salio)
	
	# Cacheamos el radio una sola vez al inicio
	var collision = get_node_or_null("CollisionShape2D")
	if collision and collision.shape is CircleShape2D:
		radio_area = collision.shape.radius

func _process(delta):
	timer_emision += delta
	if timer_emision >= intervalo_emision:
		_emitir_senal_atraccion()
		timer_emision = 0.0

func _on_malo_entro(body):
	if body.is_in_group("malos"):
		if body not in buenos_dentro:
			buenos_dentro.append(body)
		if body.has_node("IA"):
			_enviar_senal_a_malo(body)

func _on_malo_salio(body):
	if body.is_in_group("malos"):
		buenos_dentro.erase(body)
		if body.has_node("IA"):
			body.get_node("IA").perder_atraccion(get_parent())

func _emitir_senal_atraccion():
	for malo in buenos_dentro:
		if is_instance_valid(malo) and malo.has_node("IA"):
			_enviar_senal_a_malo(malo)

# NUEVO: Cálculo de intensidad SOLO aquí
func _enviar_senal_a_malo(malo):
	var dist = malo.global_position.distance_to(get_parent().global_position)
	var intensidad = max(0.0, 1.0 - (dist / radio_area)) * prioridad_base
	malo.get_node("IA").recibir_atraccion(get_parent(), intensidad)
