class_name CharacterModel
extends Node3D
## Una persona animada: el modelo armado en Blender (tools/personajes) con las animaciones de la
## Universal Animation Library de Quaternius (CC0). Mira hacia -Z, como los jugadores y el dueño.
##
## Uso: CharacterModel.create("mudancero"), y después play("Walk") o, más simple,
## update_from(moviéndose, corriendo, agachado, linterna, en el aire).

const DIR := "res://assets/characters/"
const ANIMATIONS := DIR + "animaciones.glb"
## Modelos de los jugadores (se reparten por número de jugador).
const PLAYER_MODELS := ["mudancero", "mudancera", "mudancero2"]
const BLEND := 0.2

static var _library: AnimationLibrary

var anim: AnimationPlayer
var current := ""
var _model: Node3D

static func create(model_name: String) -> CharacterModel:
	var c := CharacterModel.new()
	c.name = "Modelo"
	var scene := load(DIR + model_name + ".gltf") as PackedScene
	c._model = scene.instantiate()
	c._model.rotation.y = PI      # el modelo mira hacia +Z; el juego, hacia -Z
	c.add_child(c._model)
	c.anim = AnimationPlayer.new()
	c.anim.name = "AnimationPlayer"
	c._model.add_child(c.anim)
	c.anim.root_node = NodePath("..")
	c.anim.add_animation_library("", library())
	for mi in c._model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	c.play("Idle")
	return c

## Las animaciones se cargan una sola vez y las comparten todos.
static func library() -> AnimationLibrary:
	if _library == null:
		var scene := (load(ANIMATIONS) as PackedScene).instantiate()
		var ap: AnimationPlayer = scene.find_child("AnimationPlayer", true, false)
		# (Godot ya les saca el "_Loop" del nombre y las deja en bucle.)
		_library = ap.get_animation_library("")
		scene.free()
	return _library

func play(anim_name: String, speed := 1.0, blend := BLEND) -> void:
	anim.speed_scale = speed
	if anim_name == current:
		return
	current = anim_name
	anim.play(anim_name, blend)

## Elige la animación según lo que está haciendo.
func update_from(moving: bool, sprinting: bool, crouching: bool, torch: bool, in_air := false) -> void:
	if in_air:
		play("Jump")
	elif crouching:
		play("Crouch_Fwd" if moving else "Crouch_Idle")
	elif moving:
		play("Sprint" if sprinting else "Walk")
	else:
		play("Idle_Torch" if torch else "Idle")

## Solo la sombra (el cuerpo del jugador propio: no se ve, pero su sombra sí).
func shadow_only() -> void:
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

func skeleton() -> Skeleton3D:
	return _model.find_child("Skeleton3D", true, false)
