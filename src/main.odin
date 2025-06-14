package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 800
PLAYER_SIZE :: 16
PLAYER_SPEED :: 2
MAX_NUM_BODY :: 20
MAX_NUM_MOVERS :: 100
MAX_NUM_CANDIES :: 8
CANDY_SIZE :: 8
CANDY_RESPAWN_TIME :: 20


MAX_NUM_ENEMIES :: 4
ENEMY_RESPAWN_TIME :: 100
ENEMY_SPEED :: 1

EPSILON :: 0.5


BULLET_SPEED :: 4
BULLET_SIZE :: 16

tileset: rl.Texture2D

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "snake_invaders")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	tileset = rl.LoadTexture("./assets/tileset.png")
	defer rl.UnloadTexture(tileset)

	game := Game {
		player = &Player{ghost_pieces = &Ringuffer_t{}, body = [MAX_NUM_BODY]cell_t{}},
		scene  = &scene_t{},
	}

	load_scene(&game, .ONE)
	fmt.println("HERE WE GO1")
	fmt.println(game)

	for !rl.WindowShouldClose() {
		if game.candy_respawn_time >= CANDY_RESPAWN_TIME {
			game.candy_respawn_time = 0
			if game.scene.count_candies < MAX_NUM_CANDIES {
				spawn_candy(&game)
			}
		}

		if game.enemy_respawn_time >= ENEMY_RESPAWN_TIME {
			game.enemy_respawn_time = 0
			if game.scene.count_enemies < MAX_NUM_ENEMIES {
				spawn_enemy(&game)
			}
		}

		update(&game)

		rl.BeginDrawing()
		rl.ClearBackground(rl.BLACK)
		draw_grid({100, 100, 100, 255})

		draw_scene(&game)
		draw_player(game.player)
		draw_ghost_cells(game.player.ghost_pieces)

		rl.EndDrawing()

		game.enemy_respawn_time += 1
		game.candy_respawn_time += 1
	}
}

////////////
// UPDATE //
////////////
update :: proc(game: ^Game) {
	get_input(game)
	check_collision(game)

	game.scene.count_entities = clear_dead_entities(
		&game.scene.entities,
		game.scene.count_entities,
	)

	update_player(game.player)
	update_scene(game)

	TESTING(game)
}

get_input :: proc(game: ^Game) {
	player := game.player
	if (rl.IsKeyPressed(.H) || rl.IsKeyPressed(.LEFT)) {
		player.next_dir = {-1, 0}
	}
	if (rl.IsKeyPressed(.L) || rl.IsKeyPressed(.RIGHT)) {
		player.next_dir = {1, 0}
	}
	if (rl.IsKeyPressed(.J) || rl.IsKeyPressed(.DOWN)) {
		player.next_dir = {0, 1}
	}
	if (rl.IsKeyPressed(.K) || rl.IsKeyPressed(.UP)) {
		player.next_dir = {0, -1}
	}
	if rl.IsKeyPressed(.T) {
		spawn_enemy(game)
	}


	if rl.IsKeyDown(.SPACE) && player.num_cells > 0 && player.next_bullet_size <= 3 {
		fmt.println("SPACING")
		last_cell := &game.player.body[game.player.num_cells - 1]
		last_cell.size = math.lerp(last_cell.size, f32(0.0), f32(0.05))

		if last_cell.size < f32(EPSILON) {
			last_ghost, ok := peek_cell(game.player.ghost_pieces)

			if ok &&
			   last_cell.count_turns_left <= 1 &&
			   vec2_distance(last_cell.position, last_ghost.position) < PLAYER_SIZE {
				pop_cell(game.player.ghost_pieces)
			}

			player.next_bullet_size += 1
			game.player.num_cells -= 1

			fmt.println("INCREASE BULLET SIZE TO: ", player.next_bullet_size)
		}
	} else if player.num_cells > 0 {
		last_cell := &game.player.body[game.player.num_cells - 1]
		if PLAYER_SIZE - last_cell.size > EPSILON {
			last_cell.size = math.lerp(last_cell.size, f32(PLAYER_SIZE), f32(0.09))
		} else {
			last_cell.size = PLAYER_SIZE
		}
	}
	if (rl.IsKeyReleased(.SPACE)) && player.next_bullet_size > 0 {
		spawn_bullet(game)
		player.next_bullet_size = 0
	}


}

try_set_dir :: proc(player: ^Player) -> bool {
	prev_dir := player.head.direction
	next_dir := player.next_dir
	if !oposite_directions(next_dir, prev_dir) && next_dir != prev_dir {
		player.head.direction = next_dir
		return true
	}
	return false
}

update_scene :: proc(game: ^Game) {
	for i in 0 ..< game.scene.count_entities {
		entity := &game.scene.entities[i]
		switch entity.kind {
		case .BULLET:
			entity.position.x += (entity.speed * entity.direction.x)
			entity.position.y += (entity.speed * entity.direction.y)
		case .CANDY:
		case .STATIC:
		case .ENEMY:
			to_player: vec2_t = {
				game.player.head.position.x - entity.position.x,
				game.player.head.position.y - entity.position.y,
			}
			distance := magnitude(to_player)

			if distance > 0 {
				desired_dir: vec2_t = {to_player.x / distance, to_player.y / distance}

				smoothing := 0.1
				entity.direction.x = math.lerp(entity.direction.x, desired_dir.x, f32(smoothing))
				entity.direction.y = math.lerp(entity.direction.y, desired_dir.y, f32(smoothing))

				entity.position.x += entity.direction.x * entity.speed
				entity.position.y += entity.direction.y * entity.speed
			}
		}
	}

}

update_player :: proc(player: ^Player) {
	if aligned_to_grid(player.head.position) {
		if try_set_dir(player) && player.num_cells > 0 && player.head.direction != {0, 0} {
			put_cell(
				player.ghost_pieces,
				cell_ghost_t{player.head.position, player.head.direction},
			)
			add_turn_count(player)
		}
	}

	player.head.position.x += player.head.direction.x * PLAYER_SPEED
	player.head.position.y += player.head.direction.y * PLAYER_SPEED

	if player.head.direction != {0, 0} && !player.growing {
		for i in 0 ..< player.num_cells {
			piece_to_follow: cell_t
			if (player.body[i].count_turns_left == 0) {
				piece_to_follow = (i == 0) ? player.head : player.body[i - 1]
				player.body[i].direction = piece_to_follow.direction
			} else {
				index :=
					(MAX_RINGBUFFER_VALUES +
						player.ghost_pieces.tail -
						player.body[i].count_turns_left) %
					MAX_RINGBUFFER_VALUES

				following_ghost_piece := ghost_to_cell(player.ghost_pieces.values[index])

				if (player.body[i].position == following_ghost_piece.position) {
					player.body[i].direction = following_ghost_piece.direction
					player.body[i].count_turns_left -= 1
				} else {
					direction_to_ghost := get_cardinal_direction(
						player.body[i].position,
						following_ghost_piece.position,
					)
					player.body[i].direction = direction_to_ghost
				}


				if (i == player.num_cells - 1) {
					dealing_ghost_piece(player, i)
				}

			}
			player.body[i].position.x += player.body[i].direction.x * PLAYER_SPEED
			player.body[i].position.y += player.body[i].direction.y * PLAYER_SPEED

		}
	}

	if player.num_cells > 0 && player.growing {
		distance: f32
		if player.body[0].count_turns_left > 0 {
			ghost_cell, _ := peek_tail(player.ghost_pieces)
			distance += vec2_distance(player.body[0].position, ghost_cell.position)
			distance += vec2_distance(player.head.position, ghost_cell.position)
		} else {
			distance = vec2_distance(player.head.position, player.body[0].position)
		}

		if distance >= PLAYER_SIZE {player.growing = false}
	}
}

clear_dead_entities :: proc(entities: ^[]Entity, count_entities: int) -> int {
	alive_count := 0

	for i in 0 ..< count_entities {
		if entities^[i].state == .ALIVE {
			if i != alive_count {
				entities^[alive_count], entities^[i] = entities^[i], entities^[alive_count]
			}
			alive_count += 1
		}
	}
	return alive_count
}

// grow_body :: proc(player: ^Player) {
// 	if player.num_cells < MAX_NUM_BODY {
// 		direction: vec2_t
// 		new_x, new_y: f32
// 		size: f32
//
// 		if player.num_cells == 0 {
// 			direction = player.head.direction
// 			new_x = player.head.position.x - direction.x * PLAYER_SIZE
// 			new_y = player.head.position.y - direction.y * PLAYER_SIZE
// 		} else {
// 			last := &player.body[player.num_cells - 1]
// 			direction = last.direction
// 			new_x = last.position.x - direction.x * PLAYER_SIZE
// 			new_y = last.position.y - direction.y * PLAYER_SIZE
// 		}
// 		num_ghost_pieces := player.ghost_pieces.count
//
// 		new_cell := cell_t{{new_x, new_y}, direction, num_ghost_pieces, size, .GROW}
// 		shift_array_right(&player.body, int(player.num_cells))
// 		player.body[0] = new_cell
// 		player.num_cells += 1
// 		fmt.println("WE ARE GROWING NUM CELLS: ", player.num_cells)
// 	} else {
// 		fmt.println("WE DO NOT GROW!")
// 	}
// }

grow_body :: proc(player: ^Player) {
	if player.num_cells < MAX_NUM_BODY {
		player.growing = true
		player.num_cells += 1
		if player.num_cells > 0 {
			shift_array_right(&player.body, int(player.num_cells))
		}

		new_cell := cell_t {
			{player.head.position.x, player.head.position.y},
			{player.head.direction.x, player.head.direction.y},
			0,
			PLAYER_SIZE,
			.NORMAL,
		}

		player.body[0] = new_cell
		fmt.println("WE ARE GROWING NUM CELLS: ", player.num_cells)
	} else {
		fmt.println("WE DO NOT GROW!")
	}
}


dealing_ghost_piece :: proc(player: ^Player, last_piece: i8) {
	ghost_piece, ok := peek_cell(player.ghost_pieces)
	if !ok {
		return
	}

	is_colliding := rec_colliding(
		player.body[last_piece].position,
		PLAYER_SIZE,
		PLAYER_SIZE,
		ghost_piece.position,
		PLAYER_SIZE,
		PLAYER_SIZE,
	)

	if (is_colliding && player.body[last_piece].direction == ghost_piece.direction) {
		pop_cell(player.ghost_pieces)
	}
}

spawn_enemy :: proc(game: ^Game) {
	enemy := new(Entity)

	random_index := rand.int31_max(i32(game.scene.count_spawners))
	spawn_area := game.scene.spawn_areas[random_index]

	// TODO: PUT CHECKERS FOR SPAWN_AREA UNION 
	x_position :=
		math.floor(
			(spawn_area.position.x + rand.float32() * spawn_area.shape.(Rect).w) / PLAYER_SIZE,
		) *
		PLAYER_SIZE
	y_position :=
		math.floor(
			(spawn_area.position.y + rand.float32() * spawn_area.shape.(Rect).h) / PLAYER_SIZE,
		) *
		PLAYER_SIZE

	enemy.kind = .ENEMY
	enemy.state = .ALIVE
	enemy.position = {x_position + PLAYER_SIZE / 2, y_position + PLAYER_SIZE / 2}
	enemy.shape = Circle {
		r = PLAYER_SIZE / 2,
	}

	enemy.speed = ENEMY_SPEED

	game.scene.entities[game.scene.count_entities] = enemy^
	game.scene.count_entities += 1
	game.scene.count_enemies += 1
}

spawn_bullet :: proc(game: ^Game) {
	head := game.player.head

	bullet := new(Entity)
	bullet.position = {head.position.x + PLAYER_SIZE / 2, head.position.y + PLAYER_SIZE / 2}
	bullet.shape = Circle {
		r = PLAYER_SIZE * (game.player.next_bullet_size / 2),
	}

	bullet.direction = head.direction
	bullet.kind = .BULLET
	bullet.speed = BULLET_SPEED
	bullet.state = .ALIVE

	game.scene.entities[game.scene.count_entities] = bullet^
	game.scene.count_entities += 1
	game.scene.count_bullets += 1


	//TODO: CHECK FOR GHOST PIECES WITH NO PARENTS 
}

spawn_candy :: proc(game: ^Game) {
	candy := new(Entity)
	x_position := f32((int(rand.float32() * SCREEN_WIDTH) % PLAYER_SIZE) * PLAYER_SIZE * 2)
	y_position := f32((int(rand.float32() * SCREEN_HEIGHT) % PLAYER_SIZE) * PLAYER_SIZE * 2)
	x_position += PLAYER_SIZE / 2
	y_position += PLAYER_SIZE / 2

	candy.position.x = clamp(x_position, PLAYER_SIZE * 2.5, SCREEN_WIDTH - PLAYER_SIZE * 2.5)
	candy.position.y = clamp(y_position, PLAYER_SIZE * 2.5, SCREEN_HEIGHT - PLAYER_SIZE * 2.5)
	candy.kind = .CANDY
	candy.state = .ALIVE
	candy.shape = Circle {
		r = CANDY_SIZE,
	}

	game.scene.entities[game.scene.count_entities] = candy^
	game.scene.count_entities += 1
	game.scene.count_candies += 1
}

////////////
// RENDER //
////////////
draw_scene :: proc(game: ^Game) {
	for i in 0 ..< game.scene.count_scenario {
		rectangle := game.scene.scenario[i]
		rec := rl.Rectangle {
			rectangle.position.x,
			rectangle.position.y,
			rectangle.shape.(Rect).w,
			rectangle.shape.(Rect).h,
		}
		rl.DrawRectangleRec(rec, rl.YELLOW)
	}
	for i in 0 ..< game.scene.count_spawners {
		rectangle := game.scene.spawn_areas[i]
		rec := rl.Rectangle {
			rectangle.position.x,
			rectangle.position.y,
			rectangle.shape.(Rect).w,
			rectangle.shape.(Rect).h,
		}
		rl.DrawRectangleRec(rec, rl.PINK)
	}

	for i in 0 ..< game.scene.count_entities {
		entity := game.scene.entities[i]
		color: rl.Color
		switch entity.kind {
		case .STATIC:
			color = rl.YELLOW
		case .CANDY:
			color = rl.WHITE
		case .BULLET:
			color = rl.BLUE
		case .ENEMY:
			color = rl.RED
		}

		switch s in entity.shape {
		case Circle:
			r := entity.shape.(Circle).r
			rl.DrawCircle(i32(entity.position.x), i32(entity.position.y), r, color)
		case Square:
			w := entity.shape.(Square).w
			rec := rl.Rectangle{entity.position.x, entity.position.y, w, w}
			rl.DrawRectangleRec(rec, color)
		case Rect:
			w := entity.shape.(Rect).w
			h := entity.shape.(Rect).h
			rec := rl.Rectangle{entity.position.x, entity.position.y, w, h}
			rl.DrawRectangleRec(rec, color)
		}

	}
}

draw_player :: proc(player: ^Player) {
	for i in 0 ..< player.num_cells {
		cell := player.body[i]

		x_size := cell.direction.x != 0 ? cell.size : PLAYER_SIZE
		y_size := cell.direction.y != 0 ? cell.size : PLAYER_SIZE
		x_position: f32
		y_position: f32
		switch cell.direction {
		case {0, 1}:
			x_position = cell.position.x
			y_position = cell.position.y + PLAYER_SIZE - cell.size
		case {0, -1}:
			x_position = cell.position.x
			y_position = cell.position.y
		case {1, 0}:
			x_position = cell.position.x + PLAYER_SIZE - cell.size
			y_position = cell.position.y
		case {-1, 0}:
			x_position = cell.position.x
			y_position = cell.position.y
		}

		rl.DrawRectangle(
			i32(math.round(x_position)),
			i32(math.round(y_position)),
			i32(math.round(x_size)),
			i32(math.round(y_size)),
			rl.ORANGE,
		)
	}

	src_rec := rl.Rectangle{0, 32, PLAYER_SIZE, PLAYER_SIZE}
	switch player.head.direction {
	case {0, 1}:
		player.rotation = 270
	case {0, -1}:
		player.rotation = 90
	case {1, 0}:
		player.rotation = 180
	case {-1, 0}:
		player.rotation = 0
	}

	dst_rec := rl.Rectangle {
		player.head.position.x + PLAYER_SIZE / 2,
		player.head.position.y + PLAYER_SIZE / 2,
		PLAYER_SIZE,
		PLAYER_SIZE,
	}
	origin := rl.Vector2{PLAYER_SIZE / 2, PLAYER_SIZE / 2}
	rl.DrawTexturePro(tileset, src_rec, dst_rec, origin, player.rotation, rl.WHITE)


}

draw_ghost_cells :: proc(rb: ^Ringuffer_t) {
	for i in 0 ..< rb.count {
		current := rb.head + i
		if current >= MAX_RINGBUFFER_VALUES {
			current = current % MAX_RINGBUFFER_VALUES
		}
		cell := rb.values[current]
		rl.DrawRectangle(
			i32(cell.position.x),
			i32(cell.position.y),
			PLAYER_SIZE,
			PLAYER_SIZE,
			rl.PINK,
		)
	}
}

draw_grid :: proc(col: rl.Color) {
	for i: i32 = 0; i < SCREEN_WIDTH; i += PLAYER_SIZE {
		rl.DrawLine(i, 0, i, SCREEN_HEIGHT, col)
		rl.DrawLine(0, i, SCREEN_WIDTH, i, col)
	}
}

/////////////
// COLLIDE //
/////////////
check_collision :: proc(game: ^Game) {
	player := game.player
	future_pos := vec2_add(player.head.position, vec2_mul_scalar(player.next_dir, PLAYER_SPEED))

	count_candies := game.scene.count_candies

	center_player := player.head.position
	center_player.x += PLAYER_SIZE / 2
	center_player.y += PLAYER_SIZE / 2

	for i in 0 ..< game.scene.count_entities {
		entity := &game.scene.entities[i]
		switch entity.kind {
		case .CANDY:
			if vec2_distance(center_player, entity.position) + 4 < PLAYER_SIZE &&
			   entity.state != .DEAD {
				game.scene.entities[i].state = .DEAD
				game.scene.count_candies -= 1
				fmt.println("BEFORE EATING CANDY WE GOT: ", game.player.num_cells)
				grow_body(game.player)
			}

		case .BULLET:
			for j in 0 ..< game.scene.count_entities {
				if game.scene.entities[j].kind == .ENEMY {
					bullet := &game.scene.entities[i]
					bullet_size := bullet.shape.(Circle).r
					enemy := &game.scene.entities[j]
					enemy_size := enemy.shape.(Circle).r
					if circle_colliding(bullet.position, enemy.position, bullet_size, enemy_size) {
						bullet.state = .DEAD
						enemy.state = .DEAD
						game.scene.count_enemies -= 1
						game.scene.count_bullets -= 1
					}
				}
			}
		case .STATIC:
		case .ENEMY:
			if vec2_distance(center_player, entity.position) < PLAYER_SIZE &&
			   entity.state != .DEAD {
				rl.CloseWindow()
			}

		}
	}

	for i in 0 ..< game.scene.count_scenario {
		rectangle := game.scene.scenario[i]

		if rec_colliding_no_edges(
			rectangle.position,
			rectangle.shape.(Rect).w,
			rectangle.shape.(Rect).h,
			future_pos,
			PLAYER_SIZE,
			PLAYER_SIZE,
		) {
			fmt.println("WE COLLIDE")
			player.next_dir = {0, 0}
		}
	}
}

aligned_to_grid :: proc(p: vec2_t) -> bool {
	return i32(p.x) % PLAYER_SIZE == 0 && i32(p.y) % PLAYER_SIZE == 0
}

circle_colliding :: proc(v0, v1: vec2_t, d0, d1: f32) -> bool {
	return vec2_distance(v0, v1) < d0 + d1
}

rec_colliding :: proc(v0: vec2_t, w0: f32, h0: f32, v1: vec2_t, w1: f32, h1: f32) -> bool {
	horizontal_in :=
		(v0.x <= v1.x && v0.x + w0 >= v1.x) || (v0.x <= v1.x + w1 && v0.x + w0 >= v1.x + w1)
	vertical_in :=
		(v0.y <= v1.y && v0.y + h0 >= v1.y) || (v0.y <= v1.y + h1 && v0.y + h0 >= v1.y + h1)
	return horizontal_in && vertical_in
}

rec_colliding_no_edges :: proc(
	v0: vec2_t,
	w0: f32,
	h0: f32,
	v1: vec2_t,
	w1: f32,
	h1: f32,
) -> bool {
	horizontal_in :=
		(v0.x < v1.x && v0.x + w0 > v1.x) || (v0.x < v1.x + w1 && v0.x + w0 > v1.x + w1)
	vertical_in := (v0.y < v1.y && v0.y + h0 > v1.y) || (v0.y < v1.y + h1 && v0.y + h0 > v1.y + h1)
	return horizontal_in && vertical_in
}


aligned :: proc(v0: vec2_t, v1: vec2_t) -> bool {
	return v0.x == v1.x || v0.y == v1.y
}


////////////
// OTHERS //
////////////
add_turn_count :: proc(player: ^Player) {
	for i in 0 ..< player.num_cells {
		player.body[i].count_turns_left += 1
	}
}

ghost_to_cell :: proc(cell: cell_ghost_t) -> cell_t {
	return cell_t{position = cell.position, direction = cell.direction}
}

vec2_distance :: proc(a, b: vec2_t) -> f32 {
	return math.sqrt(math.pow(b.x - a.x, 2.0) + math.pow(b.y - a.y, 2.0))
}


get_cardinal_direction :: proc(from, to: vec2_t) -> vec2_t {
	dx := to.x - from.x
	dy := to.y - from.y
	if (abs(dx) > abs(dy)) {
		return (dx > 0) ? vec2_t{1, 0} : vec2_t{-1, 0}
	} else {
		return (dy > 0) ? vec2_t{0, 1} : vec2_t{0, -1}
	}
}

get_ghost_piece_index :: proc(turns_left, tail: i8) -> i8 {
	index := (MAX_RINGBUFFER_VALUES + tail - turns_left) % MAX_RINGBUFFER_VALUES
	return index
}


TESTING :: proc(game: ^Game) {
	for i in 1 ..< game.player.num_cells {
		prev_cell := game.player.body[i - 1]
		next_cell := game.player.body[i]

		if !rec_colliding(
			prev_cell.position,
			PLAYER_SIZE,
			PLAYER_SIZE,
			next_cell.position,
			PLAYER_SIZE,
			PLAYER_SIZE,
		) {
			fmt.printf(
				"LENGTH BODY %d, PREV_CELL IDX %d, NEXT_CELL IDX %d",
				game.player.num_cells,
				i - 1,
				i,
			)
			fmt.println("PREV_CELL POS AND DIR", prev_cell.position, prev_cell.direction)
			fmt.println("NEXT_CELL POS AND DIR", next_cell.position, next_cell.direction)
		}

		index :=
			(MAX_RINGBUFFER_VALUES + game.player.ghost_pieces.tail - next_cell.count_turns_left) %
			MAX_RINGBUFFER_VALUES

		following_ghost_piece := ghost_to_cell(game.player.ghost_pieces.values[index])
		if !aligned(next_cell.position, following_ghost_piece.position) &&
		   next_cell.count_turns_left != 0 &&
		   following_ghost_piece.position != {0, 0} {

			fmt.println()
			fmt.println()
			fmt.println(
				"GHOST POS AND DIR",
				following_ghost_piece.position,
				following_ghost_piece.direction,
			)
			fmt.println("NEXT_CELL POS AND DIR", next_cell.position, next_cell.direction)
		}

	}
}

vec2_add :: proc(v0, v1: vec2_t) -> vec2_t {
	return {v0.x + v1.x, v0.y + v1.y}

}
vec2_mul_scalar :: proc(v: vec2_t, scalar: f32) -> vec2_t {
	return {v.x * scalar, v.y * scalar}
}

sign :: proc(x: f32) -> f32 {
	return (x > 0) ? 1 : (x < 0) ? -1 : 0
}

magnitude :: proc(v: vec2_t) -> f32 {
	return math.sqrt(v.x * v.x + v.y * v.y)
}

shift_array_right :: proc(arr: ^[20]cell_t, count: int) {
	for i := count - 1; i > 0; i -= 1 {
		arr[i] = arr[i - 1]
	}
}

oposite_directions :: proc(new, curr: vec2_t) -> bool {
	return new.x == -curr.x && new.y == -curr.y
}
