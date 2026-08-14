extends Control

@onready var _currency_label: Label = $CurrencyLabel
@onready var _upgrades_container: VBoxContainer = $UpgradesContainer


func _ready() -> void:
	MetaProgression.currency_changed.connect(_on_currency_changed)
	MetaProgression.stat_changed.connect(_on_stat_changed)
	for def in MetaProgression.get_stat_defs():
		_add_upgrade_button(def)
	_refresh_currency()


func _add_upgrade_button(def: StatDef) -> void:
	var button := Button.new()
	button.name = _button_name(def.id)
	button.pressed.connect(_on_upgrade_pressed.bind(def.id))
	_upgrades_container.add_child(button)
	_refresh_button(def)


func _on_upgrade_pressed(id: StringName) -> void:
	MetaProgression.buy_upgrade(id)


func _on_currency_changed(_current: int) -> void:
	_refresh_currency()
	for def in MetaProgression.get_stat_defs():
		_refresh_button(def)


func _on_stat_changed(stat_id: StringName, _new_value: float) -> void:
	for def in MetaProgression.get_stat_defs():
		if def.id == stat_id:
			_refresh_button(def)
			return


func _on_start_run_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/arena.tscn")


func _refresh_currency() -> void:
	_currency_label.text = "Currency: %d" % MetaProgression.currency


func _refresh_button(def: StatDef) -> void:
	var button: Button = _upgrades_container.get_node(_button_name(def.id))
	var current := MetaProgression.get_stat(def.id)
	button.text = (
		"%s: %s   (+%s for %d currency)"
		% [
			def.display_name,
			_format(current, def.decimals),
			_format(def.upgrade_amount, def.decimals),
			def.upgrade_cost,
		]
	)
	button.disabled = MetaProgression.currency < def.upgrade_cost


func _button_name(id: StringName) -> String:
	return "Upgrade_%s" % id


func _format(value: float, decimals: int) -> String:
	return ("%." + str(decimals) + "f") % value
