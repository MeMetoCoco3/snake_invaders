package main
import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import "core:mem"
import "core:os"
import rl "vendor:raylib"

//////////////
//// MATH ////
//////////////

angle_from_vector :: proc(v0: Vec2) -> f32 {
	return math.atan2(v0.y, v0.x) * (180.0 / math.PI)
}

radians_from_vector :: proc(v: Vec2) -> f32 {
	return math.atan2_f32(v.y, v.x)

}

vec2_normalize :: proc(v: ^Vec2) {
	x, y: f32
	if v.x == 0 {
		x = 0
	} else {
		x = v.x / abs(v.x)
	}
	if v.y == 0 {
		y = 0
	} else {
		y = v.y / abs(v.y)
	}
	v.x = x
	v.y = y
}


aligned :: proc(v0: Vec2, v1: Vec2) -> bool {
	return v0.x == v1.x || v0.y == v1.y
}

manhattan_distance :: proc(a, b: Vec2) -> f32 {
	return abs(b.x - a.x) + abs(b.y - a.y)

}

vec2_distance :: proc(a, b: Vec2) -> f32 {
	if a.x == b.x && a.y == b.y {
		return 0
	}
	return math.sqrt(math.pow(b.x - a.x, 2.0) + math.pow(b.y - a.y, 2.0))
}

aligned_vectors :: proc(vectors: ..Vec2) -> bool {
	aligned_x := true
	aligned_y := true

	for i in 1 ..< len(vectors) {
		prev := vectors[i - 1]
		curr := vectors[i]

		if prev.x != curr.x {
			aligned_x = false
		}
		if prev.y != curr.y {
			aligned_y = false
		}
	}
	return aligned_x || aligned_y
}

get_cardinal_direction :: proc(from, to: Vec2) -> Vec2 {
	dx := to.x - from.x
	dy := to.y - from.y
	if (abs(dx) > abs(dy)) {
		return (dx > 0) ? Vec2{1, 0} : Vec2{-1, 0}
	} else {
		return (dy > 0) ? Vec2{0, 1} : Vec2{0, -1}
	}
}


point_between_given_distance :: proc(a, b: Vec2, f: f32) -> Vec2 {
	dir := b - a
	normal_dir := linalg.normalize(dir)
	new_point := a + normal_dir * f
	return new_point
}

proj_point_over_line :: proc(a, b, c: Vec2) -> Vec2 {
	ab := b - a
	ac := c - a

	dot_abc := linalg.dot(ab, ac)

	length_square := linalg.length2(ab)
	t := dot_abc / length_square
	return Vec2{a.x + t * ab.x, a.y + t * ab.y}
}


sign :: proc(x: f32) -> f32 {
	return (x > 0) ? 1 : (x < 0) ? -1 : 0
}

magnitude :: proc(v: Vec2) -> f32 {
	return math.sqrt(v.x * v.x + v.y * v.y)
}

shift_array_right :: proc(arr: ^[20]cell_t, count: int) {
	for i := count - 1; i > 0; i -= 1 {
		arr[i] = arr[i - 1]
	}
}


////////////////
////STRUCTURE///
////////////////

set_body_0 :: proc(game: ^Game) {
	raw, _ := mem.alloc(size_of(Ringuffer_t(cell_ghost_t)))
	rb_ghost := cast(^Ringuffer_t(cell_ghost_t))raw
	rb_ghost.values = make([]cell_ghost_t, MAX_RINGBUFFER_VALUES)
	game.player_body.ghost_pieces = rb_ghost
}

set_directions_0 :: proc(game: ^Game) {
	raw, _ := mem.alloc(size_of(Ringuffer_t(Vec2)))
	rb_dir := cast(^Ringuffer_t(Vec2))raw
	rb_dir.values = make([]Vec2, MAX_RINGBUFFER_VALUES)
	game.directions = rb_dir
}


//////////////
////SYSTEMS///
//////////////


has_component :: proc(mask, component: COMPONENT_ID) -> bool {
	return (mask & component) == component
}

get_closest_candy :: proc(g: ^Game, v: Vec2) -> (target: Target_Information, closest: f32) {
	archetype := g.world.archetypes[candy_mask]
	closest = 1000

	for i in 0 ..< len(archetype.entities_id) {
		position := &archetype.positions[i]
		new_distance := vec2_distance(v, position.pos)

		if new_distance < closest {
			closest = new_distance
			target.position = position
			target.data = &archetype.data[i]
		}

	}

	return target, closest
}


rec_colliding :: proc(v0: Vec2, w0: f32, h0: f32, v1: Vec2, w1: f32, h1: f32) -> bool {
	horizontal_in :=
		(v0.x <= v1.x && v0.x + w0 >= v1.x) || (v0.x <= v1.x + w1 && v0.x + w0 >= v1.x + w1)
	vertical_in :=
		(v0.y <= v1.y && v0.y + h0 >= v1.y) || (v0.y <= v1.y + h1 && v0.y + h0 >= v1.y + h1)
	return horizontal_in && vertical_in
}

rec_colliding_no_edges :: proc(v0: Vec2, w0: f32, h0: f32, v1: Vec2, w1: f32, h1: f32) -> bool {
	horizontal_in :=
		(v0.x < v1.x && v0.x + w0 > v1.x) || (v0.x < v1.x + w1 && v0.x + w0 > v1.x + w1)
	vertical_in := (v0.y < v1.y && v0.y + h0 > v1.y) || (v0.y < v1.y + h1 && v0.y + h0 > v1.y + h1)
	return horizontal_in && vertical_in
}

collide_no_edges :: proc(c0, c1: Collider) -> bool {
	v0 := c0.position
	w0 := f32(c0.w)
	h0 := f32(c0.h)

	v1 := c1.position
	w1 := f32(c1.w)
	h1 := f32(c1.h)

	a := (v0.x < v1.x + w1 && v0.x + w0 > v1.x && v0.y < v1.y + h1 && v0.y + h0 > v1.y)
	b := (v0.x + w0 == v1.x || v0.x == v1.x + w1 || v0.y + h0 == v1.y || v0.y == v1.y + h1)

	return a && !b
}

collide :: proc(c0, c1: Collider) -> bool {
	v0 := c0.position
	w0 := f32(c0.w)
	h0 := f32(c0.h)

	v1 := c1.position
	w1 := f32(c1.w)
	h1 := f32(c1.h)

	horizontal_in :=
		(v0.x <= v1.x && v0.x + w0 >= v1.x) || (v0.x <= v1.x + w1 && v0.x + w0 >= v1.x + w1)
	vertical_in :=
		(v0.y <= v1.y && v0.y + h0 >= v1.y) || (v0.y <= v1.y + h1 && v0.y + h0 >= v1.y + h1)
	return horizontal_in && vertical_in
}

is_oposite_directions :: proc(new, curr: Vec2) -> bool {
	return new.x == -curr.x && new.y == -curr.y
}


aligned_to_grid :: proc(p: Vec2) -> bool {
	return i32(p.x) % GRID_SIZE == 0 && i32(p.y) % GRID_SIZE == 0
}

circle_colliding :: proc(v0, v1: Vec2, d0, d1: f32) -> bool {
	return vec2_distance(v0, v1) < d0 + d1
}

set_dir :: proc(
	game: ^Game,
	velocity: ^Velocity,
	next_dir, current_dir: Vec2,
	data: ^PlayerData,
) -> bool {
	velocity.direction = next_dir
	if current_dir != {0, 0} {
		data.previous_dir = current_dir
	}
	if next_dir != {0, 0} {
		return true
	}
	return false
}
set_piece_to_follow :: proc(
	ghosts: ^Ringuffer_t(cell_ghost_t),
	turns_left: int,
	head_pos, head_dir: Vec2,
	piece_to_follow: ^cell_t,
	ghost_index_being_followed: ^int,
) {
	if turns_left == 0 {
		piece_to_follow^ = cell_t{head_pos, head_dir, 0, PLAYER_SIZE, {}}
		ghost_index_being_followed^ = -1
	} else {
		ghost_index_being_followed^ =
			(MAX_RINGBUFFER_VALUES + int(ghosts.tail) - turns_left) % MAX_RINGBUFFER_VALUES
		piece_to_follow^ = ghost_to_cell(ghosts.values[ghost_index_being_followed^])
	}
}

is_move_allowed :: proc(
	velocity: ^Velocity,
	next_dir, current_dir: Vec2,
	data: ^PlayerData,
	game: ^Game,
) -> bool {
	moved_enough := data.time_since_turn >= PLAYER_SIZE ? true : false
	has_body := game.player_body.num_cells > 0

	if !has_body {
		return true
	}


	if !moved_enough {
		last_index := (MAX_RINGBUFFER_VALUES + game.directions.tail - 2) % MAX_RINGBUFFER_VALUES
		last_dir := game.directions.values[last_index]
		if is_oposite_directions(next_dir, last_dir) {
			velocity.direction = {0, 0}
			return false
		}
	}

	if game.player_body.num_cells > 0 {
		last_index := (MAX_RINGBUFFER_VALUES + game.directions.tail - 1) % MAX_RINGBUFFER_VALUES
		last_dir := game.directions.values[last_index]
		if is_oposite_directions(next_dir, last_dir) {
			velocity.direction = {0, 0}
			return false
		}
	}

	if !is_oposite_directions(next_dir, current_dir) && next_dir != current_dir {
		return true
	}
	return false
}

add_turn_count :: proc(world: ^World) {
	archetypes, is_empty := query_archetype(world, body_mask)
	if is_empty {
		return
	}


	for archetype in archetypes {
		for i in 0 ..< len(archetype.entities_id) {
			if archetype.data[i].kind == .BODY {
				archetype.players_data[i].count_turn_left += 1
			}
		}
	}
}

ghost_to_cell :: proc(cell: cell_ghost_t) -> cell_t {
	return cell_t{position = cell.position, direction = cell.direction}
}

// TODO: OPTIMIZE
check_broken_ghost :: proc(world: ^World, rb: ^Ringuffer_t(cell_ghost_t), body: []Position) {
	last, ok := peek_last(rb);if !ok do return
	for piece in body {
		if vec2_distance(piece.pos, last.position) < PLAYER_SIZE {
			return
		}
	}

	ghost, _ := pop_cell(rb)
	kill_entity(world.archetypes[ghost_mask], ghost.entity_id)
	fmt.println("WE KILLED")
}

get_ghost_piece_index :: proc(turns_left, tail: i8) -> i8 {
	index := (MAX_RINGBUFFER_VALUES + tail - turns_left) % MAX_RINGBUFFER_VALUES
	return index
}

////////////
// LOGGER //
////////////

get_logger :: proc() -> log.Logger {
	mode: int = 0
	when ODIN_OS == .Linux || ODIN_OS == .Darwin {
		mode = os.S_IRUSR | os.S_IWUSR | os.S_IRGRP | os.S_IROTH
	}

	logh, logh_err := os.open("log.txt", (os.O_CREATE | os.O_TRUNC | os.O_RDWR), mode)

	if logh_err == os.ERROR_NONE {
		// os.stdout = logh
		os.stderr = logh
	}

	return log.create_file_logger(logh)
}

delete_logger :: proc(logger: log.Logger) {
	log.destroy_file_logger(logger)
}


///////////////
/// TESTING ///
///////////////

spawn_triangle :: proc(w: ^World) {
	tri := Visual(
		Shape{num_sides = 10, angle = 0, size = 50, center = {400, 400}, color = rl.GREEN},
	)
	add_entity(
		w,
		COMPONENT_ID.VISUAL | .POSITION | .DATA,
		[]Component{Position{{400, 400}, {40, 40}}, tri, Data{.ENEMY, .ALIVE, .GOOD}},
	)

}
