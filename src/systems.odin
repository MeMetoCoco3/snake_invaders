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
			rect := rl.Rectangle {
				x      = colliders[i].position.x,
				y      = colliders[i].position.y,
				width  = f32(colliders[i].w),
				height = f32(colliders[i].h),
			}
			rl.DrawRectangleRec(rect, rl.BLUE)
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
					// player.animations[i].
					// if head_data.next_dir != (Vector2{0, 0}) {
					is_turning = true
					// }
				}
				// fmt.println(velocityA.speed)
				colliderA_future_pos.position =
					colliderA.position + velocityA.speed * player.velocities[0].direction

				if is_player {
					fmt.println("PREV DIRECTION", player.players_data[i].previous_dir)
				}
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
							fmt.println("WE EAT")
							dataB.state = .DEAD
							add_sound(game, &sound_bank[FX.FX_EAT])

							grow_body(
								&game.player_body,
								positionA.pos,
								// archetypeA.players_data[i].next_dir * velocityA.speed,
								game.player_velocity.direction,
							)

							// Calcula distancia recorrida desde que crecemos
							archetypeA.players_data[0].distance = 0


						}

					case .STATIC:
						if collide(colliderB^, colliderA_future_pos) {
							if is_player {
								fmt.println(" PLAYER IS COLLIDING")
								archetypeA.velocities[i].direction = Vector2{0, 0}
								fmt.println("Player position", positionA)
								continue
							}
							velocityA.direction = {0, 0}
						}

					case .ENEMY:
						if is_player &&
						   dataB.state != .DEAD &&
						   collide_no_edges(colliderB^, colliderA^) {
							switch dataA.player_state {
							case .NORMAL:
								game.state = .DEAD
								break
							case .DASH:
								dataA.state = .DEAD
								add_sound(game, &sound_bank[FX.FX_EAT])
								// TODO: 
								// grow_body(game.player)
								continue
							}
						}

					case .BULLET:
						if dataA.team == dataB.team {
							continue
						}

						are_colliding := collide_no_edges(colliderB^, colliderA^)
						if are_colliding {
							if dataB.team == .BAD && is_player {
								game.state = .DEAD
							} else if dataB.team == .GOOD && !is_player {
								dataB.state = .DEAD
								dataA.state = .DEAD
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
			   body.num_cells > 0 {
				// fmt.println("NOT ALIGNED")
				put_cell(
					body.ghost_pieces,
					cell_ghost_t{head_position, player.velocities[0].direction},
				)
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
		ias := &arquetype.ias

		for i in 0 ..< len(arquetype.entities_id) {
			center_enemy := positions[i].pos + ENEMY_SIZE / 2
			distance_to_player := vec2_distance(center_player, center_enemy)

			if ias[i]._time_for_change_state > TIME_TO_CHANGE_STATE {
				ias[i]._time_for_change_state = 0
				switch {
				case distance_to_player > ias[i].maximum_distance:
					ias[i].behavior = .APPROACH
				case distance_to_player < ias[i].minimum_distance:
					ias[i].behavior = .GOAWAY
				case:
					ias[i].behavior = .SHOT
				}} else {
				ias[i]._time_for_change_state += 1
			}

			direction := (center_player - center_enemy) / distance_to_player


			switch ias[i].behavior {
			case .SHOT:
				velocities[i].direction = {0, 0}
				if ias[i].reload_time >= ENEMY_TIME_RELOAD {
					spawn_bullet(game, positions[i].pos, ENEMY_SIZE_BULLET, direction, .BAD)
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

		if arquetype.data[0].kind == .PLAYER {
			is_player = true
		}

		for i in 0 ..< len(arquetype.entities_id) {

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
				// fmt.println(head_data.distance)
			}
			if is_player {
				fmt.println("PLAYER SPEED: ", velocities[i].speed)
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
		fmt.println("CHEKEANDO SI ENTRAMOS EN AQUI")
		for i in 0 ..< body.num_cells {
			piece_to_follow: cell_t

			moved := false
			if (body.cells[i].count_turns_left == 0) {

				absolute_direction := Vector2{abs(head_direction.x), abs(head_direction.y)}

				new_collider_size := absolute_direction * {GRID_SIZE, GRID_SIZE}
				new_collider_position := new_collider_size + head_position^

				if new_collider_size.x == PLAYER_SIZE {new_collider_size.x = 0}
				if new_collider_size.y == PLAYER_SIZE {new_collider_size.y = 0}

				piece_to_follow =
					(i == 0) ? cell_t{head_position^, head_direction, 0, PLAYER_SIZE, Collider{new_collider_position, int(new_collider_size.x), int(new_collider_size.y)}} : body.cells[i - 1]
				body.cells[i].direction = piece_to_follow.direction

			} else {
				index :=
					(MAX_RINGBUFFER_VALUES +
						body.ghost_pieces.tail -
						body.cells[i].count_turns_left) %
					MAX_RINGBUFFER_VALUES

				following_ghost_piece := ghost_to_cell(body.ghost_pieces.values[index])
				fmt.println(
					"Ghost Index: ",
					index,
					" Tail: ",
					body.ghost_pieces.tail,
					" Turns left: ",
					body.cells[i].count_turns_left,
				)
				fmt.println(
					"Following ghost pos: ",
					following_ghost_piece.position,
					" Cell pos: ",
					body.cells[i].position,
				)

				distance := vec2_distance(body.cells[i].position, following_ghost_piece.position)
				fmt.println("CHEKEANDO LA HEAD_VELOCITY.SPEED", head_velocity.speed)

				body_cell_speed := head_velocity.speed
				if distance < body_cell_speed {
					if body.cells[i].position == following_ghost_piece.position {
						body.cells[i].direction = following_ghost_piece.direction
						body.cells[i].count_turns_left -= 1

					} else {
						body.cells[i].position = following_ghost_piece.position
						fmt.println("WE MOVE IT BY CHANGING POSITION")
						body_cell_speed -= distance
						// moved = true

					}


				} else {
					direction_to_ghost := get_cardinal_direction(
						body.cells[i].position,
						following_ghost_piece.position,
					)
					body.cells[i].direction = direction_to_ghost
				}

				if (i == body.num_cells - 1) {
					dealing_ghost_piece(body, i)
				}
			}

			if !moved {
				fmt.println("Body speed: ", head_velocity.speed, i)
				fmt.println()
				body.cells[i].position += body.cells[i].direction * head_velocity.speed
			}
		}
	}
}

RenderingSystem :: proc(game: ^Game) {
	arquetypes, is_empty := query_archetype(game.world, COMPONENT_ID.POSITION | .SPRITE)
	if is_empty {
		return
	}

	for arquetype in arquetypes {
		positions := arquetype.positions
		sprites := arquetype.sprites
		for i in 0 ..< len(arquetype.entities_id) {
			draw(sprites[i])
		}
	}

	arquetypes, is_empty = query_archetype(game.world, COMPONENT_ID.POSITION | .ANIMATION)
	if is_empty {
		return
	}


	for arquetype in arquetypes {
		positions := arquetype.positions
		animations := arquetype.animations
		direction := Vector2{0, 0}
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


			draw(positions[i], &animations[i], direction)
		}
	}
}


angle_from_vector :: proc(v0: Vector2) -> f32 {
	return math.atan2(v0.y, v0.x) * (180.0 / math.PI)

}
