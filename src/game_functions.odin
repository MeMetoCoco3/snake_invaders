package main
import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

///////////
// INPUT //
///////////
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


	if rl.IsKeyPressed(.P) {
		rl.PauseAudioStream(game.audio.bg_music)
		game.state = .PAUSE
	}

	if player.can_dash && rl.IsKeyPressed(.X) {
		player.speed = PLAYER_SPEED * 2
		player.can_dash = false
		player.time_on_dash = 0
		player.state = .DASH
	}

	if rl.IsKeyDown(.Z) && player.num_cells > 0 && player.next_bullet_size <= 3 {
		last_cell := &game.player.body[game.player.num_cells - 1]
		last_cell.size = math.lerp(last_cell.size, f32(0.0), f32(SMOOTHING / 2))

		if last_cell.size < f32(EPSILON) {
			last_ghost, ok := peek_cell(game.player.ghost_pieces)

			if ok &&
			   last_cell.count_turns_left <= 1 &&
			   vec2_distance(last_cell.position, last_ghost.position) < PLAYER_SIZE {
				pop_cell(game.player.ghost_pieces)
			}

			player.next_bullet_size += 1
			game.player.num_cells -= 1

		}
	} else if player.num_cells > 0 {
		last_cell := &game.player.body[game.player.num_cells - 1]
		if PLAYER_SIZE - last_cell.size > EPSILON {
			last_cell.size = math.lerp(last_cell.size, f32(PLAYER_SIZE), f32(SMOOTHING / 2))
		} else {
			last_cell.size = PLAYER_SIZE
		}
	}
	if (rl.IsKeyReleased(.Z)) && player.next_bullet_size > 0 {
		add_sound(game, &sound_bank[FX.FX_SHOOT])
		spawn_bullet(game)
		player.next_bullet_size = 0
	}
}

get_input_pause :: proc(game: ^Game) {
	if (rl.IsKeyPressed(.ENTER)) {
		fmt.println(game.player)
		if game.state == .DEAD {
			load_scene(game, game.current_scene)

			fmt.println()
			fmt.println(game.player)

			fmt.println("MUSIC RESUMED")
		}
		game.state = .PLAY
		rl.ResumeMusicStream(game.audio.bg_music)

	}
	if (rl.IsKeyPressed(.Q)) {
		game.state = .QUIT
	}
}


////////////
// UPDATE //
////////////
update :: proc(game: ^Game) {
	check_collision(game)

	game.scene.count_entities = clear_dead_entities(
		&game.scene.entities,
		game.scene.count_entities,
	)

	update_player(game.player)
	update_scene(game)

	play_sound(game)

	game.enemy_respawn_time += 1
	game.candy_respawn_time += 1
	TESTING(game)
}


update_scene :: proc(game: ^Game) {
	player := game.player

	if !player.can_dash {
		player.time_on_dash += 1
	}

	if player.time_on_dash >= DASH_DURATION {
		player.speed = PLAYER_SPEED
		player.state = .NORMAL
		if player.time_on_dash >= RECOVER_DASH_TIME {
			player.can_dash = true
		}
	}


	if game.candy_respawn_time >= CANDY_RESPAWN_TIME {
		game.candy_respawn_time = 0
		if game.scene.count_candies < MAX_NUM_CANDIES {
			spawn_candy(game)
		}
	}

	if game.enemy_respawn_time >= ENEMY_RESPAWN_TIME {
		game.enemy_respawn_time = 0
		if game.scene.count_enemies < MAX_NUM_ENEMIES {
			spawn_enemy(game)
		}
	}


	for i in 0 ..< game.scene.count_entities {
		entity := &game.scene.entities[i]
		switch entity.kind {
		case .BULLET:
			entity.position += (entity.speed * entity.direction)
		case .CANDY:
		case .STATIC:
		case .ENEMY:
			to_player := game.player.head.position - entity.position
			distance := magnitude(to_player)

			if distance > 0 {
				desired_dir := to_player / distance
				entity.direction = math.lerp(entity.direction, desired_dir, f32(SMOOTHING))

				entity.position += entity.direction * entity.speed
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

	player.head.position += player.head.direction * f32(player.speed)

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
			player.body[i].position += player.body[i].direction * f32(player.speed)
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

grow_body :: proc(player: ^Player) {
	if player.num_cells < MAX_NUM_BODY {
		player.growing = true
		player.num_cells += 1
		if player.num_cells > 0 {
			shift_array_right(&player.body, int(player.num_cells))
		}

		new_cell := cell_t{player.head.position, player.head.direction, 0, PLAYER_SIZE}

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

///////////
// SPAWN //
///////////
spawn_enemy :: proc(game: ^Game) {
	enemy: Entity

	random_index := rand.int_max(game.scene.count_spawners)
	fmt.println(random_index)
	fmt.println(game.scene.count_spawners)

	spawn_area := game.scene.spawn_areas[random_index]
	rect := spawn_area.shape.(Rect)

	x := spawn_area.position.x + rand.float32() * rect.w
	y := spawn_area.position.y + rand.float32() * rect.h

	x = math.floor(x / PLAYER_SIZE) * PLAYER_SIZE
	y = math.floor(y / PLAYER_SIZE) * PLAYER_SIZE

	enemy.position = Vector2{x, y}
	enemy.kind = .ENEMY
	enemy.state = .ALIVE
	enemy.shape = Circle {
		r = PLAYER_SIZE * 2,
	}

	enemy.speed = ENEMY_SPEED

	enemy.animation = {
		image       = &texture_bank[TEXTURE.TX_ENEMY],
		w           = 32,
		h           = 32,
		frame_delay = 6,
		num_frames  = 4,
		kind        = .REPEAT,
		angle_type  = .LR,
	}


	game.scene.entities[game.scene.count_entities] = enemy
	game.scene.count_entities += 1
	game.scene.count_enemies += 1
}

spawn_bullet :: proc(game: ^Game) {
	bullet: Entity

	head := game.player.head

	bullet.position = {head.position.x + PLAYER_SIZE / 2, head.position.y + PLAYER_SIZE / 2}
	bullet.shape = Circle {
		r = PLAYER_SIZE * (game.player.next_bullet_size),
	}

	bullet.direction = head.direction
	bullet.kind = .BULLET
	bullet.speed = BULLET_SPEED
	bullet.state = .ALIVE

	bullet.animation = {
		image       = &texture_bank[TEXTURE.TX_BULLET],
		w           = 16,
		h           = 16,
		num_frames  = 4,
		frame_delay = 6,
		kind        = .REPEAT,
		angle_type  = .DIRECTIONAL,
	}

	game.scene.entities[game.scene.count_entities] = bullet
	game.scene.count_entities += 1
	game.scene.count_bullets += 1

}

spawn_candy :: proc(game: ^Game) {
	candy: Entity

	pos_x := rand.int_max((SCREEN_WIDTH / (PLAYER_SIZE * 2)) - 1)
	pos_y := rand.int_max((SCREEN_HEIGHT / (PLAYER_SIZE * 2)) - 1)

	candy.position.x = clamp(
		f32(pos_x * PLAYER_SIZE * 2 + PLAYER_SIZE / 2),
		PLAYER_SIZE * 2.5,
		SCREEN_WIDTH - PLAYER_SIZE * 2.5,
	)

	candy.position.y = clamp(
		f32(pos_y * PLAYER_SIZE * 2 + PLAYER_SIZE / 2),
		PLAYER_SIZE * 2.5,
		SCREEN_HEIGHT - PLAYER_SIZE * 2.5,
	)


	candy.kind = .CANDY
	candy.state = .ALIVE
	candy.shape = Circle {
		r = CANDY_SIZE,
	}

	candy.animation = animation_t {
		image       = &texture_bank[TEXTURE.TX_CANDY],
		w           = 16,
		h           = 16,
		num_frames  = 16,
		frame_delay = 4,
		kind        = .REPEAT,
		angle_type  = .IGNORE,
	}

	game.scene.entities[game.scene.count_entities] = candy
	game.scene.count_entities += 1
	game.scene.count_candies += 1
}

////////////
// RENDER //
////////////
draw_game :: proc(game: ^Game) {
	draw_grid({100, 100, 100, 255})
	draw_scene(game)
	draw_player(game.player)
	draw_ghost_cells(game.player.ghost_pieces)
}

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
		entity := &game.scene.entities[i]
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
			rl.DrawCircle(i32(entity.position.x), i32(entity.position.y), s.r / 2, color)
			draw(entity)
		case Square:
			rec := rl.Rectangle{entity.position.x, entity.position.y, s.w, s.w}
			rl.DrawRectangleRec(rec, color)
			draw(entity)
		case Rect:
			rec := rl.Rectangle{entity.position.x, entity.position.y, s.w, s.h}
			rl.DrawRectangleRec(rec, color)
			draw(entity)
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

	draw(player)
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

/////////////
// COLLIDE //
/////////////
check_collision :: proc(game: ^Game) {
	player := game.player
	future_pos := vec2_add(
		player.head.position,
		vec2_mul_scalar(player.next_dir, f32(player.speed)),
	)

	count_candies := game.scene.count_candies

	center_player := player.head.position
	center_player += PLAYER_SIZE / 2

	for i in 0 ..< game.scene.count_entities {
		entity := &game.scene.entities[i]
		switch entity.kind {
		case .CANDY:
			if vec2_distance(center_player, entity.position) + 4 < PLAYER_SIZE &&
			   entity.state != .DEAD {
				game.scene.entities[i].state = .DEAD
				game.scene.count_candies -= 1

				add_sound(game, &sound_bank[FX.FX_EAT])
				grow_body(game.player)
			}

		case .BULLET:
			for j in 0 ..< game.scene.count_entities {
				if game.scene.entities[j].kind == .ENEMY {
					bullet := &game.scene.entities[i]
					bullet_size := bullet.shape.(Circle).r

					enemy := &game.scene.entities[j]
					enemy_size := enemy.shape.(Circle).r

					if circle_colliding(
						bullet.position,
						enemy.position,
						bullet_size,
						enemy_size - ENEMY_COLLIDER_THRESHOLD,
					) {
						bullet.state = .DEAD
						enemy.state = .DEAD
						game.scene.count_enemies -= 1
						game.scene.count_bullets -= 1
					}
				}
			}
		case .STATIC:
		case .ENEMY:
			if vec2_distance(center_player, entity.position) <
				   PLAYER_SIZE - ENEMY_COLLIDER_THRESHOLD &&
			   entity.state != .DEAD {
				switch player.state {
				case .NORMAL:
					game.state = .DEAD
				case .DASH:
					game.scene.entities[i].state = .DEAD

					add_sound(game, &sound_bank[FX.FX_EAT])
					grow_body(game.player)
					game.scene.count_enemies -= 1
				}

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

aligned_to_grid :: proc(p: Vector2) -> bool {
	return i32(p.x) % PLAYER_SIZE == 0 && i32(p.y) % PLAYER_SIZE == 0
}

circle_colliding :: proc(v0, v1: Vector2, d0, d1: f32) -> bool {
	return vec2_distance(v0, v1) < d0 + d1
}

rec_colliding :: proc(v0: Vector2, w0: f32, h0: f32, v1: Vector2, w1: f32, h1: f32) -> bool {
	horizontal_in :=
		(v0.x <= v1.x && v0.x + w0 >= v1.x) || (v0.x <= v1.x + w1 && v0.x + w0 >= v1.x + w1)
	vertical_in :=
		(v0.y <= v1.y && v0.y + h0 >= v1.y) || (v0.y <= v1.y + h1 && v0.y + h0 >= v1.y + h1)
	return horizontal_in && vertical_in
}

rec_colliding_no_edges :: proc(
	v0: Vector2,
	w0: f32,
	h0: f32,
	v1: Vector2,
	w1: f32,
	h1: f32,
) -> bool {
	horizontal_in :=
		(v0.x < v1.x && v0.x + w0 > v1.x) || (v0.x < v1.x + w1 && v0.x + w0 > v1.x + w1)
	vertical_in := (v0.y < v1.y && v0.y + h0 > v1.y) || (v0.y < v1.y + h1 && v0.y + h0 > v1.y + h1)
	return horizontal_in && vertical_in
}
