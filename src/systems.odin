package main
import "core:fmt"
import "core:math"
import rl "vendor:raylib"


audio_system_t :: struct {
	bg_music: rl.Music,
	fx:       [dynamic]^rl.Sound,
}

FX :: enum {
	FX_EAT = 0,
	FX_SHOOT,
	FX_COUNT,
}


DrawCollidersSystem :: proc(game: ^Game) {
	arquetypes, is_empty := query_archetype(game.world, COMPONENT_ID.COLLIDER)
	if is_empty {
		return
	}

	for arquetype in arquetypes {
		colliders := arquetype.colliders
		for i in 0 ..< len(arquetype.entities_id) {
			team := arquetype.data[i].team
			color := rl.WHITE

			switch team {
			case .NEUTRAL:
				color = rl.GRAY
			case .BAD:
				color = rl.RED
			case .GOOD:
				color = rl.BLUE
			}

			rect := rl.Rectangle {
				x      = colliders[i].position.x,
				y      = colliders[i].position.y,
				width  = f32(colliders[i].w),
				height = f32(colliders[i].h),
			}
			rl.DrawRectangleRec(rect, color)
		}
	}
}

CollisionSystem :: proc(game: ^Game) {
	arquetypesA, is_empty := query_archetype(
		game.world,
		COMPONENT_ID.COLLIDER | .DATA | .VELOCITY | .POSITION,
	)
	if is_empty {
		return
	}

	// No need to check 2 colliders if either have velocity
	arquetypesB, _ := query_archetype(game.world, COMPONENT_ID.COLLIDER | .DATA | .POSITION)
	for archetypeA in arquetypesA {
		for i in 0 ..< len(archetypeA.entities_id) {
			colliderA := &archetypeA.colliders[i]
			dataA := &archetypeA.data[i]
			velocityA := &archetypeA.velocities[i]
			positionA := &archetypeA.positions[i]

			is_player := false
			is_turning := false
			// dir_is_zero := false
			colliderA_future_pos := Collider {
				colliderA.position + velocityA.direction * velocityA.speed,
				colliderA.h,
				colliderA.w,
			}


			if dataA.kind == .PLAYER {

				player := game.world.archetypes[player_mask]
				body := &game.player_body
				head_position := &player.positions[0].pos
				head_direction := player.velocities[0].direction
				head_velocity := &player.velocities[0]
				head_data := &player.players_data[0]
				head_colision := &player.colliders[0]
				has_body := game.player_body.num_cells > 0 ? true : false

				is_player = true
				can_turn := true
				if !aligned_to_grid(head_position^) {
					can_turn = false
					head_data.next_dir = {0, 0}
				}


				// Prohibe movimiento hacia atras.
				if has_body {
					dir := get_cardinal_direction(
						head_position^,
						game.player_body.cells[0].position,
					)
					if dir == head_data.next_dir {
						head_data.next_dir = {0, 0}
					}
				}

				if can_turn &&
				   try_set_dir(head_velocity, head_data.next_dir, head_direction, head_data) {
					is_turning = true
				}
				colliderA_future_pos.position =
					colliderA.position + velocityA.speed * player.velocities[0].direction
			}


			for archetypeB in arquetypesB {
				for j in 0 ..< len(archetypeB.entities_id) {
					dataB := &archetypeB.data[j]
					if dataB.state == .DEAD || dataB == dataA || dataB.kind == .PLAYER {
						continue
					}

					colliderB := &archetypeB.colliders[j]
					positionB := &archetypeB.positions[j]

					#partial switch dataB.kind {
					case .CANDY:
						if is_player &&
						   dataB.state != .DEAD &&
						   collide_no_edges(colliderB^, colliderA^) {
							dataB.state = .DEAD
							add_sound(game, &sound_bank[FX.FX_EAT])

							grow_body(
								&game.player_body,
								positionA.pos,
								game.player_velocity.direction,
							)
							archetypeA.players_data[0].distance = 0
						}

					case .STATIC:
						if collide(colliderB^, colliderA_future_pos) {
							if is_player {
								archetypeA.velocities[i].direction = Vector2{0, 0}
								continue
							}

							is_bullet := dataA.kind == .BULLET
							if is_bullet {
								dataA.state = .DEAD
							}
							velocityA.direction = {0, 0}
						}

					case .ENEMY:
						if is_player &&
						   dataB.state != .DEAD &&
						   collide_no_edges(colliderB^, colliderA^) {
							player_data := archetypeA.players_data[0].player_state
							switch player_data {
							case .NORMAL:
								game.state = .DEAD
								break
							case .DASH:
								fmt.println("WE EAT")
								dataB.state = .DEAD
								add_sound(game, &sound_bank[FX.FX_EAT])
								grow_body(
									&game.player_body,
									positionA.pos,
									game.player_velocity.direction,
								)
								// Distancia recorrida, en este caso medimos la distancia recorrida despues de empezar a crecer.
								archetypeA.players_data[0].distance = 0
							}
						}

					case .BULLET:
						if dataA.team == dataB.team {
							continue
						}

						are_colliding := collide(colliderB^, colliderA^)

						if are_colliding {
							fmt.println("COLLISION")
							if dataB.team == .BAD && is_player {
								game.state = .DEAD
							} else if dataB.team == .GOOD && !is_player {
								dataA.state = .DEAD
								dataB.state = .DEAD
							}
						}

					case .PLAYER:
						continue
					}
				}
			}

			// We check if a turn is made after the collision is checked, if it is, we spawn a ghost.
			head_position := game.player_position.pos
			head_velocity := game.player_velocity
			body := &game.player_body
			player := game.world.archetypes[player_mask]
			future_head_pos := head_position + head_velocity.direction * head_velocity.speed

			if is_turning &&
			   !aligned_vectors(head_position, future_head_pos, body.cells[0].position) &&
			   body.num_cells > 0 { 	// !dir_is_zero &&

				rotation: f32 = 90
				from_dir := player.velocities[0].direction
				to_dir := get_cardinal_direction(head_position, body.cells[0].position)
				fmt.println("TO DIR", to_dir)

				if (from_dir == {0, -1} && to_dir == {1, 0}) ||
				   (from_dir == {1, 0} && to_dir == {0, -1}) {
					rotation += 270
				} else if (from_dir == {0, -1} && to_dir == {-1, 0}) ||
				   (from_dir == {-1, 0} && to_dir == {0, -1}) {
					rotation += 180
				} else if (from_dir == {0, 1} && to_dir == {-1, 0}) ||
				   (from_dir == {-1, 0} && to_dir == {0, 1}) {
					rotation += 90
				} else if (from_dir == {0, 1} && to_dir == {1, 0}) ||
				   (from_dir == {1, 0} && to_dir == {0, 1}) {
					rotation += 0
				} else {
					return
				}

				// Checks if the previous ghost is aligned with the head_position and the future_head_pos
				if body.cells[0].count_turns_left > 0 {
					ghost, ok := peek_head(body.ghost_pieces)
					if aligned_vectors(ghost.position, head_position, future_head_pos) {
						return
					}
				}

				put_cell(body.ghost_pieces, cell_ghost_t{head_position, from_dir, rotation})
				add_turn_count(body)
			}
		}

	}

}


IASystem :: proc(game: ^Game) {
	arquetypes, is_empty := query_archetype(game.world, COMPONENT_ID.IA | .VELOCITY | .POSITION)
	if is_empty {
		return
	}

	center_player := game.player_position.pos + PLAYER_SIZE / 2

	for arquetype in arquetypes {
		velocities := &arquetype.velocities
		positions := &arquetype.positions
		animations := &arquetype.animations
		ias := &arquetype.ias

		for i in 0 ..< len(arquetype.entities_id) {
			center_enemy := positions[i].pos + ENEMY_SIZE / 2
			distance_to_player := vec2_distance(center_player, center_enemy)

			if ias[i]._time_for_change_state > TIME_TO_CHANGE_STATE {
				ias[i]._time_for_change_state = 0
				switch {
				case distance_to_player > ias[i].maximum_distance:
					ias[i].behavior = .APPROACH
					animations[i] = animation_bank[ANIMATION.ENEMY_RUN]
				case distance_to_player < ias[i].minimum_distance:
					animations[i] = animation_bank[ANIMATION.ENEMY_RUN]
					ias[i].behavior = .GOAWAY
				case:
					animations[i] = animation_bank[ANIMATION.ENEMY_SHOT]
					ias[i].behavior = .SHOT
				}} else {
				ias[i]._time_for_change_state += 1
			}

			direction := (center_player - center_enemy) / distance_to_player


			switch ias[i].behavior {
			case .SHOT:
				velocities[i].direction = {0, 0}
				if ias[i].reload_time >= ENEMY_TIME_RELOAD {
					spawn_bullet(
						game,
						positions[i].pos,
						ENEMY_SIZE_BULLET,
						BULLET_SPEED / 2,
						direction,
						.BAD,
					)
					ias[i].reload_time = 0
				} else {
					ias[i].reload_time += 1
				}
			case .APPROACH:
				velocities[i].direction = direction
			case .GOAWAY:
				velocities[i].direction = -direction
			}

		}
	}
}


VelocitySystem :: proc(game: ^Game) {
	player := game.world.archetypes[player_mask]
	body := &game.player_body


	head_position := &player.positions[0].pos
	head_direction := player.velocities[0].direction
	head_velocity := &player.velocities[0]
	head_data := &player.players_data[0]
	head_colision := &player.colliders[0]
	has_body := game.player_body.num_cells > 0 ? true : false

	arquetypes, is_empty := query_archetype(
		game.world,
		COMPONENT_ID.VELOCITY | COMPONENT_ID.POSITION | COMPONENT_ID.COLLIDER | .DATA,
	)

	if is_empty {
		return
	}
	for arquetype in arquetypes {
		velocities := arquetype.velocities
		positions := arquetype.positions
		colliders := arquetype.colliders
		is_player := false

		mask := arquetype.component_mask
		if (mask & COMPONENT_ID.PLAYER_DATA) == .PLAYER_DATA {
			is_player = true
			fmt.println("CURRENT DIR", velocities[0].direction)
			fmt.println("PREV DIR", arquetype.players_data[0].previous_dir)
		}

		for i in 0 ..< len(arquetype.entities_id) {
			if (arquetype.data[i].kind == .BULLET && arquetype.data[i].team == .GOOD) {
				fmt.println("THE GOOD BULLET HAS SPEED = ", velocities[i].speed)
				fmt.println("THE GOOD BULLET HAS DIRECTION = ", velocities[i].direction)
			}
			vector_move := (velocities[i].direction * velocities[i].speed)
			if is_player {
				player_data := &arquetype.players_data[i]
				if !player_data.can_dash {
					player_data.time_on_dash += 1

					if player_data.time_on_dash >= RECOVER_DASH_TIME {
						player_data.can_dash = true
					}
				}

				if player_data.time_on_dash >= DASH_DURATION {
					velocities[i].speed = PLAYER_SPEED
					vector_move = (velocities[i].direction * velocities[i].speed)
					player_data.player_state = .NORMAL
				}

				head_data.distance += abs(vector_move.x + vector_move.y)
			}
			positions[i].pos += vector_move
			colliders[i].position += vector_move
		}
	}

	head_direction = player.velocities[0].direction
	if body.growing && head_direction != {0, 0} {
		distance := head_data.distance

		if distance > PLAYER_SIZE {
			body.growing = false
		}
	}


	if head_direction != {0, 0} && !body.growing {
		for i in 0 ..< body.num_cells {
			curr_cell := &body.cells[i]

			piece_to_follow: cell_t
			ghost_index_being_followed: i8 = -1

			if curr_cell.count_turns_left == 0 {
				piece_to_follow = cell_t {
					head_position^,
					head_direction,
					0,
					PLAYER_SIZE,
					Collider{},
				}
			} else {
				ghost_index_being_followed =
					(MAX_RINGBUFFER_VALUES + body.ghost_pieces.tail - curr_cell.count_turns_left) %
					MAX_RINGBUFFER_VALUES
				piece_to_follow = ghost_to_cell(
					body.ghost_pieces.values[ghost_index_being_followed],
				)
			}

			// BEGIN MOVEMENT
			remaining_movement := head_velocity.speed
			for {
				direction := get_cardinal_direction(curr_cell.position, piece_to_follow.position)
				distance_to_follow := vec2_distance(curr_cell.position, piece_to_follow.position)

				if distance_to_follow <= remaining_movement {
					curr_cell.position = piece_to_follow.position
					curr_cell.direction = piece_to_follow.direction
					remaining_movement -= distance_to_follow

					if curr_cell.count_turns_left > 0 {
						curr_cell.count_turns_left -= 1
					}

					if i == body.num_cells - 1 && ghost_index_being_followed >= 0 {
						dealing_ghost_piece(body, i)
					}

					if curr_cell.count_turns_left == 0 {
						piece_to_follow = cell_t {
							head_position^,
							head_direction,
							0,
							PLAYER_SIZE,
							Collider{},
						}
						ghost_index_being_followed = -1
					} else {
						ghost_index_being_followed =
							(MAX_RINGBUFFER_VALUES +
								body.ghost_pieces.tail -
								curr_cell.count_turns_left) %
							MAX_RINGBUFFER_VALUES
						piece_to_follow = ghost_to_cell(
							body.ghost_pieces.values[ghost_index_being_followed],
						)
					}
				} else {
					curr_cell.direction = direction
					curr_cell.position += direction * remaining_movement

					if i == body.num_cells - 1 && ghost_index_being_followed >= 0 {
						dealing_ghost_piece(body, i)
					}
					break
				}
			}
		}
	}
}

RenderingSystem :: proc(game: ^Game) {
	arquetypes, is_empty := query_archetype(game.world, COMPONENT_ID.POSITION | .SPRITE)
	if !is_empty {
		for arquetype in arquetypes {
			positions := arquetype.positions
			sprites := arquetype.sprites
			for i in 0 ..< len(arquetype.entities_id) {
				draw(sprites[i])
			}
		}


	}

	arquetypes, is_empty = query_archetype(game.world, COMPONENT_ID.POSITION | .ANIMATION)
	if !is_empty {
		for arquetype in arquetypes {
			positions := arquetype.positions
			animations := arquetype.animations
			direction := Vector2{0, 0}
			team := arquetype.data
			has_velocity := false
			is_player := false

			if (arquetype.component_mask & COMPONENT_ID.PLAYER_DATA) == .PLAYER_DATA {
				is_player = true
			}


			if (arquetype.component_mask & COMPONENT_ID.VELOCITY) == .VELOCITY {
				has_velocity = true
			}

			for i in 0 ..< len(arquetype.entities_id) {
				if has_velocity {

					if is_player && arquetype.velocities[i].direction == {0, 0} {
						direction = arquetype.players_data[i].previous_dir
					} else {
						direction = arquetype.velocities[i].direction
					}
				}


				draw(positions[i], &animations[i], direction, team[i].team)
			}
		}
	}
}

angle_from_vector :: proc(v0: Vector2) -> f32 {
	return math.atan2(v0.y, v0.x) * (180.0 / math.PI)

}
