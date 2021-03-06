extends KinematicBody2D

const POPUP_DAMAGE = preload("res://UI/PopupDamage.tscn")

var acceleration = 250
var friction = 300

var max_speed setget set_max_speed
var normal_speed = 75 setget set_normal_speed
var sprint_speed = 125 setget set_sprint_speed

var velocity = Vector2.ZERO
var input_vector

var moving = false
var sprinting = false

var can_sprint = true
var can_attack = true

var hit = false
var dead = false

var weapon_equipped = false

var weapon
var weapon_distance
var weapon_hitbox

onready var weapon_position = $WeaponPosition

onready var potion_sound = $PotionSound
onready var pickup_sound = $PickupSound

onready var anim_player = $AnimationPlayer
onready var hit_anim = $HitAnimation
onready var death_anim = $DeathAnimation

onready var player_camera = $Camera2D

onready var sprint_particles = $SprintParticles
onready var player_light = $Light2D
onready var hurtbox = $Hurtbox

onready var stats = $Stats
onready var items = $Items


func set_max_speed(value):
	max_speed = value


func set_normal_speed(value):
	normal_speed = value


func set_sprint_speed(value):
	sprint_speed = value


func _ready():
	stats.connect("no_health", self, "_on_no_health")
	stats.connect("no_stamina", self, "_on_no_stamina")
	player_light.texture_scale = stats.area_of_sight
	set_max_speed(normal_speed)
	add_to_group("Player")
	equip_fists()


func _physics_process(delta: float):
	if !dead and Global.game_started:
		_input_vector(delta)
		_move_player()
		if weapon_equipped:
			_move_weapon()


func _input_vector(delta):
	input_vector = Vector2.ZERO
	input_vector.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
	input_vector.y = Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	input_vector = input_vector.normalized()
	
	if input_vector != Vector2.ZERO:
		anim_player.play("move")
		moving = true
		velocity = velocity.move_toward(input_vector * max_speed, acceleration * delta)
	else:
		anim_player.play("move_stop")
		moving = false
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)


func _input(_event):
	if weapon_equipped:
		if Input.is_action_just_pressed("attack") and can_attack and weapon.can_attack:
			can_attack = false
			weapon.attack()
		if Input.is_action_just_pressed("drop_weapon"):
			drop_weapon()
	if Input.is_action_just_pressed("use_health_potion") and items.health_potions > 0:
		use_health_potion()


func _move_player():
	velocity = move_and_slide(velocity)
	
	if Input.is_action_pressed("sprint") and can_sprint:
		set_max_speed(sprint_speed)
		if moving:
			sprinting = true
			anim_player.playback_speed = 1.5
			sprint_particles_enabled(true)
			stats.set_regenerating(false)
			stats.stamina -= 0.1
	else:
		sprinting = false
		sprint_particles_enabled(false)
		anim_player.playback_speed = 1
		set_max_speed(normal_speed)
		stats.set_regenerating(true)


func _move_weapon():
	if weapon != null:
		weapon_position.look_at(get_global_mouse_position())


func equip_fists():
	var fists = preload("res://Weapons/Fists.tscn").instance()
	equip_weapon(fists)


func equip_weapon(new_weapon):
	if weapon_position.get_children():
		for _weapon in weapon_position.get_children():
			_weapon.queue_free()
	
	weapon_position.add_child(new_weapon)  
	weapon = new_weapon
	weapon.position.x += weapon.weapon_distance
	if new_weapon.is_in_group("MeleeWeapon"):
		weapon_hitbox = weapon.get_node("Body/Hitbox")
	weapon_equipped = true
	if !can_attack:
		can_attack = true


func drop_weapon():
	if !weapon.is_in_group("Fists"):
		var format_path = "res://Weapons/WeaponDrops/%sDrop.tscn"
		var actual_path = format_path % weapon.name
		var weapon_drop = load(actual_path).instance()
		weapon_drop.global_position = global_position
		get_tree().current_scene.get_node("YSort/Items").add_child(weapon_drop)
		weapon_position.get_child(0).queue_free()
		equip_fists()


func use_health_potion():
	if stats.health < stats.max_health:
		heal_player()
		play_potion_sound()
		items.health_potions -= 1
		get_tree().call_group("HUD", "set_health_potions", items.health_potions)


func play_potion_sound():
	randomize()
	potion_sound.pitch_scale = rand_range(0.9, 1.1)
	potion_sound.play()


func heal_player():
	stats.health = stats.max_health


func set_sprint_particles_direction():
	sprint_particles.direction = -input_vector
	sprint_particles.gravity = -input_vector * 98


func sprint_particles_enabled(value):
	set_sprint_particles_direction()
	sprint_particles.emitting = value


func create_popup_damage(dmg, color, size):
	var instance = POPUP_DAMAGE.instance()
	get_tree().current_scene.add_child(instance)
	instance.modulate = color
	instance.scale = size
	instance.position = get_global_transform().origin
	instance.popup_damage(dmg)


func _on_no_health():
	dead = true
	death_anim.play("player_death")
	yield(death_anim, "animation_finished")
	get_tree().call_group("HUD", "show_death_label")
	queue_free()


func _on_no_stamina():
	can_sprint = false


func _on_weapon_attack_done():
	can_attack = true


func _on_Hurtbox_area_entered(area: Area2D):
	if area.is_in_group("Hitbox") and !hit:
		hit = true
		stats.health -= area.damage
		create_popup_damage(area.damage, Color.white, Vector2(0.4, 0.4))
		hit_anim.play("player_hit")
		hurtbox.start_invincibility(0.75)
		hit = false
	if area.is_in_group("BossProjectile") and !hit:
		hit = true
		if weapon_equipped:
			drop_weapon()
		hit = false

