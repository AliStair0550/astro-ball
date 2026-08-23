class_name GameFeel
extends Node

## Genbrugelig game feel-værktøjskasse.
##
## Fase 1 bruger kun screen shake (2 px / 60 ms ved vægramt).
## Hitstop er implementeret, men kaldes med 0 og aktiveres i fase 2,
## når klodser og sprængklodser kommer til.
##
## Squash er en lille hjælpeklasse, som paddlen bruger nu, og som
## klodser og power-up-kapsler kan genbruge senere.

## Kameraet, der forskydes ved shake. Sættes fra scenen.
@export var camera_path: NodePath

var _camera: Camera2D

var _shake_amplitude := 0.0
var _shake_duration := 0.0
var _shake_left := 0.0

var _hitstop_left := 0.0


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera2D
	# Kør efter alt andet, så kameraforskydningen er frisk i samme frame.
	process_priority = 100


## Sandt, mens spillet er frosset. Bold og paddle springer deres
## opdatering over, mens dette er sandt.
func is_frozen() -> bool:
	return _hitstop_left > 0.0


## Frys spillet i N sekunder. Fase 1 kalder altid med 0.
func hitstop(seconds: float) -> void:
	if seconds <= 0.0:
		return
	_hitstop_left = maxf(_hitstop_left, seconds)


## Ryst kameraet. Amplitude i px, varighed i sekunder.
## Et kraftigere shake overskriver et svagere. Et svagere forlænger ikke.
func shake(amplitude: float, seconds: float) -> void:
	if amplitude <= 0.0 or seconds <= 0.0:
		return
	if amplitude >= _shake_amplitude * (_shake_left / maxf(_shake_duration, 0.0001)):
		_shake_amplitude = amplitude
		_shake_duration = seconds
		_shake_left = seconds


func _process(delta: float) -> void:
	if _hitstop_left > 0.0:
		_hitstop_left = maxf(0.0, _hitstop_left - delta)

	if _camera == null:
		return

	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - delta)
		var falloff := _shake_left / maxf(_shake_duration, 0.0001)
		var a := _shake_amplitude * falloff
		_camera.offset = Vector2(randf_range(-a, a), randf_range(-a, a))
		if _shake_left <= 0.0:
			_shake_amplitude = 0.0
			_camera.offset = Vector2.ZERO
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO


## Squash og stretch som en lille tilstandsmaskine.
##
## Brug: kald trigger() ved kontakt, og gang højden med update(delta)
## i _process. Returnerer 1.0, når den er i hvile.
class Squash extends RefCounted:
	## Hvor sammenpresset, den bliver. 0.9 = 90 % højde.
	var squash_to := 0.9
	## Tid ind i sammenpresningen.
	var squash_time := 0.08
	## Tid tilbage til hvile, inklusive overshoot.
	var release_time := 0.16
	## Hvor meget den skyder over 1.0 på vej tilbage.
	var overshoot := 1.06

	var _t := -1.0

	func trigger() -> void:
		_t = 0.0

	func is_active() -> bool:
		return _t >= 0.0

	func update(delta: float) -> float:
		if _t < 0.0:
			return 1.0
		_t += delta
		if _t < squash_time:
			# Hurtigt ind.
			return lerpf(1.0, squash_to, ease(_t / squash_time, 0.35))
		var r := (_t - squash_time) / release_time
		if r >= 1.0:
			_t = -1.0
			return 1.0
		# Tilbage med et lille overshoot på midten af udturen.
		return lerpf(squash_to, 1.0, r) + sin(r * PI) * (overshoot - 1.0)
