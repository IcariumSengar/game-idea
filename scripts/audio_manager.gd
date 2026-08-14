extends Node

## Procedural SFX: the project ships with no audio assets yet, so short
## cues (blips/sweeps/chimes) are synthesized once at startup instead of
## loading sound files. Swap _make_* calls for preloaded AudioStreamWAV/OGG
## assets later without touching any call site.

const SAMPLE_RATE: int = 22050
const POOL_SIZE: int = 8

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_streams["enemy_hit"] = _make_tone(220.0, 0.06, 0.35, "square")
	_streams["enemy_death"] = _make_tone(160.0, 0.14, 0.4, "square", true)
	_streams["player_hit"] = _make_tone(140.0, 0.09, 0.45, "square")
	_streams["player_death"] = _make_sweep(420.0, 70.0, 0.55, 0.5)
	_streams["pickup"] = _make_tone(880.0, 0.05, 0.25, "sine")
	_streams["purchase"] = _make_chime([660.0, 990.0], 0.08, 0.3)
	_streams["dash"] = _make_sweep(320.0, 720.0, 0.1, 0.28)
	_streams["click"] = _make_tone(520.0, 0.03, 0.2, "sine")

	for i in POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.bus = "Master"
		add_child(player)
		_players.append(player)


func play(cue: String, volume_db: float = 0.0, pitch_variance: float = 0.08) -> void:
	if cue not in _streams:
		return
	var player := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	player.stream = _streams[cue]
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-pitch_variance, pitch_variance)
	player.play()


func _make_tone(
	freq: float, duration: float, volume: float, wave: String, pitch_drop: bool = false
) -> AudioStreamWAV:
	var sample_count := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var progress: float = float(i) / sample_count
		var t: float = float(i) / SAMPLE_RATE
		var env: float = 1.0 - progress
		var f: float = lerp(freq * 1.6, freq * 0.6, progress) if pitch_drop else freq
		var sample: float = (
			(1.0 if sin(TAU * f * t) >= 0.0 else -1.0) if wave == "square" else sin(TAU * f * t)
		)
		sample *= env * volume
		data.encode_s16(i * 2, clampi(int(sample * 32767.0), -32768, 32767))
	return _to_wav(data)


func _make_sweep(
	freq_start: float, freq_end: float, duration: float, volume: float
) -> AudioStreamWAV:
	var sample_count := int(SAMPLE_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	var phase: float = 0.0
	for i in sample_count:
		var progress: float = float(i) / sample_count
		var env: float = 1.0 - progress
		var f: float = lerp(freq_start, freq_end, progress)
		phase += f / SAMPLE_RATE
		var sample: float = sin(TAU * phase) * env * volume
		data.encode_s16(i * 2, clampi(int(sample * 32767.0), -32768, 32767))
	return _to_wav(data)


func _make_chime(freqs: Array, note_duration: float, volume: float) -> AudioStreamWAV:
	var per_note: int = int(SAMPLE_RATE * note_duration)
	var sample_count: int = per_note * freqs.size()
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for i in sample_count:
		var note_index: int = i / per_note
		var local_i: int = i % per_note
		var t: float = float(local_i) / SAMPLE_RATE
		var env: float = 1.0 - float(local_i) / per_note
		var f: float = freqs[note_index]
		var sample: float = sin(TAU * f * t) * env * volume
		data.encode_s16(i * 2, clampi(int(sample * 32767.0), -32768, 32767))
	return _to_wav(data)


func _to_wav(data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	return stream
