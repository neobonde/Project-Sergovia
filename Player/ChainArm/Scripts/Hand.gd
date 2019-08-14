extends RigidBody2D

const DISTANCE = 46
const MIN_DISTANCE = DISTANCE -30
const FORCE = 1500
const RETRACTION_SPEED = 6

var pivot 
var player
var spawned_hand
var aim_vector = Vector2()
var grab_position
signal grabbed
signal ungrabbed
signal shake

# Called when the node enters the scene tree for the first time.
func _ready():	
	pivot = get_parent().get_node("Anchor")
	player = get_parent().get_parent()
	set_deferred("mode",MODE_KINEMATIC)
	
	pass # Replace with function body.

var detached = false
var fired = false
var extended_length = 0
var retracting = false
var retraction = 0
var retraction_start = Vector2()
signal retracted  
signal extended

func fire(ext_len):
	extended_length = ext_len
	detached = true
	set_deferred("mode",MODE_RIGID)

func refire():
	fired = false
	detached = true
	retracting = false
	set_deferred("mode",MODE_RIGID)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta):
	updateMovement(delta)
	
func updateMovement(delta):
	if grab_position != null:
		global_position = grab_position
		if Input.is_action_just_released("player_fire"):
			grab_position = null
			retracting = true
			retraction_start = global_position
			emit_signal("ungrabbed")
#			apply_impulse(Vector2(),-return_vector*FORCE*mass)
	else:
		aim_vector = (get_global_mouse_position() - pivot.global_position).normalized()
		if not detached:
			if pivot.global_position.distance_to(get_global_mouse_position()) > MIN_DISTANCE:
				position = aim_vector * DISTANCE + pivot.position
				$Sprite.look_at(get_global_mouse_position())
		elif not fired and detached:
				apply_impulse(Vector2(),aim_vector*FORCE*mass)
				fired = true
		elif detached:
			if (pivot.global_position + player.velocity.normalized()*30).distance_to(global_position) >= extended_length:
				# retract
				retracting = true
				mode = MODE_KINEMATIC
				emit_signal("extended")
				retraction_start = global_position
				emit_signal("shake",0.07,40,2)
			if retracting:
				var goal = aim_vector * DISTANCE + pivot.global_position
				var temp = retraction_start.linear_interpolate(goal, retraction)
				global_position = temp
				retraction += delta * RETRACTION_SPEED
				if retraction >= 0.9:
					retraction = 0
					retracting = false
					detached = false
					fired = false
					emit_signal("retracted")


func _on_Grabber_area_entered(area):
	if grab_position == null and area.is_in_group("grabbable"):
		if detached and Input.is_action_pressed("player_fire"):
			print("Grabbing: " + area.name)
			set_deferred("mode",MODE_KINEMATIC)
			grab_position = area.get_node("Pivot").global_position
			emit_signal("grabbed",grab_position,extended_length)


func _on_Grabber_body_entered(body):
	if fired and not retracting and body.is_in_group("Punchable"): 
		print("Punching: " + body.name)
		if body.has_method("damage"):
			var hp = body.damage(1)
			if hp > 0:
				emit_signal("shake",0.1,40,8)
		retracting = true
		mode = MODE_KINEMATIC
		emit_signal("extended")
		retraction_start = global_position
