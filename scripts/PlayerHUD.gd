extends CanvasLayer
class_name PlayerHUD

@onready var health_bar: ProgressBar = $MarginLeft/VBoxContainer/HealthBar
@onready var mana_bar: ProgressBar = $MarginLeft/VBoxContainer/ManaBar
@onready var spell_label: Label = $MarginRight/VBoxContainer/SpellLabel
@onready var cooldown_ui: Control = $CooldownUI

var current_cooldown: float = 0.0
var current_max_cooldown: float = 1.0

func _ready():
	cooldown_ui.draw.connect(_on_cooldown_draw)

func _process(delta):
	var v_size = get_viewport().get_visible_rect().size
	$MarginLeft.position = Vector2(40, v_size.y - $MarginLeft.size.y - 40)
	$MarginRight.position = Vector2(v_size.x - $MarginRight.size.x - 40, v_size.y - $MarginRight.size.y - 40)
	cooldown_ui.position = v_size / 2.0

func update_health(health: float, max_health: float):
	health_bar.max_value = max_health
	health_bar.value = health

func update_mana(mana: float, max_mana: float):
	mana_bar.max_value = max_mana
	mana_bar.value = mana

func update_spell(spell_name: String, cost: float):
	spell_label.text = spell_name.capitalize() + " (" + str(cost) + " MP)"

func set_cooldown(cooldown: float, max_cooldown: float):
	current_cooldown = cooldown
	current_max_cooldown = max_cooldown
	cooldown_ui.queue_redraw()

func _on_cooldown_draw():
	if current_cooldown > 0:
		var center = Vector2.ZERO
		var radius = 25.0
		var angle_from = -PI / 2.0
		var progress = 1.0 - (current_cooldown / current_max_cooldown)
		var angle_to = angle_from + (PI * 2.0 * progress)
		
		cooldown_ui.draw_arc(center, radius, 0, PI * 2.0, 64, Color(1, 1, 1, 0.1), 4.0, true)
		cooldown_ui.draw_arc(center, radius, angle_from, angle_to, 64, Color(1, 1, 1, 0.4), 4.0, true)
