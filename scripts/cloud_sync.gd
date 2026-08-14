extends Node

## Optional cloud-sync for meta-progression.
## Syncs save data to cloud on run end and quit for cross-device access.
## Offline-first: saves work fully offline, sync is best-effort.

signal sync_completed
signal sync_failed(error: String)

const CLOUD_CONFIG_FILE: String = "user://cloud_sync.json"
const SYNC_TIMEOUT: float = 10.0

var _enabled: bool = false
var _device_id: String = ""
var _email: String = ""
var _last_sync_time: int = 0


func _ready() -> void:
	_load_config()


func _load_config() -> void:
	if not ResourceLoader.exists(CLOUD_CONFIG_FILE):
		return
	var file := FileAccess.open(CLOUD_CONFIG_FILE, FileAccess.READ)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data == null:
		return
	_enabled = data.get("enabled", false)
	_device_id = data.get("device_id", "")
	_email = data.get("email", "")
	_last_sync_time = data.get("last_sync", 0)


func enable_sync(email: String) -> void:
	if email.is_empty():
		return
	_email = email
	_enabled = true
	_device_id = _generate_device_id()
	_save_config()


func disable_sync() -> void:
	_enabled = false
	_device_id = ""
	_email = ""
	_save_config()


func sync_now() -> void:
	if not _enabled:
		return
	# TODO: Implement actual cloud sync
	# For now, just track that sync was attempted
	_last_sync_time = Time.get_ticks_msec() / 1000
	_save_config()
	sync_completed.emit()


func _save_config() -> void:
	var data := {
		"enabled": _enabled,
		"device_id": _device_id,
		"email": _email,
		"last_sync": _last_sync_time
	}
	var file := FileAccess.open(CLOUD_CONFIG_FILE, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))


func _generate_device_id() -> String:
	return "%s_%d" % [OS.get_unique_id(), Time.get_ticks_msec()]


func is_enabled() -> bool:
	return _enabled


func get_email() -> String:
	return _email


func get_last_sync_time() -> int:
	return _last_sync_time
