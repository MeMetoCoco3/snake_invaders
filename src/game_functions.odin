package main
import "core:fmt"
import "core:math"
import "core:math/rand"
import vmem "core:mem/virtual"
import rl "vendor:raylib"
///////////
// INPUT //
///////////

table_enemy_human := ia_table {
	move     = ia_human,
	get_type = get_enemy_human_type,
}

table_enemy_shield := ia_table {
	move     = ia_shield,
	get_type = get_enemy_shield_type,
}

enemy_behavior := #partial [ENEMY_KIND]IA {
	.HUMAN = IA {
		behavior = BEHAVIOR(IA_ENEMY_HUMAN{.APPROACH, 60, 100, 500, 0, 0}),
		table = &table_enemy_human,
	},
	.SHIELD = IA {
		behavior = BEHAVIOR(IA_ENEMY_SHIELD{.LOOK_FOR_TARGET, nil, 0}),
		table = &table_enemy_shield,
	},
}

UpdateCamera :: proc(g: ^Game) {
	gx, gy := g.player_position.pos.x, g.player_position.pos.y
	camera_pos := rl.Vector2{gx - SCREEN_WIDTH / 2, gy - SCREEN_HEIGHT / 2}
	g.camera.target = camera_pos

}

InitCamera :: proc(g: ^Game) {
	// g.camera.target = g.player_position.pos
	g.camera.zoom = 1
	// g.camera. = g.player_position
}


InputSystem :: proc(game: ^Game) {
	if (rl.IsKeyReleased(.C)) {
		DEBUG_COLISION = !DEBUG_COLISION
	}

	player_velocity := game.player_velocity
	player_data := game.player_data
	player_position := game.player_position

	if (rl.IsKeyDown(.H) || rl.IsKeyDown(.LEFT)) {
		player_data.next_dir = {-1, 0}
	} else if (rl.IsKeyDown(.L) || rl.IsKeyDown(.RIGHT)) {
		player_data.next_dir = {1, 0}
	} else if (rl.IsKeyDown(.J) || rl.IsKeyDown(.DOWN)) {
		player_data.next_dir = {0, 1}
	} else if (rl.IsKeyDown(.K) || rl.IsKeyDown(.UP)) {
		player_data.next_dir = {0, -1}
	} else {
		player_data.next_dir = {0, 0}
	}


	if rl.IsKeyPressed(.P) {
		rl.PauseAudioStream(game.audio.bg_music)
		game.state = .PAUSE
	}

	if player_data.can_dash && rl.IsKeyPressed(.X) || player_data.gona_dash {
		player_data.gona_dash = true
		player_velocity.speed = PLAYER_SPEED * 2
		player_data.can_dash = false
		player_data.time_on_dash = 0
		player_data.player_state = .DASH
		player_data.gona_dash = false
		player_data.distance = 0
	}

	body := &game.player_body
	not_growing := !game.player_body.growing

	if rl.IsKeyDown(.Z) &&
	   body.num_cells > 0 &&
	   player_data.next_bullet_size < MAX_BULLET_SIZE &&
	   not_growing {
		last_index := game.player_body.num_cells - 1
		last_cell_pos, last_cell_velocity, last_cell_data, ok := get_cell(game, last_index)
		last_cell_pos.size = math.lerp(last_cell_pos.size, f32(0.0), f32(SMOOTHING))

		penultimate_cell_pos, _, penultimate_cell_data, penultimate_on := get_cell(
			game,
			last_index - 1,
		)

		num_turns_left := last_cell_data.count_turn_left
		max_delete_cells := 3

		if penultimate_on {
			fmt.println("PNULTIMATE ON", max_delete_cells)
			max_delete_cells = num_turns_left - penultimate_cell_data.count_turn_left
			fmt.println("PNULTIMATE ON", max_delete_cells)
		}

		if last_cell_pos.size.x < f32(EPSILON) {
			count_turns_left := last_cell_data.count_turn_left
			for i := 0; i < max_delete_cells; i += 1 {
				last_ghost, ok := peek_head(body.ghost_pieces)
				distance_to_ghost := manhattan_distance(last_cell_pos.pos, last_ghost.position)

				if ok && count_turns_left > 0 && distance_to_ghost < PLAYER_SIZE {
					ghost, ok := pop_cell(body.ghost_pieces)
					if ok {
						kill_entity(game.world.archetypes[ghost_mask], ghost.entity_id)
					}
				} else {
					break
				}


			}

			player_data.next_bullet_size += 1
			kill_last_body_cell(game)
			body.num_cells -= 1
		}
	}
	// } else if body.num_cells > 0 {
	// 	last_cell_pos, last_cell_velocity, last_cell_data, ok := get_last_cell2(game)
	// 	if PLAYER_SIZE - last_cell_pos.size.x > EPSILON {
	// 		last_cell_pos.size = math.lerp(
	// 			Vec2{last_cell_pos.size.x, last_cell_pos.size.y},
	// 			f32(PLAYER_SIZE),
	// 			f32(SMOOTHING / 2),
	// 		)
	// 	} else {
	// 		last_cell_pos.size = PLAYER_SIZE
	// 	}
	// }


	if (rl.IsKeyReleased(.Z)) && player_data.next_bullet_size > 0 {
		AddSound(game, &sound_bank[FX.FX_SHOOT])
		// THIS ORIGIN MARKS THE VERTEZ SO I SHOULD TAKEON ACCOUT ALSO THE SIZE OF THE BULLET
		origin := player_position.pos + player_position.size / 2

		speed := max(player_velocity.speed * 1.5, BULLET_SPEED)

		direction := player_velocity.direction
		if direction == {0, 0} {
			direction = player_data.previous_dir
		}

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

InputSystemPause :: proc(game: ^Game) {
	if (rl.IsKeyPressed(.ENTER)) {
		if game.state == .DEAD {
			vmem.arena_free_all(game.arena)
			LoadScene(game, game.current_scene)
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
	PlaySound(game)
	UpdateScene(game)
	UpdateCamera(game)
	fmt.println(game.camera.target)
	if game.player_data.cells_to_grow > 0 {
		game.player_data.cells_to_grow -= 1
		if !game.player_body.growing && game.player_data.distance > PLAYER_SIZE {
			fmt.println("WE GONNA GROW")
			grow_body(
				game,
				&game.player_body,
				game.player_position.pos,
				game.player_velocity.direction,
			)
		}

		game.player_data.distance = 0
	}

	if game.player_body.num_cells > 0 {
		body_positions := game.world.archetypes[body_mask].positions
		ghosts := game.player_body.ghost_pieces
		check_broken_ghost(game.world, ghosts, body_positions[:])
	}
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
done := false
UpdateScene :: proc(game: ^Game) {
	if game.candy_respawn_time >= CANDY_RESPAWN_TIME {
		if game.count_candies < MAX_NUM_CANDIES {
			game.candy_respawn_time = 0
			spawn_candy(game)
		}
	}


	if !done {
		spawn_pos := get_random_position_on_spawn(game)
		spawn_enemy(game, spawn_pos.x, spawn_pos.y, .SHIELD)
		spawn_pos = get_random_position_on_spawn(game)
		spawn_enemy(game, spawn_pos.x, spawn_pos.y, .HUMAN)
		done = true
	}
	// if game.enemy_respawn_time >= ENEMY_RESPAWN_TIME {
	// 	game.enemy_respawn_time = 0
	// 	if game.count_enemies < MAX_NUM_ENEMIES {
	// 		spawn_pos := get_random_position_on_spawn(game)
	// 		new_kind := get_random_enemy_type()
	//
	// 		spawn_enemy(game, spawn_pos.x, spawn_pos.y, new_kind)
	// 	}
	// }

	game.enemy_respawn_time += 1
	game.candy_respawn_time += 1
	game.player_data.time_since_dmg += 1
}

get_random_enemy_type :: proc() -> ENEMY_KIND {
	n := rand.int_max(int(ENEMY_KIND.TOP))
	return ENEMY_KIND(n)
}


get_cell :: proc(g: ^Game, index: i8) -> (^Position, ^Velocity, ^PlayerData, bool) {
	archetype := g.world.archetypes[body_mask]
	for i in 0 ..< len(archetype.entities_id) {
		current_index := archetype.players_data[i].body_index == index
		kind := archetype.data[i].kind

		if kind == .BODY && current_index {
			return &archetype.positions[i],
				&archetype.velocities[i],
				&archetype.players_data[i],
				true
		}
	}
	return nil, nil, nil, false
}

//
// get_last_cell :: proc(game: ^Game) -> (^Position, ^Velocity, ^PlayerData, bool) {
// 	archetype := game.world.archetypes[body_mask]
// 	for i in 0 ..< len(archetype.entities_id) {
// 		if archetype.data[i].kind == .BODY {
// 			return &archetype.positions[i],
// 				&archetype.velocities[i],
// 				&archetype.players_data[i],
// 				true
// 		}
// 	}
// 	return nil, nil, nil, false
// }
//
grow_body :: proc(game: ^Game, body: ^Body, head_pos, head_dir: Vec2) {
	switch {
	case body.num_cells < MAX_NUM_BODY:
		add_entity(
			game.world,
			body_mask,
			[]Component {
				Position{pos = head_pos, size = {PLAYER_SIZE, PLAYER_SIZE}},
				Velocity{direction = head_dir, speed = 0},
				sprite_bank[SPRITE.BODY_STRAIGHT],
				PlayerData{player_state = .NORMAL, count_turn_left = 0, body_index = -1},
				Collider{position = head_pos, w = PLAYER_SIZE, h = PLAYER_SIZE},
				Data{kind = .BODY, state = .ALIVE, team = .GOOD},
			},
		)


		archetype := game.world.archetypes[body_mask]
		index := len(archetype.entities_id) - 1

		game.player_body.first_cell_pos = &archetype.positions[index]
		game.player_body.first_cell_data = &archetype.players_data[index]


		add_body_index(game.world)
		body.growing = true
		body.num_cells += 1
	case:
		fmt.println("WE DO NOT GROW!")
	}
}

add_ghost_body_index :: proc(world: ^World) {
	archetype := world.archetypes[ghost_mask]
	// fmt.printfln("Add ghost body index on len = %v", len(archetype.entities_id))
	for i in 0 ..< len(archetype.entities_id) {
		if archetype.data[i].kind == .GHOST_PIECE && archetype.data[i].state == .ALIVE {
			// fmt.printfln(
			// 	"ID %v, Body indexbefore: %v",
			// 	archetype.entities_id[i],
			// 	archetype.players_data[i].body_index,
			// )
			archetype.players_data[i].body_index += 1
			// fmt.printfln("Index: %v, Body indexafter: %v", i, archetype.players_data[i].body_index)
		}
	}
}


add_body_index :: proc(world: ^World) {
	archetype := world.archetypes[body_mask]
	for i in 0 ..< len(archetype.entities_id) {
		if archetype.data[i].kind == .BODY {
			index := &archetype.players_data[i].body_index
			// if index^ == -1 {
			// index^ = 0
			// } else if index^ >= 0 {
			index^ += 1
			// }
		}
	}
}


dealing_ghost_piece :: proc(game: ^Game, body: ^Body, last_piece: i8) -> (cell_ghost_t, bool) {
	ghost_piece, ok := peek_head(body.ghost_pieces)
	if !ok {
		return {}, false
	}

	last_index := game.player_body.num_cells - 1
	last_cell_pos, last_cell_velocity, last_cell_data, _ := get_cell(game, last_index)
	is_colliding := rec_colliding(
		last_cell_pos.pos,
		PLAYER_SIZE,
		PLAYER_SIZE,
		ghost_piece.position,
		PLAYER_SIZE,
		PLAYER_SIZE,
	)

	if (is_colliding && last_cell_velocity.direction == ghost_piece.direction) {
		ghost, _ := pop_cell(body.ghost_pieces)
		ghost_archetype := game.world.archetypes[ghost_mask]
		kill_entity(ghost_archetype, ghost.entity_id)
		return ghost, true
	}
	return {}, false
}

///////////
// SPAWN //
///////////

get_random_position_on_spawn :: proc(game: ^Game) -> [2]f32 {
	random_index := rand.int_max(n = game.count_spawn_areas)

	rect := game.spawn_areas[random_index]

	x := rect.x + rand.float32() * rect.width
	y := rect.y + rand.float32() * rect.height

	x = math.floor(x / PLAYER_SIZE) * PLAYER_SIZE
	y = math.floor(y / PLAYER_SIZE) * PLAYER_SIZE

	return {x, y}
}

spawn_enemy :: proc(game: ^Game, x, y: f32, kind: ENEMY_KIND) -> u32 {
	animation: Animation
	velocity: Velocity
	#partial switch kind {
	case .HUMAN:
		animation = animation_bank[ANIMATION.ENEMY_RUN]
		velocity = Velocity{{0, 0}, ENEMY_SPEED}
	case .SHIELD:
		animation = animation_bank[ANIMATION.SHIELD]
		velocity = Velocity{{0, 0}, ENEMY_SPEED * 1.5}
	}

	colision_origin := Vec2{x, y} + EPSILON_COLISION * 2
	id := add_entity(
	game.world,
	enemy_mask,
	[]Component {
		Position{{x, y}, {ENEMY_SIZE, ENEMY_SIZE}},
		velocity,
		animation,
		Collider {
			colision_origin,
			ENEMY_SIZE - EPSILON_COLISION * 4,
			ENEMY_SIZE - EPSILON_COLISION * 4,
			true,
		},
		Data{.ENEMY, .ALIVE, .BAD},
		// IA{behavior = IA_ENEMY_HUMAN{.APPROACH, 60, 100, 500, 0}, table = &table_enemy_human},
		enemy_behavior[kind],
	},
	)
	game.count_enemies += 1
	return id
}


spawn_bullet :: proc(
	game: ^Game,
	origin: Vec2,
	bullet_size: f32,
	speed: f32,
	direction: Vec2,
	team: ENTITY_TEAM,
) {

	anim :=
		(team == .GOOD) ? animation_bank[ANIMATION.BULLET_G] : animation_bank[ANIMATION.BULLET_B]
	id := add_entity(
		game.world,
		bullet_mask,
		[]Component {
			Position{origin, {bullet_size, bullet_size}},
			Velocity{direction, speed},
			anim,
			Collider {
				origin + EPSILON_COLISION,
				int(bullet_size) - EPSILON_COLISION * 2,
				int(bullet_size) - EPSILON_COLISION * 2,
				true,
			},
			Data{.BULLET, .ALIVE, team},
		},
	)
}

spawn_candy :: proc(game: ^Game) {
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

	id := add_entity(
		game.world,
		candy_mask,
		[]Component {
			Position{{f32(pos_x + 10), f32(pos_y + 10)}, {CANDY_SIZE, CANDY_SIZE}},
			Data{.CANDY, .ALIVE, .NEUTRAL},
			animation_bank[ANIMATION.CANDY],
			Collider {
				Vec2{f32(pos_x + 10), f32(pos_y + 10)} + EPSILON_COLISION,
				CANDY_SIZE - EPSILON_COLISION * 2,
				CANDY_SIZE - EPSILON_COLISION * 2,
				true,
			},
		},
	)

	archetype := game.world.archetypes[candy_mask]

	game.count_candies += 1
}

////////////
// RENDER //
////////////
DrawGame :: proc(game: ^Game) {
	DrawGrid({100, 100, 100, 255})

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	rl.BeginMode2D(game.camera)
	DrawBody(&game.player_body)
	DrawGhostCells(game.player_body.ghost_pieces)
	RenderingSystem(game)
	if DEBUG_COLISION {
		DrawCollidersSystem(game)
	}

	rl.EndMode2D()
	rl.EndDrawing()
}

DrawGrid :: proc(col: rl.Color) {
	for i: i32 = 0; i < SCREEN_WIDTH; i += GRID_SIZE {
		rl.DrawLine(i, 0, i, SCREEN_HEIGHT, col)
		rl.DrawLine(0, i, SCREEN_WIDTH, i, col)
	}
}


DrawBody :: proc(body: ^Body) {
	draw_body_sprite(body)
}


DrawGhostCells :: proc(rb: ^Ringuffer_t(cell_ghost_t)) {
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
