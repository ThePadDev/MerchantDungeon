extends "res://Enemies/Enemy.gd"

var moving_faster = false

var speed_multiplier : float = 1.5
var time_moving_faster : float = 1.0


func _ready():
	$MoveSpeedTimer.start()


func _physics_process(delta: float):
	if !dead:
		match state:
			CHASE:
				move_anim.play("goblin_move")
			IDLE:
				move_anim.play("goblin_move_stop")
	else:
		hurtbox.set_deferred("monitorable", false)
		hitbox.set_deferred("monitorable", false)


func _on_Hurtbox_area_entered(area: Area2D):
	if area.is_in_group("Hitbox") and !hit:
		hit = true
		stats.health -= area.damage
		create_hit_effect(global_position)
		create_popup_damage(area.damage, Color.white, Vector2(0.3, 0.3))
		hurtbox.start_invincibility(0.5)
		hit_anim.play("goblin_hit")
		knockback = area.knockback_vector * (area.knockback_amount * stats.knockback_multiplier)


func _on_Stats_no_health():
	dead = true
	death_anim.play("goblin_death")
	yield(death_anim, "animation_finished")
	drops.drop_item()
	queue_free()


func _on_MoveSpeedTimer_timeout():
	if !dead:
		max_speed = max_speed * speed_multiplier
		moving_faster = true
		yield(get_tree().create_timer(time_moving_faster), "timeout")
		max_speed = normal_speed
	else:
		pass
