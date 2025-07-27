package main
import "core:fmt"
import "core:log"
import "core:math"
import "core:os"
import rl "vendor:raylib"
////////////
// OTHERS //
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


draw_grid :: proc(col: rl.Color) {
	for i: i32 = 0; i < SCREEN_WIDTH; i += GRID_SIZE {
		rl.DrawLine(i, 0, i, SCREEN_HEIGHT, col)
		rl.DrawLine(0, i, SCREEN_WIDTH, i, col)
	}
}


aligned :: proc(v0: Vector2, v1: Vector2) -> bool {
	return v0.x == v1.x || v0.y == v1.y
}

set_dir :: proc(
	game: ^Game,
	velocity: ^Velocity,
	next_dir, current_dir: Vector2,
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

is_move_allowed :: proc(
	velocity: ^Velocity,
	next_dir, current_dir: Vector2,
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

manhattan_distance :: proc(a, b: Vector2) -> f32 {
	return abs(b.x - a.x) + abs(b.y - a.y)

}
vec2_distance :: proc(a, b: Vector2) -> f32 {
	if a.x == b.x && a.y == b.y {
		return 0
	}
	return math.sqrt(math.pow(b.x - a.x, 2.0) + math.pow(b.y - a.y, 2.0))
}

aligned_vectors :: proc(vectors: ..Vector2) -> bool {
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

get_cardinal_direction :: proc(from, to: Vector2) -> Vector2 {
	dx := to.x - from.x
	dy := to.y - from.y
	if (abs(dx) > abs(dy)) {
		return (dx > 0) ? Vector2{1, 0} : Vector2{-1, 0}
	} else {
		return (dy > 0) ? Vector2{0, 1} : Vector2{0, -1}
	}
}

get_ghost_piece_index :: proc(turns_left, tail: i8) -> i8 {
	index := (MAX_RINGBUFFER_VALUES + tail - turns_left) % MAX_RINGBUFFER_VALUES
	return index
}

//
// TESTING :: proc(game: ^Game) {
// 	for i in 1 ..< game.player.num_cells {
// 		prev_cell := game.player.body[i - 1]
// 		next_cell := game.player.body[i]
//
// 		if !rec_colliding(
// 			prev_cell.position,
// 			PLAYER_SIZE,
// 			PLAYER_SIZE,
// 			next_cell.position,
// 			PLAYER_SIZE,
// 			PLAYER_SIZE,
// 		) {
// 			fmt.printf(
// 				"LENGTH BODY %d, PREV_CELL IDX %d, NEXT_CELL IDX %d",
// 				game.player.num_cells,
// 				i - 1,
// 				i,
// 			)
// 			fmt.println("PREV_CELL POS AND DIR", prev_cell.position, prev_cell.direction)
// 			fmt.println("NEXT_CELL POS AND DIR", next_cell.position, next_cell.direction)
// 		}
//
// 		index :=
// 			(MAX_RINGBUFFER_VALUES + game.player.ghost_pieces.tail - next_cell.count_turns_left) %
// 			MAX_RINGBUFFER_VALUES
//
// 		following_ghost_piece := ghost_to_cell(game.player.ghost_pieces.values[index])
// 		if !aligned(next_cell.position, following_ghost_piece.position) &&
// 		   next_cell.count_turns_left != 0 &&
// 		   following_ghost_piece.position != {0, 0} {
//
// 			fmt.println()
// 			fmt.println()
// 			fmt.println(
// 				"GHOST POS AND DIR",
// 				following_ghost_piece.position,
// 				following_ghost_piece.direction,
// 			)
// 			fmt.println("NEXT_CELL POS AND DIR", next_cell.position, next_cell.direction)
// 		}
//
// 	}
// }
//
vec2_add :: proc(v0, v1: Vector2) -> Vector2 {
	return {v0.x + v1.x, v0.y + v1.y}

}
vec2_mul_scalar :: proc(v: Vector2, scalar: f32) -> Vector2 {
	return {v.x * scalar, v.y * scalar}
}

sign :: proc(x: f32) -> f32 {
	return (x > 0) ? 1 : (x < 0) ? -1 : 0
}

magnitude :: proc(v: Vector2) -> f32 {
	return math.sqrt(v.x * v.x + v.y * v.y)
}

shift_array_right :: proc(arr: ^[20]cell_t, count: int) {
	for i := count - 1; i > 0; i -= 1 {
		arr[i] = arr[i - 1]
	}
}

is_oposite_directions :: proc(new, curr: Vector2) -> bool {
	return new.x == -curr.x && new.y == -curr.y
}
