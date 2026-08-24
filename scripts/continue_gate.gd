class_name ContinueGate
extends RefCounted

## The seam a rewarded ad plugs into, built before the ad exists.
##
## Section 16 gives RE-ENTRY two prices: in the free version you watch a
## rewarded ad for it, in the paid version it is free once per field.
## Section 19 puts all monetisation after phase 8, so neither a store nor
## an ad network is in this project and none should be added yet.
##
## What lives here is only the decision. The game asks the gate what a
## re-entry costs and acts on the answer, so when an ad layer arrives it
## sets `rewarded_ready`, listens for `ad_requested` and calls `resolve`.
## Nothing in game.gd, screens.gd or the level state has to change.

signal granted()
signal denied()
## An ad layer will connect to this. Nothing does today.
signal ad_requested()

enum Cost {
	## Take it, no strings.
	FREE,
	## An ad is ready and the player has not bought the unlock.
	WATCH_AD,
	## Already used on this field.
	UNAVAILABLE,
}

## Section 16: one re-entry per field.
const MAX_PER_FIELD := 1

## True once "Astro Ball Complete" is owned. No store yet, so no way to
## set it, which is exactly the free-version case.
var entitled := false
## Set by the ad layer when it has an ad in hand. Nothing sets it today.
var rewarded_ready := false

var _pending := false


func cost_for(used_this_field: int) -> Cost:
	if used_this_field >= MAX_PER_FIELD:
		return Cost.UNAVAILABLE
	if entitled:
		return Cost.FREE
	if rewarded_ready:
		return Cost.WATCH_AD
	# No store and no ad network in the build, so the offer stands free.
	# The branch above is the one that lights up when either arrives.
	return Cost.FREE


func available(used_this_field: int) -> bool:
	return cost_for(used_this_field) != Cost.UNAVAILABLE


## Asks for a re-entry. FREE grants at once. WATCH_AD asks the ad layer
## and waits for resolve(). UNAVAILABLE denies.
func request(used_this_field: int) -> void:
	match cost_for(used_this_field):
		Cost.FREE:
			granted.emit()
		Cost.WATCH_AD:
			_pending = true
			ad_requested.emit()
		_:
			denied.emit()


## Called by the ad layer when the player finished or abandoned the ad.
func resolve(watched: bool) -> void:
	if not _pending:
		return
	_pending = false
	if watched:
		granted.emit()
	else:
		denied.emit()


func is_pending() -> bool:
	return _pending
