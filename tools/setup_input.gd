extends SceneTree
## Tuş atamalarını project.godot içine yazar.
## Kullanım:  godot --headless --path . --script tools/setup_input.gd
## (Kontrolleri değiştirmek istersen Godot'ta Project > Project Settings > Input Map'ten de yapabilirsin.)


func _init() -> void:
	var actions := {
		"move_left": [_key(KEY_A), _key(KEY_LEFT), _joy_axis(JOY_AXIS_LEFT_X, -1.0), _joy_btn(JOY_BUTTON_DPAD_LEFT)],
		"move_right": [_key(KEY_D), _key(KEY_RIGHT), _joy_axis(JOY_AXIS_LEFT_X, 1.0), _joy_btn(JOY_BUTTON_DPAD_RIGHT)],
		"jump": [_key(KEY_SPACE), _key(KEY_W), _key(KEY_UP), _joy_btn(JOY_BUTTON_A)],
		"dash": [_key(KEY_SHIFT), _key(KEY_L), _joy_btn(JOY_BUTTON_RIGHT_SHOULDER)],
		"attack": [_key(KEY_J), _mouse(MOUSE_BUTTON_LEFT), _joy_btn(JOY_BUTTON_X)],
		"parry": [_key(KEY_K), _mouse(MOUSE_BUTTON_RIGHT), _joy_btn(JOY_BUTTON_B)],
		"restart": [_key(KEY_R)],
		"debug_toggle": [_key(KEY_F3)],
	}
	for action_name in actions:
		ProjectSettings.set_setting("input/" + action_name, {"deadzone": 0.5, "events": actions[action_name]})
	var err := ProjectSettings.save()
	print("input map saved, err=", err)
	quit()


func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.device = -1
	e.physical_keycode = code
	return e


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.device = -1
	e.button_index = button
	return e


func _joy_btn(button: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.device = -1
	e.button_index = button
	return e


func _joy_axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.device = -1
	e.axis = axis
	e.axis_value = value
	return e
