package main
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

////////////
// OTHERS //
////////////
draw_grid :: proc(col: rl.Color) {
	for i: i32 = 0; i < SCREEN_WIDTH; i += GRID_SIZE {
		rl.DrawLine(i, 0, i, SCREEN_HEIGHT, col)
		rl.DrawLine(0, i, SCREEN_WIDTH, i, col)
	}
}


aligned :: proc(v0: Vector2, v1: Vector2) -> bool {
	return v0.x == v1.x || v0.y == v1.y
}

try_set_dir :: proc(
	velocity: ^Velocity,
	next_dir, current_dir: Vector2,
	data: ^PlayerData,
) -> bool {
	if !oposite_directions(next_dir, current_dir) && next_dir != current_dir {
		velocity.direction = next_dir
		if current_dir != {0, 0} {
			data.previous_dir = current_dir
		}
		return true
	}
	return false
}


add_turn_count :: proc(world: ^World, body: ^Body) {
	fmt.println("WE ADD TURN TO COUT")
	archetypes, is_empty := query_archetype(world, body_mask)
	if is_empty {
		return
	}

	for archetype in archetypes {
		fmt.println("NUMBER OF ENTITIES ", len(archetype.entities_id))
		for i in 0 ..< len(archetype.entities_id) {
			fmt.println("INDEX OF ENTITY: ", i)
			if archetype.data[i].kind == .BODY {

				archetype.players_data[i].count_turn_left += 1
			}
		}

	}

}

ghost_to_cell :: proc(cell: cell_ghost_t) -> cell_t {
	return cell_t{position = cell.position, direction = cell.direction}
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

oposite_directions :: proc(new, curr: Vector2) -> bool {
	return new.x == -curr.x && new.y == -curr.y
}
