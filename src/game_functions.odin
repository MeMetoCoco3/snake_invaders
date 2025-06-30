package main
import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

///////////
// INPUT //
///////////
InputSystem :: proc(game: ^Game) {
	player_velocity := &game.world.archetypes[player_mask].velocities[0]
	player_data := &game.world.archetypes[player_mask].players_data[0]
	player_position := &game.world.archetypes[player_mask].positions[0]

	if (rl.IsKeyDown(.H) || rl.IsKeyDown(.LEFT)) {
		player_data.next_dir = {-1, 0}
	} else if (rl.IsKeyDown(.L) || rl.IsKeyDown(.RIGHT)) {
		player_data.next_dir = {1, 0}
	} else if (rl.IsKeyDown(.J) || rl.IsKeyDown(.DOWN)) {
		player_data.next_dir = {0, 1}
	} else if (rl.IsKeyDown(.K) || rl.IsKeyDown(.UP)) {
		player_data.next_dir = {0, -1}
	}


	if rl.IsKeyPressed(.P) {
		rl.PauseAudioStream(game.audio.bg_music)
		game.state = .PAUSE
	}

	if player_data.can_dash && rl.IsKeyPressed(.X) || player_data.gona_dash {
		player_data.gona_dash = true


		if aligned_to_grid(player_position.pos) {
			player_velocity.speed = PLAYER_SPEED * 2
			player_data.can_dash = false
			player_data.time_on_dash = 0
			player_data.player_state = .DASH
			player_data.gona_dash = false
		}
	}

	body := &game.player_body

	if rl.IsKeyDown(.Z) && body.num_cells > 0 && player_data.next_bullet_size <= 3 {
		last_cell := &body.cells[body.num_cells - 1]
		last_cell.size = math.lerp(last_cell.size, f32(0.0), f32(SMOOTHING / 2))

		if last_cell.size < f32(EPSILON) {
			last_ghost, ok := peek_head(body.ghost_pieces)

			if ok &&
			   last_cell.count_turns_left <= 1 &&
			   vec2_distance(last_cell.position, last_ghost.position) < PLAYER_SIZE {
				pop_cell(body.ghost_pieces)
			}

			player_data.next_bullet_size += 1
			body.num_cells -= 1
		}
	} else if body.num_cells > 0 {
		last_cell := &body.cells[body.num_cells - 1]
		if PLAYER_SIZE - last_cell.size > EPSILON {
			last_cell.size = math.lerp(last_cell.size, f32(PLAYER_SIZE), f32(SMOOTHING / 2))
		} else {
			last_cell.size = PLAYER_SIZE
		}
	}
	if (rl.IsKeyReleased(.Z)) && player_data.next_bullet_size > 0 {
		add_sound(game, &sound_bank[FX.FX_SHOOT])
		// THIS ORIGIN MARKS THE VERTEZ SO I SHOULD TAKEON ACCOUT ALSO THE SIZE OF THE BULLET
		origin := player_position.pos + player_position.size / 2


		speed := max(player_velocity.speed * 1.5, BULLET_SPEED)

		direction := player_velocity.direction
		if direction == {0, 0} {
			direction = player_data.previous_dir
		}

		fmt.println("SPEED HERE: ", speed)
		fmt.println("DIR HERE", direction)
		spawn_bullet(
			game,
			origin,
			PLAYER_SIZE * player_data.next_bullet_size,
			speed,
			direction,
			.GOOD,
		)

		player_data.next_bullet_size = 0
	}
}

get_input_pause :: proc(game: ^Game) {
	if (rl.IsKeyPressed(.ENTER)) {
		if game.state == .DEAD {
			load_scene(game, game.current_scene)
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
	play_sound(game)
	update_scene(game)
	// TESTING(game)
}


clear_dead :: proc(game: ^Game) {
	archetypes, is_empty := query_archetype(game.world, COMPONENT_ID.DATA)
	if is_empty {
		return
	}

	for archetype in archetypes {
		data := archetype.data

		for i := 0; i < len(archetype.entities_id); {
			if data[i].state == .DEAD {
				unordered_remove(&archetype.entities_id, i)
				for component, index in COMPONENT_ID {
					if (component & archetype.component_mask) == component {
						switch component {
						case .POSITION:
							unordered_remove(&archetype.positions, i)
						case .VELOCITY:
							unordered_remove(&archetype.velocities, i)
						case .SPRITE:
							unordered_remove(&archetype.sprites, i)
						case .ANIMATION:
							unordered_remove(&archetype.animations, i)
						case .DATA:
							unordered_remove(&archetype.data, i)
						case .COLLIDER:
							unordered_remove(&archetype.colliders, i)
						case .IA:
							unordered_remove(&archetype.ias, i)
						case .PLAYER_DATA:
							unordered_remove(&archetype.players_data, i)
						case .COUNT:
						}

					}
				}
			} else {
				i += 1
			}
		}

	}

}

update_scene :: proc(game: ^Game) {
	if game.candy_respawn_time >= CANDY_RESPAWN_TIME {
		game.candy_respawn_time = 0
		if game.count_candies < MAX_NUM_CANDIES {
			fmt.println("SPAWN THE CANDYYY")
			spawn_candy(game)
		}
	}

	if game.enemy_respawn_time >= ENEMY_RESPAWN_TIME {
		game.enemy_respawn_time = 0
		if game.count_enemies < MAX_NUM_ENEMIES {
			spawn_enemy(game)
		}
	}

	game.enemy_respawn_time += 1
	game.candy_respawn_time += 1
}

grow_body :: proc(body: ^Body, head_pos, head_dir: Vector2) {
	if body.num_cells < MAX_NUM_BODY {
		body.growing = true
		body.num_cells += 1

		if body.num_cells > 0 {
			shift_array_right(&body.cells, int(body.num_cells))
		}

		body.cells[0] = cell_t {
			position         = head_pos,
			direction        = head_dir,
			count_turns_left = 0,
			size             = PLAYER_SIZE,
		}

	} else {
		fmt.println("WE DO NOT GROW!")
	}
}


dealing_ghost_piece :: proc(body: ^Body, last_piece: i8) {
	ghost_piece, ok := peek_head(body.ghost_pieces)
	if !ok {
		return
	}

	is_colliding := rec_colliding(
		body.cells[last_piece].position,
		PLAYER_SIZE,
		PLAYER_SIZE,
		ghost_piece.position,
		PLAYER_SIZE,
		PLAYER_SIZE,
	)

	if (is_colliding && body.cells[last_piece].direction == ghost_piece.direction) {
		pop_cell(body.ghost_pieces)
	}
}

///////////
// SPAWN //
///////////
spawn_enemy :: proc(game: ^Game) {
	random_index := rand.int_max(n = game.count_spawn_areas)

	rect := game.spawn_areas[random_index]

	x := rect.x + rand.float32() * rect.width
	y := rect.y + rand.float32() * rect.height

	x = math.floor(x / PLAYER_SIZE) * PLAYER_SIZE
	y = math.floor(y / PLAYER_SIZE) * PLAYER_SIZE

	mask := (COMPONENT_ID.POSITION | .VELOCITY | .ANIMATION | .COLLIDER | .DATA | .IA)
	add_entity(game.world, mask)

	archetype := game.world.archetypes[mask]
	enemy_position := Position{{x, y}, {ENEMY_SIZE, ENEMY_SIZE}}
	append(&archetype.positions, enemy_position)
	append(&archetype.velocities, Velocity{{0, 0}, ENEMY_SPEED})
	append(&archetype.animations, animation_bank[ANIMATION.ENEMY_RUN])


	colision_origin := Vector2{x, y} + EPSILON_COLISION * 2
	enemy_collider := Collider {
		colision_origin,
		ENEMY_SIZE - EPSILON_COLISION * 4,
		ENEMY_SIZE - EPSILON_COLISION * 4,
	}
	append(&archetype.colliders, enemy_collider)

	append(&archetype.data, Data{.ENEMY, .ALIVE, .BAD})
	append(&archetype.ias, IA{.APPROACH, 60, 100, 500, 0})

	game.count_enemies += 1

	fmt.println("APPENDED NEW ENEMY")
	fmt.println("POSITION:  ", enemy_position)
	fmt.println("COLLIDER: ", enemy_collider)

}

spawn_bullet :: proc(
	game: ^Game,
	origin: Vector2,
	bullet_size: f32,
	speed: f32,
	direction: Vector2,
	team: ENTITY_TEAM,
) {
	mask := (COMPONENT_ID.POSITION | .VELOCITY | .ANIMATION | .COLLIDER | .DATA)
	add_entity(game.world, mask)

	archetype := game.world.archetypes[mask]

	append(&archetype.positions, Position{origin, {bullet_size, bullet_size}})
	append(&archetype.velocities, Velocity{direction, speed})

	anim :=
		(team == .GOOD) ? animation_bank[ANIMATION.BULLET_G] : animation_bank[ANIMATION.BULLET_B]
	// anim.angle = angle_from_vector(direction)
	append(&archetype.animations, anim)
	append(
		&archetype.colliders,
		Collider {
			origin + EPSILON_COLISION,
			int(bullet_size) - EPSILON_COLISION * 2,
			int(bullet_size) - EPSILON_COLISION * 2,
		},
	)
	append(&archetype.data, Data{.BULLET, .ALIVE, team})
}

spawn_candy :: proc(game: ^Game) {
	mask := (COMPONENT_ID.POSITION | .ANIMATION | .COLLIDER | .DATA)
	add_entity(game.world, mask)

	archetype := game.world.archetypes[mask]

	pos_x := rand.int_max((SCREEN_WIDTH / (PLAYER_SIZE * 2)) - 1)
	pos_x = int(
		clamp(
			f32(pos_x * PLAYER_SIZE * 2 + PLAYER_SIZE / 2),
			PLAYER_SIZE * 2.5,
			SCREEN_WIDTH - PLAYER_SIZE * 2.5,
		),
	)

	pos_y := rand.int_max((SCREEN_HEIGHT / (PLAYER_SIZE * 2)) - 1)
	pos_y = int(
		clamp(
			f32(pos_y * PLAYER_SIZE * 2 + PLAYER_SIZE / 2),
			PLAYER_SIZE * 2.5,
			SCREEN_HEIGHT - PLAYER_SIZE * 2.5,
		),
	)

	append(
		&archetype.positions,
		Position{{f32(pos_x + 10), f32(pos_y + 10)}, {CANDY_SIZE, CANDY_SIZE}},
	)
	append(&archetype.data, Data{.CANDY, .ALIVE, .NEUTRAL})
	append(&archetype.animations, animation_bank[ANIMATION.CANDY])

	collider_position := Vector2{f32(pos_x + 10), f32(pos_y + 10)} + EPSILON_COLISION

	append(
		&archetype.colliders,
		Collider {
			collider_position,
			CANDY_SIZE - EPSILON_COLISION * 2,
			CANDY_SIZE - EPSILON_COLISION * 2,
		},
	)
	game.count_candies += 1
}

////////////
// RENDER //
////////////
draw_game :: proc(game: ^Game) {
	draw_grid({100, 100, 100, 255})
	// draw_scene(game)
	draw_body(&game.player_body)
	// draw_ghost_cells(game.player_body.ghost_pieces)
	RenderingSystem(game)
}

// draw_scene :: proc(game: ^Game) {
// 	for i in 0 ..< game.scene.count_scenario {
// 		rectangle := game.scene.scenario[i]
// 		rec := rl.Rectangle {
// 			rectangle.position.x,
// 			rectangle.position.y,
// 			rectangle.shape.(Rect).w,
// 			rectangle.shape.(Rect).h,
// 		}
// 		rl.DrawRectangleRec(rec, rl.YELLOW)
// 	}
//
// 	for i in 0 ..< game.scene.count_spawners {
// 		rectangle := game.scene.spawn_areas[i]
// 		rec := rl.Rectangle {
// 			rectangle.position.x,
// 			rectangle.position.y,
// 			rectangle.shape.(Rect).w,
// 			rectangle.shape.(Rect).h,
// 		}
// 		rl.DrawRectangleRec(rec, rl.PINK)
// 	}
//
// 	for i in 0 ..< game.scene.count_entities {
// 		entity := &game.scene.entities[i]
// 		color: rl.Color
//
// 		switch entity.kind {
// 		case .STATIC:
// 			color = rl.YELLOW
// 		case .CANDY:
// 			color = rl.WHITE
// 		}
// 		switch s in entity.shape {
// 		case Circle:
// 			rl.DrawCircle(i32(entity.position.x), i32(entity.position.y), s.r / 2, color)
// 			draw(entity)
// 		case Square:
// 			rec := rl.Rectangle{entity.position.x, entity.position.y, s.w, s.w}
// 			rl.DrawRectangleRec(rec, color)
// 			draw(entity)
// 		case Rect:
// 			rec := rl.Rectangle{entity.position.x, entity.position.y, s.w, s.h}
// 			rl.DrawRectangleRec(rec, color)
// 			draw(entity)
// 		}
//
// 	}
//
// 	for i in 0 ..< game.scene.count_enemies {
// 		enemy := &game.scene.enemies[i]
// 		rl.DrawCircle(
// 			i32(enemy.position.x),
// 			i32(enemy.position.y),
// 			enemy.shape.(Circle).r / 2 - EPSILON_COLISION,
// 			rl.RED,
// 		)
// 		draw(enemy)
//
// 	}
// 	for i in 0 ..< game.scene.count_bullets {
// 		bullet := &game.scene.bullets[i]
// 		rl.DrawCircle(
// 			i32(bullet.position.x),
// 			i32(bullet.position.y),
// 			bullet.shape.(Circle).r / 2 - EPSILON_COLISION,
// 			rl.BLUE,
// 		)
// 		draw(bullet)
// 	}
// }
//
draw_body :: proc(body: ^Body) {
	for i in 0 ..< body.num_cells {
		cell := body.cells[i]


		rl.DrawRectangle(
			i32(cell.position.x),
			i32(cell.position.y),
			i32(math.round(cell.size)),
			i32(math.round(cell.size)),
			rl.ORANGE,
		)

	}

	draw_body_sprite(body)
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
aligned_to_grid :: proc(p: Vector2) -> bool {
	return i32(p.x) % GRID_SIZE == 0 && i32(p.y) % GRID_SIZE == 0
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
