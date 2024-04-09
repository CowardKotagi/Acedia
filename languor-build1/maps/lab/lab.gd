extends Node3D

@onready var Player : CharacterBody3D = $peika
@onready var Enemies: Node = $Enemies
@onready var temp: CharacterBody3D = $Enemies/EnemyBase

func _ready():
	pass

#func _physics_process(_delta):
	#get_tree().call_group("npc", "update_target_location", Player.global_transform.origin)
