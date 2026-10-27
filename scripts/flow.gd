extends RefCounted
## Mapa odleglosci od gracza (BFS po kaflach) w oknie 73x73, liczona po kawalku co klatke,
## zeby nie powodowac przycinek. Wrogowie schodza po gradiencie tej mapy.

const R := 36
const FW := R * 2 + 1

var world
var dist := PackedInt32Array()
var ox := 0
var oy := 0
var valid := false
var _next := PackedInt32Array()
var _queue := PackedInt32Array()
var _nox := 0
var _noy := 0
var _head := 0
var _tail := 0
var _running := false


func _init(w) -> void:
	world = w
	dist.resize(FW * FW)
	_next.resize(FW * FW)
	_queue.resize(FW * FW)
	dist.fill(-1)


func start(center: Vector2) -> void:
	_nox = floori(center.x) - R
	_noy = floori(center.y) - R
	_next.fill(-1)
	var s := R * FW + R
	_next[s] = 0
	_queue[0] = s
	_head = 0
	_tail = 1
	_running = true


func step(budget: int, center: Vector2) -> void:
	if not _running:
		start(center)
	var solid: PackedByteArray = world.solid
	var ww: int = world.w
	var hh: int = world.h
	var n := 0
	while _head < _tail and n < budget:
		var c: int = _queue[_head]
		_head += 1
		n += 1
		var a := c % FW
		var b := c / FW
		var d: int = _next[c] + 1
		var gi := _nox + a
		var gj := _noy + b
		if a > 0 and _next[c - 1] < 0 and gi - 1 >= 0 and solid[gj * ww + gi - 1] == 0:
			_next[c - 1] = d
			_queue[_tail] = c - 1
			_tail += 1
		if a < FW - 1 and _next[c + 1] < 0 and gi + 1 < ww and solid[gj * ww + gi + 1] == 0:
			_next[c + 1] = d
			_queue[_tail] = c + 1
			_tail += 1
		if b > 0 and _next[c - FW] < 0 and gj - 1 >= 0 and solid[(gj - 1) * ww + gi] == 0:
			_next[c - FW] = d
			_queue[_tail] = c - FW
			_tail += 1
		if b < FW - 1 and _next[c + FW] < 0 and gj + 1 < hh and solid[(gj + 1) * ww + gi] == 0:
			_next[c + FW] = d
			_queue[_tail] = c + FW
			_tail += 1
	if _head >= _tail:
		dist = _next.duplicate()
		ox = _nox
		oy = _noy
		valid = true
		_running = false


func dist_at(p: Vector2) -> int:
	var a := floori(p.x) - ox
	var b := floori(p.y) - oy
	if not valid or a < 0 or b < 0 or a >= FW or b >= FW:
		return -1
	return dist[b * FW + a]


## Punkt (srodek kafla) do ktorego warto isc, albo Vector2.ZERO gdy brak sciezki.
func next_target(p: Vector2) -> Vector2:
	var a := floori(p.x) - ox
	var b := floori(p.y) - oy
	if not valid or a < 0 or b < 0 or a >= FW or b >= FW:
		return Vector2.ZERO
	var cur: int = dist[b * FW + a]
	if cur <= 0:
		return Vector2.ZERO
	var best := cur
	var bi := a
	var bj := b
	for n in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
		var aa: int = a + n.x
		var bb: int = b + n.y
		if aa < 0 or bb < 0 or aa >= FW or bb >= FW:
			continue
		var d: int = dist[bb * FW + aa]
		if d < 0 or d >= best:
			continue
		if n.x != 0 and n.y != 0 and (dist[b * FW + aa] < 0 or dist[bb * FW + a] < 0):
			continue
		best = d
		bi = aa
		bj = bb
	return Vector2(ox + bi + 0.5, oy + bj + 0.5)
