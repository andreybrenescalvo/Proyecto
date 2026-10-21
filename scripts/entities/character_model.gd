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

## Dónde quedan las manos al escribir (relativo al modelo sentado, que mira hacia -Z).
const TYPING_HANDS := [Vector3(-0.17, 0.3, -0.52), Vector3(0.17, 0.3, -0.52)]
const TYPING_ELBOWS := [Vector3(-0.55, -0.2, 0.1), Vector3(0.55, -0.2, 0.1)]

var anim: AnimationPlayer
var current := ""
var _model: Node3D
var _typing_ik: TwoBoneIK3D
var _typing_targets: Array[Marker3D] = []
var _typing_time := 0.0

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

## Escribir en un teclado (sentado): las manos van a las teclas con cinemática inversa de dos
## huesos (brazo y antebrazo) y se mueven un poquito, como tecleando.
func set_typing(on: bool) -> void:
	if on and _typing_ik == null:
		var sk := skeleton()
		if sk == null:
			return
		_typing_ik = TwoBoneIK3D.new()
		_typing_ik.name = "Teclear"
		sk.add_child(_typing_ik)
		_typing_ik.setting_count = 2
		for i in 2:
			var side := "l" if i == 0 else "r"
			var target := Marker3D.new()
			target.position = TYPING_HANDS[i]
			add_child(target)
			_typing_targets.append(target)
			var pole := Marker3D.new()
			pole.position = TYPING_ELBOWS[i]
			add_child(pole)
			_typing_ik.set_root_bone_name(i, "upperarm_" + side)
			_typing_ik.set_middle_bone_name(i, "lowerarm_" + side)
			_typing_ik.set_end_bone_name(i, "hand_" + side)
			_typing_ik.set_target_node(i, _typing_ik.get_path_to(target))
			_typing_ik.set_pole_node(i, _typing_ik.get_path_to(pole))
	if _typing_ik:
		_typing_ik.active = on
		set_process(on)

func _process(delta: float) -> void:
	if _typing_ik == null or not _typing_ik.active:
		return
	_typing_time += delta
	for i in _typing_targets.size():
		var tap := maxf(sin(_typing_time * (11.0 + i * 2.3) + i * 1.7), 0.0)
		_typing_targets[i].position = TYPING_HANDS[i] + Vector3(sin(_typing_time * 1.3 + i) * 0.04, tap * 0.025, 0)

func skeleton() -> Skeleton3D:
	return _model.find_child("Skeleton3D", true, false)
