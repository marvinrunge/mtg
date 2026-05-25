extends Node3D

@export var max_health: float = 1000.0
var health: float

# Animation parameters
@export var float_speed: float = 1.0
@export var float_amplitude: float = 0.2
@export var rotation_speed: float = 0.2

var initial_y: float
var time_passed: float = 0.0

func _ready():
	health = max_health
	initial_y = position.y

func _process(delta: float):
	time_passed += delta
	position.y = initial_y + sin(time_passed * float_speed) * float_amplitude
	rotate_y(rotation_speed * delta)

func take_damage(amount: float):
	if not multiplayer.is_server(): return
	health -= amount
	print("Base Cristal health: ", health)
	if health <= 0:
		print("Base Cristal destroyed! Game Over!")
		# Here you would typically trigger game over logic
