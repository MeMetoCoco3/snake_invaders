package main
import "core:fmt"
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

			colliderA_future_pos := Collider {
				colliderA.position + velocityA.direction * velocityA.speed,
				colliderA.h,
				colliderA.w,
			}


			if dataA.kind == .PLAYER {
				is_player = true
				colliderA_future_pos.position =
					colliderA.position + velocityA.speed * archetypeA.players_data[i].next_dir
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
								positionA.pos +
								archetypeA.players_data[i].next_dir * velocityA.speed,
								game.player_velocity.direction,
							)

						}

					case .STATIC:
						if collide_no_edges(colliderB^, colliderA_future_pos) {
							if is_player {
								archetypeA.players_data[i].next_dir = Vector2{0, 0}
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
	head_data := player.players_data[0]
	head_colision := &player.colliders[0]

	if try_set_dir(head_velocity, head_data.next_dir, head_direction) {

		player.players_data[0].previous_dir = head_direction
		if body.num_cells > 0 &&
		   head_data.next_dir != {0, 0} &&
		   head_data.next_dir != head_direction {

			put_cell(
				body.ghost_pieces,
				cell_ghost_t{head_position^, player.velocities[0].direction},
			)
			add_turn_count(body)

		}
	}
	if body.growing {
		distance: f32 = 0.0
		ghosts := body.ghost_pieces
		cap := MAX_RINGBUFFER_VALUES
		head_pos := head_position^
		tail_pos := body.cells[0].position
		turns_left := body.cells[0].count_turns_left

		if turns_left > 0 {
			ghost_head := int(ghosts.head) % cap
			first_ghost := ghosts.values[ghost_head]
			distance += vec2_distance(head_pos, first_ghost.position)

			for i := 1; i < int(turns_left); i += 1 {
				from := ghosts.values[(ghost_head + i - 1) % cap]
				to := ghosts.values[(ghost_head + i) % cap]
				distance += vec2_distance(from.position, to.position)
			}

			last_ghost := ghosts.values[(i8(ghost_head) + turns_left - 1) % i8(cap)]
			distance += vec2_distance(last_ghost.position, tail_pos)
		} else {
			distance = vec2_distance(head_pos, tail_pos)
		}

		fmt.println("Total body separation distance:", distance)
		if distance >= PLAYER_SIZE {
			body.growing = false
		}
	}

	// if body.growing {
	// 	fmt.println("GONNA STOP GROWING")
	// 	distance: f32 = 0
	// 	position_to_follow := head_position
	// 	fmt.println(body.cells[0])
	//
	// 	turns_left := body.cells[0].count_turns_left
	// 	fmt.println("TURNS_LEFT: ", turns_left)
	// 	if turns_left > 0 {
	// 		ghost_cell, _ := peek_head(body.ghost_pieces)
	// 		next_ghost := ghost_cell
	// 		distance += vec2_distance(ghost_cell.position, head_position^)
	//
	// 		fmt.println("DISTANCE", distance)
	// 		for i := 0; i < int(turns_left - 1); i += 1 {
	//
	// 			next_ghost =
	// 				game.player_body.ghost_pieces.values[(game.player_body.ghost_pieces.head + 1) % MAX_RINGBUFFER_VALUES]
	// 			distance += vec2_distance(next_ghost.position, ghost_cell.position)
	// 		}
	// 		distance += vec2_distance(next_ghost.position, head_position^)
	// 	} else {
	//
	// 		distance = vec2_distance(head_position^, body.cells[0].position)
	// 	}
	//
	// 	fmt.println(distance)
	// 	if distance >= PLAYER_SIZE {
	// 		body.growing = false
	// 		// if body.cells[0].count_turns_left >0{
	// 		// }
	// 	}
	// }


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
			if is_player {
				player_data := &arquetype.players_data[i]
				if !player_data.can_dash {
					player_data.time_on_dash += 1
				}

				if player_data.time_on_dash >= DASH_DURATION {
					velocities[i].speed = PLAYER_SPEED
					player_data.player_state = .NORMAL
					if player_data.time_on_dash >= RECOVER_DASH_TIME {
						player_data.can_dash = true
					}
				}
			}


			positions[i].pos += (velocities[i].direction * velocities[i].speed)
			colliders[i].position += (velocities[i].direction * velocities[i].speed)

		}
	}


	if head_direction != {0, 0} && !body.growing {
		for i in 0 ..< body.num_cells {
			piece_to_follow: cell_t

			moved := false
			if (body.cells[i].count_turns_left == 0) {
				piece_to_follow =
					(i == 0) ? cell_t{head_position^, head_direction, 0, PLAYER_SIZE} : body.cells[i - 1]
				body.cells[i].direction = piece_to_follow.direction

				// fmt.println("PIECE TO FOLLOW : ", piece_to_follow)
			} else {
				index :=
					(MAX_RINGBUFFER_VALUES +
						body.ghost_pieces.tail -
						body.cells[i].count_turns_left) %
					MAX_RINGBUFFER_VALUES

				following_ghost_piece := ghost_to_cell(body.ghost_pieces.values[index])
				// fmt.println("GHOST PIECEINFORMATION : ", following_ghost_piece)
				// fmt.println("body piece: ", body.cells[i])

				distance := vec2_distance(body.cells[i].position, following_ghost_piece.position)
				if distance < head_velocity.speed {
					if body.cells[i].position == following_ghost_piece.position {
						body.cells[i].direction = following_ghost_piece.direction
						body.cells[i].count_turns_left -= 1
					} else {
						body.cells[i].position = following_ghost_piece.position
						moved = true
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
				body.cells[i].position += body.cells[i].direction * head_velocity.speed
				// fmt.printfln("POSITION %v: %v", i, body.cells[i].position)
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
		velocity := Velocity{{0, 0}, 0}
		update_velocity := false
		if (arquetype.component_mask & COMPONENT_ID.VELOCITY) == .VELOCITY {
			update_velocity = true
		}

		for i in 0 ..< len(arquetype.entities_id) {
			if update_velocity {
				velocity = arquetype.velocities[i]
			}
			draw(positions[i], &animations[i], velocity)
		}
	}
}
