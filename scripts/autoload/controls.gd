extends Node
## Registra los controles del juego al arrancar (así no dependen del editor).
## Se usan teclas físicas: funcionan igual en teclados QWERTY, AZERTY, etc.

func _enter_tree() -> void:
	_keys(&"move_forward", [KEY_W, KEY_UP])
	_keys(&"move_back", [KEY_S, KEY_DOWN])
	_keys(&"move_left", [KEY_A, KEY_LEFT])
	_keys(&"move_right", [KEY_D, KEY_RIGHT])
	_keys(&"jump", [KEY_SPACE])
	_keys(&"sprint", [KEY_SHIFT])
	_keys(&"crouch", [KEY_C, KEY_CTRL])
	_keys(&"interact", [KEY_E])
	_keys(&"flashlight", [KEY_F])
	_keys(&"pause", [KEY_ESCAPE])
	_keys(&"debug", [KEY_F3])
	_mouse(&"use", MOUSE_BUTTON_LEFT)

func _ensure(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

func _keys(action: StringName, keys: Array) -> void:
	_ensure(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)

func _mouse(action: StringName, button: MouseButton) -> void:
	_ensure(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
