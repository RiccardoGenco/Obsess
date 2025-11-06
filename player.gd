extends CharacterBody2D

# ----------------------------
# === NODI RIFERIMENTO ===
# ----------------------------
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D



# ----------------------------
# === COSTANTI MOVIMENTO ===
# ----------------------------
const WALK_SPEED = 100
const RUN_SPEED = 200
const SNEAK_SPEED = 40
const DASH_SPEED = 450
const DASH_TIME = 0.6




# ----------------------------
# === VARIABILI DI STATO ===
# ----------------------------
@export_category("Movement variable")
@export_category("Jump variable")
@export var jump_speed = 240.0
@export var acceleration = 290.0
@export var deceleration = 0.1
@export var MAX_JUMPS = 2
@export var GRAVITY = 500.0
@export var original_gravity = GRAVITY
@onready var left_rayt: RayCast2D = $raycast_top/left_rayt
@onready var right_rayt: RayCast2D = $raycast_top/right_rayt
@onready var left_rayb: RayCast2D = $raycast_bot/left_rayb
@onready var right_rayb: RayCast2D = $raycast_bot/right_rayb



var is_wall_jumping := false
var wall_jump_lock_time = 0.2
var wall_jump_timer = 0.0
var is_wall_sliding := false

var is_attacking := false
var is_dashing := false
var hp := 100
var max_hp := 100
var invincible := false
var facing_dir = 1  # 1 = destra, -1 = sinistra


# ----------------------------
# === READY ===
# ----------------------------
func _ready():
	appear()



# ----------------------------
# === LOOP FISICA ===
# ----------------------------
func _physics_process(delta):
	if hp <= 0:
		return
		
	if wall_jump_timer > 0:
		wall_jump_timer -= delta
	update_flip()
	wall_jump_logic()
	jump_logic()
	velocity.y += GRAVITY * delta
	if wall_jump_timer <= 0:
		wall_slide_logic()
	if wall_jump_timer <= 0:
		handle_input(delta)
	move_and_slide()
	
	# Resetta i salti solo se sei a terra
	if is_on_floor():
		MAX_JUMPS = 2
	if is_on_wall():
		MAX_JUMPS = 1
	# Aggiorna animazioni
	update_animation()

# ----------------------------
# === INPUT ===
# ----------------------------
func update_flip():
	if velocity.x > 0: 
		scale.x = scale.y * 1 
		facing_dir = 1 
	if velocity.x < 0: 
		scale.x = scale.y * -1 
		facing_dir = -1

func handle_input(delta):
	var input_dir = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")

	# Movimento orizzontale
	if  not is_dashing:
		if Input.is_action_pressed("sneak"):
			velocity.x = input_dir * SNEAK_SPEED
		elif Input.is_action_pressed("run"):
			velocity.x = input_dir * RUN_SPEED
		else:
			velocity.x = input_dir * WALK_SPEED


		# Attacchi e dash
		if Input.is_action_just_pressed("attack"):
			attack()
		elif Input.is_action_just_pressed("attack_power"):
			attack_power()
		elif Input.is_action_just_pressed("dash"):
			dash()


# ----------------------------
# === FISICA VERTICALE ===
# ----------------------------
func jump_logic():
	if not is_wall_sliding:
		if Input.is_action_just_pressed("jump") and MAX_JUMPS > 0:
			MAX_JUMPS -= 1
			velocity.y = -jump_speed

	if Input.is_action_just_released("jump") and velocity.y != 0:
		velocity.y *= 0.3
		
func wall_jump_logic():
	if is_on_floor():
		return

	var left_wall = left_rayt.is_colliding() or left_rayb.is_colliding()
	var right_wall = right_rayt.is_colliding() or right_rayb.is_colliding()
	var on_wall = left_wall or right_wall

	
	if on_wall and Input.is_action_just_pressed("jump"):
		velocity.x = (140 * -facing_dir)
		velocity.y = -200

		is_wall_jumping = false
		wall_jump_timer = wall_jump_lock_time


func wall_slide_logic():
	
	if wall_jump_timer > 0:
		return  
	is_wall_sliding = false

	if is_on_floor() or velocity.y <= 0:
		return

	var left_wall = left_rayt.is_colliding() or left_rayb.is_colliding()
	var right_wall = right_rayt.is_colliding() or right_rayb.is_colliding()

	if left_wall or right_wall:
		is_wall_sliding = true
		velocity.y = min(velocity.y, 10)  # rallenta la caduta

		# Solo se non c'è input opposto
		if left_wall and Input.get_action_strength("ui_left") == 0:
			velocity.x = min(velocity.x, 5)
		elif right_wall and Input.get_action_strength("ui_right") == 0:
			velocity.x = max(velocity.x, -5)

		


		


# ----------------------------
# === ANIMAZIONI ===
# ----------------------------
func update_animation():
	if hp <= 0:
		anim.play("dissolve")
		return
		
	if is_on_wall_only():
		anim.play("wall_slide")
		return
		
	if is_dashing:
		anim.play("dash")  
		return

	if is_attacking:
		return # animazioni gestite nelle funzioni stesse
		
	if velocity.y != 0 and not is_dashing and not is_attacking:
		anim.play("jump")
		return

	if abs(velocity.x) < 5:
		anim.play("idle")
	else:
		if abs(velocity.x) <= SNEAK_SPEED:
			anim.play("sneak")
		elif abs(velocity.x) >= RUN_SPEED - 1:
			anim.play("run")
		else:
			anim.play("walk")

func dash():
	if is_dashing:
		return  # Non puoi dashare se già in dash

	is_dashing = true
	GRAVITY *= 0.2  # 20% della gravità normale
	# Salva la direzione corrente, usa 1 se fermo
	var dir = sign(velocity.x)
	if dir == 0:
		dir = scale.x / abs(scale.x)  # direzione dello sprite

	# Applica la velocità del dash
	velocity.x = DASH_SPEED * facing_dir
	

	# Aspetta la durata della dash
	await get_tree().create_timer(DASH_TIME).timeout

	# Fine dash, ripristina movimento
	is_dashing = false# oppure lascia che handle_input gestisca di nuovo
	GRAVITY = original_gravity

	# --- Gestione salto / caduta ---

# ----------------------------
# === ATTACCHI ===
# ----------------------------
func attack():
	if is_attacking: return
	is_attacking = true
	anim.play("attack")
	await anim.animation_finished
	is_attacking = false
	


func attack_power():
	if is_attacking: return
	is_attacking = true
	anim.play("attack_power")
	await anim.animation_finished
	is_attacking = false



# ----------------------------
# === HP E DANNI ===
# ----------------------------
func take_damage(amount: int):
	if invincible or hp <= 0:
		return
	hp -= amount
	anim.play("glow")
	invincible = true
	blink_invincibility()
	if hp <= 0:
		dissolve()

# effetto lampeggiante invincibile breve
func blink_invincibility():
	var blink_time = 0.2
	for i in 3:
		anim.modulate = Color(1,1,1,0.5)
		await get_tree().create_timer(blink_time).timeout
		anim.modulate = Color(1,1,1,1)
		await get_tree().create_timer(blink_time).timeout
	invincible = false

func dissolve():
	hp = 0
	anim.play("dissolve")
	await anim.animation_finished
	queue_free() # o respawn

# ----------------------------
# === APPARIZIONE ===
# ----------------------------
func appear():
	anim.play("appear")
	await anim.animation_finished
	anim.play("idle")
