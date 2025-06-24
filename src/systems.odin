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

			if dataA.kind == .PLAYER {
				is_player = true
			}

			centerA := Vector2 {
				colliderA.position.x - f32(colliderA.w),
				colliderA.position.y - f32(colliderA.h),
			}

			future_pos := Vector2 {
				colliderA.position.x + velocityA.direction.x,
				colliderA.position.y + velocityA.direction.y,
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
						center_candy :=
							colliderB.position + ({f32(colliderB.w), f32(colliderB.h)} / 2)
						if is_player {
							fmt.println(vec2_distance(centerA, center_candy))
						}
						if is_player &&
						   vec2_distance(centerA, center_candy) + EPSILON_COLISION < PLAYER_SIZE &&
						   dataB.state != .DEAD {
							fmt.println("WE EAT")
							dataB.state = .DEAD
							add_sound(game, &sound_bank[FX.FX_EAT])
							// grow_body(game.player)

						}

					case .STATIC:
						if rec_colliding_no_edges(
							colliderB.position,
							f32(colliderB.w),
							f32(colliderB.h),
							future_pos,
							f32(colliderA.w),
							f32(colliderA.h),
						) {
							velocityA.direction = Vector2{0, 0}
						}

					case .ENEMY:
						center_enemy :=
							colliderB.position + ({f32(colliderB.w), f32(colliderB.h)} / 2)
						distance := vec2_distance(centerA, center_enemy)
						direction := (centerA - center_enemy) / distance

						sum_radius := (PLAYER_SIZE / 2 + ENEMY_SIZE / 2) - EPSILON_COLISION

						if is_player && distance < f32(sum_radius) && dataA.state != .DEAD {
							switch dataA.player_state {
							case .NORMAL:
								game.state = .DEAD
								break
							case .DASH:
								dataA.state = .DEAD
								add_sound(game, &sound_bank[FX.FX_EAT])
								// grow_body(game.player)
								continue
							}
						}

					case .BULLET:
						center_bullet :=
							colliderB.position + ({f32(colliderB.w), f32(colliderB.h)} / 2)
						sum_radius_player := (BULLET_SIZE / 2 + PLAYER_SIZE / 2) - EPSILON_COLISION
						are_colliding :=
							vec2_distance(center_bullet, centerA) <= f32(sum_radius_player)

						if dataB.team == .BAD && is_player {
							if are_colliding {
								game.state = .DEAD
							}
						} else if dataB.team == .GOOD && !is_player {
							if are_colliding {
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

	if aligned_to_grid(head_position^) {
		if try_set_dir(head_velocity, head_data.next_dir, head_direction) &&
		   body.num_cells > 0 &&
		   head_direction != {0, 0} {
			put_cell(body.ghost_pieces, cell_ghost_t{head_position^, head_direction})
			add_turn_count(body)
		}
	}

	head_position^ += head_velocity.direction * f32(head_velocity.speed)
	head_colision.position += head_velocity.direction * f32(head_velocity.speed)

	if head_direction != {0, 0} && !body.growing {
		for i in 0 ..< body.num_cells {
			piece_to_follow: cell_t
			if (body.cells[i].count_turns_left == 0) {
				piece_to_follow =
					(i == 0) ? cell_t{head_position^, head_direction, 0, PLAYER_SIZE} : body.cells[i - 1]
				body.cells[i].direction = piece_to_follow.direction
			} else {
				index :=
					(MAX_RINGBUFFER_VALUES +
						body.ghost_pieces.tail -
						body.cells[i].count_turns_left) %
					MAX_RINGBUFFER_VALUES

				following_ghost_piece := ghost_to_cell(body.ghost_pieces.values[index])

				if (body.cells[i].position == following_ghost_piece.position) {
					body.cells[i].direction = following_ghost_piece.direction
					body.cells[i].count_turns_left -= 1
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
			body.cells[i].position += body.cells[i].direction * f32(head_velocity.speed)
		}


		if body.num_cells > 0 && body.growing {
			distance: f32
			if body.cells[0].count_turns_left > 0 {
				ghost_cell, _ := peek_tail(body.ghost_pieces)
				distance += vec2_distance(body.cells[0].position, ghost_cell.position)
				distance += vec2_distance(head_position^, ghost_cell.position)
			} else {
				distance = vec2_distance(head_position^, body.cells[0].position)
			}

			if distance >= PLAYER_SIZE {body.growing = false}
		}


		if !head_data.can_dash {
			head_data.time_on_dash += 1
		}

		if head_data.time_on_dash >= DASH_DURATION {
			head_velocity.speed = PLAYER_SPEED
			head_data.player_state = .NORMAL
			if head_data.time_on_dash >= RECOVER_DASH_TIME {
				head_data.can_dash = true
			}
		}
	}

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
		data := arquetype.data
		if data[0].kind == .PLAYER {
			continue
		}


		for i in 0 ..< len(arquetype.entities_id) {
			positions[i].pos += (velocities[i].direction * velocities[i].speed)
			colliders[i].position += (velocities[i].direction * velocities[i].speed)
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
			draw(positions[i], sprites[i])
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
