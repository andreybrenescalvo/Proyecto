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
	_keys(&"interact", [KEY_E])
	_keys(&"tool_pickaxe", [KEY_1])
	_keys(&"tool_dynamite", [KEY_2])
	_keys(&"tool_support", [KEY_3])
	_keys(&"charge_up", [KEY_EQUAL, KEY_KP_ADD])
	_keys(&"charge_down", [KEY_MINUS, KEY_KP_SUBTRACT])
	_keys(&"pause", [KEY_ESCAPE])
	_keys(&"debug", [KEY_F3])
	_mouse(&"use", MOUSE_BUTTON_LEFT)
	_mouse(&"charge_up", MOUSE_BUTTON_WHEEL_UP)
	_mouse(&"charge_down", MOUSE_BUTTON_WHEEL_DOWN)

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
