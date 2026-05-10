class_name DungeonGenerator

const MIN_LEAF_SIZE: int = 15
const MAX_LEAF_SIZE: int = 20 
const MIN_ROOM_SIZE: int = 12
const ROOM_MARGIN: int = 5

class Leaf:
	var x: int
	var y: int
	var w: int
	var h: int
	var left_child: Leaf = null
	var right_child: Leaf = null
	var room: Rect2i = Rect2i()

	func _init(_x, _y, _w, _h):
		x = _x; y = _y; w = _w; h = _h

	func split() -> bool:
		if left_child != null:
			return false
		# decide split direction
		var split_h = randf() > 0.5
		if w > h and float(w) / h >= 1.25:
			split_h = false
		elif h > w and float(h) / w >= 1.25:
			split_h = true

		var max_size = (h if split_h else w) - MIN_LEAF_SIZE
		if max_size <= MIN_LEAF_SIZE:
			return false  # too small to split

		var split_pos = randi_range(MIN_LEAF_SIZE, max_size)

		if split_h:
			left_child  = Leaf.new(x, y, w, split_pos)
			right_child = Leaf.new(x, y + split_pos, w, h - split_pos)
		else:
			left_child  = Leaf.new(x, y, split_pos, h)
			right_child = Leaf.new(x + split_pos, y, w - split_pos, h)
		return true

	func get_leaves() -> Array:
		if left_child == null:
			return [self]
		return left_child.get_leaves() + right_child.get_leaves()

	func create_room():
		if left_child != null:
			left_child.create_room()
			right_child.create_room()
			return
		var rx = x + randi_range(ROOM_MARGIN, max(ROOM_MARGIN, w - MIN_ROOM_SIZE - ROOM_MARGIN))
		var ry = y + randi_range(ROOM_MARGIN, max(ROOM_MARGIN, h - MIN_ROOM_SIZE - ROOM_MARGIN))
		var rw = randi_range(MIN_ROOM_SIZE, w - (rx - x) - ROOM_MARGIN)
		var rh = randi_range(MIN_ROOM_SIZE, h - (ry - y) - ROOM_MARGIN)
		room = Rect2i(rx, ry, rw, rh)

	func get_room() -> Rect2i:
		if left_child == null:
			return room
		var l = left_child.get_room()
		var r = right_child.get_room()
		if l == Rect2i(): return r
		if r == Rect2i(): return l
		return l if randf() > 0.5 else r

# --- Main generation function ---
static func generate(map_w: int, map_h: int, num_splits: int = 6) -> Dictionary:
	var root = Leaf.new(0, 0, map_w, map_h)
	var leaves: Array = [root]

	# BSP splitting
	for i in num_splits:
		var to_split = leaves.filter(func(l): return l.left_child == null)
		if to_split.is_empty(): break
		var leaf = to_split.pick_random()
		if leaf.split():
			leaves.append(leaf.left_child)
			leaves.append(leaf.right_child)

	root.create_room()

	var rooms: Array = []
	var corridors: Array = []  # Array of Array[Vector2i] pairs

	for leaf in root.get_leaves():
		if leaf.room != Rect2i():
			rooms.append(leaf.room)

	_connect_leaves(root, corridors)

	return { "rooms": rooms, "corridors": corridors }

static func _connect_leaves(leaf: Leaf, corridors: Array):
	if leaf.left_child == null:
		return
	_connect_leaves(leaf.left_child, corridors)
	_connect_leaves(leaf.right_child, corridors)

	var l_room = leaf.left_child.get_room()
	var r_room = leaf.right_child.get_room()
	if l_room == Rect2i() or r_room == Rect2i():
		return

	# Connect centre points with an L-shaped corridor
	var p1 = Vector2i(l_room.position.x + l_room.size.x / 2,
					  l_room.position.y + l_room.size.y / 2)
	var p2 = Vector2i(r_room.position.x + r_room.size.x / 2,
					  r_room.position.y + r_room.size.y / 2)
	corridors.append([p1, p2])
