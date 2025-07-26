package main
import "core:fmt"
import "core:log"
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
			if arquetype.data[i].kind == .GHOST_PIECE {
				color = rl.WHITE
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
	rb := game.player_body.ghost_pieces
	arquetypesA, is_empty := query_archetype(
		game.world,
		COMPONENT_ID.COLLIDER | .DATA | .VELOCITY | .POSITION,
	)
	if is_empty {
		return
	}

	is_turning := false
	arquetypesB, _ := query_archetype(game.world, COMPONENT_ID.COLLIDER | .DATA | .POSITION)
	for archetypeA in arquetypesA {
		for i in 0 ..< len(archetypeA.entities_id) {
			colliderA := &archetypeA.colliders[i]
			dataA := &archetypeA.data[i]
			velocityA := &archetypeA.velocities[i]
			positionA := &archetypeA.positions[i]

			is_player := false
			colliderA_future_pos: Collider

			if dataA.kind == .PLAYER {
				is_player = true
				colliderA_future_pos = Collider {
					colliderA.position + archetypeA.players_data[i].next_dir * velocityA.speed,
					colliderA.h,
					colliderA.w,
					true,
				}
			} else {
				colliderA_future_pos = {
					colliderA.position + velocityA.direction * velocityA.speed,
					colliderA.h,
					colliderA.w,
					true,
				}
			}


			if dataA.kind == .PLAYER {

				player := game.world.archetypes[player_mask]
				body := &game.player_body
				head_position := &player.positions[i].pos
				head_direction := player.velocities[i].direction
				head_velocity := &player.velocities[i]
				head_data := &player.players_data[i]
				head_colision := &player.colliders[i]
				has_body := game.player_body.num_cells > 0 ? true : false

				is_player = true


				if is_move_allowed(
					head_velocity,
					head_data.next_dir,
					head_direction,
					head_data,
					game,
				) {
					if set_dir(
						game,
						head_velocity,
						head_data.next_dir,
						head_direction,
						head_data,
					) {
						last_dir_chosen, _ := peek_last(game.directions)

						actual_turn :=
							head_velocity.direction != {0, 0} &&
							head_velocity.direction != last_dir_chosen

						if actual_turn {
							is_turning = true
							head_data.time_since_turn = 0
							if has_body {
								put_cell(game.directions, head_velocity.direction)
							}
						} else {
							game.player_body.growing = true
						}
					}
				}
			}


			for archetypeB in arquetypesB {
				for j in 0 ..< len(archetypeB.entities_id) {
					dataB := &archetypeB.data[j]
					if dataB.state == .DEAD || dataB == dataA || dataB.kind == .PLAYER do continue

					colliderB := &archetypeB.colliders[j]
					positionB := &archetypeB.positions[j]

					switch dataB.kind {
					case .CANDY:
						if is_player &&
						   dataB.state != .DEAD &&
						   collide_no_edges(colliderB^, colliderA^) {
							dataB.state = .DEAD
							add_sound(game, &sound_bank[FX.FX_EAT])
							game.count_candies -= 1

							if MAX_NUM_BODY - 1 > game.player_body.num_cells {
								game.player_data.cells_to_grow += 1
							}
						}

					case .STATIC:
						if collide(colliderB^, colliderA_future_pos) {
							if is_player {
								velocityA.direction = {0, 0}
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
							player_data := &archetypeA.players_data[i]
							switch player_data.player_state {
							case .NORMAL:
								if player_data.time_since_dmg > RECOVER_DMG_TIME {
									player_data.health -= 1
									player_data.time_since_dmg = 0

									if player_data.health <= 0 {
										game.state = .DEAD
									}
								}

							case .DASH:
								fmt.println("WE EAT")
								dataB.state = .DEAD
								add_sound(game, &sound_bank[FX.FX_EAT])

								game.player_data.cells_to_grow += 1
								// TODO: WHY IS THIS HERE? 
								// archetypeA.players_data[i].distance = 0
								game.count_enemies -= 1
							}
						}

					case .BULLET:
						if dataA.team == dataB.team {
							continue
						}

						are_colliding := collide(colliderB^, colliderA^)

						if are_colliding {
							if dataB.team == .BAD && is_player {
								player_data := &archetypeA.players_data[i]
								if player_data.time_since_dmg > RECOVER_DMG_TIME {
									player_data.health -= 1
									player_data.time_since_dmg = 0

									if player_data.health <= 0 {
										game.state = .DEAD
									}
								}

							} else if dataB.team == .GOOD && !is_player {
								dataA.state = .DEAD
								dataB.state = .DEAD
							}
						}

					case .PLAYER:
						continue

					case .BODY:
						colliderB_future_pos := Collider {
							colliderB.position +
							archetypeB.velocities[j].direction * velocityA.speed,
							colliderB.h,
							colliderB.w,
							true,
						}

						// if collide_no_edges(colliderB_future_pos, colliderA_future_pos) {

						if collide_no_edges(colliderB^, colliderA_future_pos) {
							if is_player {
								if (archetypeB.players_data[j].body_index > 1) {
									fmt.println("WE COLLIDE WITH BODY")
									velocityA.direction = {0, 0}
									continue
								} else {
									continue
								}
							}

							is_bullet := dataA.kind == .BULLET
							if is_bullet {
								dataA.state = .DEAD
							}
							velocityA.direction = {0, 0}
						}

					case .GHOST_PIECE:
						if collide_no_edges(colliderB^, colliderA_future_pos) {
							if is_player {
								if (archetypeB.players_data[j].body_index > 2) &&
								   archetypeB.data[j].state == .ALIVE &&
								   archetypeB.colliders[j].active {

									velocityA.direction = {0, 0}
									continue
								} else {
									continue
								}
							}

							is_bullet := dataA.kind == .BULLET
							if is_bullet {
								dataA.state = .DEAD
							}
						} else if !archetypeB.colliders[j].active && is_player {
							distance := vec2_distance(
								colliderB.position,
								colliderA_future_pos.position,
							)
							if distance >= PLAYER_SIZE {
								colliderB.active = true
							}
						}


					}
				}
			}
			// head_position := game.player_position.pos
			// head_velocity := game.player_velocity
			// body := &game.player_body
			// player := game.world.archetypes[player_mask]
			// future_head_pos := head_position + head_velocity.direction * head_velocity.speed
		}
	}

	if is_turning {
		body := game.player_body
		head_pos := game.player_position.pos
		index_prev_dir :=
			(MAX_RINGBUFFER_VALUES + game.directions.tail - 2) % MAX_RINGBUFFER_VALUES

		prev_dir := game.directions.values[index_prev_dir]
		curr_dir := game.player_velocity.direction
		continuous_dir := prev_dir == curr_dir

		if body.num_cells > 0 && !continuous_dir {
			rotation: f32 = 90
			from_dir := game.player_velocity.direction
			to_dir := get_cardinal_direction(head_pos, body.first_cell_pos.pos)

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
			}
			future_head_pos :=
				head_pos + game.player_velocity.direction * game.player_velocity.speed
			if body.first_cell_data.count_turn_left > 0 {
				ghost, ok := peek_head(body.ghost_pieces)
				if aligned_vectors(ghost.position, game.player_position.pos, future_head_pos) {
					return
				}
			}
			spawn_ghost_cell(game, head_pos, from_dir, rotation)
		}
	}
}

spawn_ghost_cell :: proc(game: ^Game, head_pos, from_dir: Vector2, rotation: f32) {
	entity_id := add_entity(
		game.world,
		ghost_mask,
		[]Component {
			Position{pos = head_pos, size = {PLAYER_SIZE, PLAYER_SIZE}},
			Data{kind = .GHOST_PIECE, state = .ALIVE, team = .GOOD},
			PlayerData{player_state = .NORMAL, count_turn_left = 0, body_index = -1},
			Collider{position = head_pos, w = PLAYER_SIZE, h = PLAYER_SIZE, active = false},
		},
	)

	archetype := game.world.archetypes[ghost_mask]

	if game.player_body.ghost_colliders == nil {
		game.player_body.ghost_colliders = &archetype.colliders
	}

	put_cell(
		game.player_body.ghost_pieces,
		cell_ghost_t{entity_id, 0, head_pos, from_dir, rotation},
	)

	add_turn_count(game.world)
	add_ghost_body_index(game.world)

	index := len(game.world.archetypes[ghost_mask].entities_id) - 1
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

	head_position := game.player_position
	head_direction := game.player_velocity.direction
	head_velocity := game.player_velocity
	head_data := game.player_data

	arquetypes, is_empty := query_archetype(
		game.world,
		COMPONENT_ID.VELOCITY | COMPONENT_ID.POSITION | COMPONENT_ID.COLLIDER | .DATA,
	)

	if is_empty {
		return
	}

	head_direction = game.player_velocity.direction
	if body.growing && head_direction != {0, 0} {
		distance := head_data.distance

		if distance >= PLAYER_SIZE {
			body.growing = false
		} else {
			body.growing = true
		}
	}

	move_player(game)
	START_SPEED := game.player_velocity.speed

	for arquetype in arquetypes {
		velocities := arquetype.velocities
		positions := arquetype.positions
		colliders := arquetype.colliders

		for i in 0 ..< len(arquetype.entities_id) {
			switch arquetype.data[i].kind {
			case .PLAYER:
				colliders[i].position = game.player_position.pos
			case .BODY:
				curr_cell_pos := &positions[i]
				curr_cell_data := &arquetype.players_data[i]
				curr_cell_velocity := &velocities[i]
				collider_pos := &colliders[i].position

				is_tail := curr_cell_data.body_index == int(game.player_body.num_cells - 1)
				is_neck := curr_cell_data.body_index == 0
				// IDEA: IF NEXT POS == PREV POS, BREAK
				if head_direction != {0, 0} && !body.growing {
					remaining_movement := head_velocity.speed
					for remaining_movement > 0 {
						piece_to_follow: cell_t
						ghost_index_being_followed: int

						set_piece_to_follow(
							game.player_body.ghost_pieces,
							curr_cell_data.count_turn_left,
							head_position.pos,
							head_direction,
							&piece_to_follow,
							&ghost_index_being_followed,
						)

						direction := get_cardinal_direction(
							curr_cell_pos.pos,
							piece_to_follow.position,
						)
						distance_left := vec2_distance(curr_cell_pos.pos, piece_to_follow.position)
						if distance_left <= remaining_movement {
							fmt.println(distance_left, remaining_movement)

							curr_cell_pos.pos = piece_to_follow.position
							curr_cell_velocity.direction = piece_to_follow.direction
							remaining_movement -= distance_left

							collider_pos^ = curr_cell_pos.pos

							if ghost_index_being_followed >= 0 {
								curr_cell_data.count_turn_left -= 1
								if is_tail {
									dealing_ghost_piece(game, body, i8(curr_cell_data.body_index))
								}
							}

						} else {
							curr_cell_velocity.direction = direction
							curr_cell_pos.pos += direction * remaining_movement

							collider_pos^ = curr_cell_pos.pos

							if curr_cell_data.body_index == int(game.player_body.num_cells - 1) &&
							   ghost_index_being_followed >= 0 {
								_, done := dealing_ghost_piece(
									game,
									body,
									i8(curr_cell_data.body_index),
								)
								if done {
									curr_cell_data.count_turn_left -= 1
								}
							}
							is_not_ghost := ghost_index_being_followed == -1
							distance := vec2_distance(curr_cell_pos.pos, piece_to_follow.position)
							if is_not_ghost && distance > PLAYER_SIZE && is_neck {
								fmt.printfln(
									"CURR CELL %v FOLLLOWING %v DISTANCE %v",
									curr_cell_pos.pos,
									piece_to_follow.position,
									distance,
								)
								fmt.println()
							}
							remaining_movement -= distance_left
						}
					}
				}

			case .BULLET, .ENEMY:
				vector_move := (velocities[i].direction * velocities[i].speed)
				positions[i].pos += vector_move
				colliders[i].position += vector_move
				continue
			case .CANDY, .STATIC, .GHOST_PIECE:
				continue
			}
		}
	}
	assert(START_SPEED == game.player_velocity.speed)
}


move_player :: proc(game: ^Game) {
	player_data := &game.player_data
	speed := &game.player_velocity.speed
	position := &game.player_position.pos
	dir := &game.player_velocity.direction

	if player_data^.time_on_dash >= DASH_DURATION {
		speed^ = PLAYER_SPEED
		player_data^.player_state = .NORMAL
	}

	vector_move := (dir^ * speed^)
	if !player_data^.can_dash {
		player_data^.time_on_dash += 1

		if player_data^.time_on_dash >= RECOVER_DASH_TIME {
			player_data^.can_dash = true
		}
	}


	player_data^.distance += abs(vector_move.x + vector_move.y)
	player_data^.time_since_turn += int(abs(vector_move.x + vector_move.y))

	position^ += vector_move

}

import os "core:os/os2"
breakpoint :: proc() {
	buffer: [1]u8
	os.read(os.stdin, buffer[:])
	fmt.println("JAMON")
}

RenderingSystem :: proc(game: ^Game) {
	arquetypes, is_empty := query_archetype(game.world, COMPONENT_ID.POSITION | .SPRITE)
	if !is_empty {
		for arquetype in arquetypes {
			positions := arquetype.positions
			sprites := arquetype.sprites
			for i in 0 ..< len(arquetype.entities_id) {
				kind := arquetype.data[i].kind
				pos := positions[i]
				rotation := sprites[i].rotation

				if kind == .BODY {
					rl.DrawRectangle(
						i32(positions[i].pos.x),
						i32(positions[i].pos.y),
						PLAYER_SIZE,
						PLAYER_SIZE,
						rl.ORANGE,
					)
					pos.pos += pos.size / 2
					direction := arquetype.velocities[i].direction
					if direction != {0, 0} {
						rotation = 90 + angle_from_vector(direction)
					}
				}
				sprites[i].rotation = rotation
				draw(sprites[i], pos)


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

				color := rl.WHITE
				if is_player && arquetype.players_data[i].time_since_dmg < RECOVER_DMG_TIME {
					color = rl.RED
				}

				draw(positions[i], &animations[i], direction, team[i].team, color)
			}
		}
	}
}


set_piece_to_follow :: proc(
	ghosts: ^Ringuffer_t(cell_ghost_t),
	turns_left: int,
	head_pos, head_dir: Vector2,
	piece_to_follow: ^cell_t,
	ghost_index_being_followed: ^int,
) {
	if turns_left == 0 {
		piece_to_follow^ = cell_t{head_pos, head_dir, 0, PLAYER_SIZE, {}}
		ghost_index_being_followed^ = -1
	} else {
		ghost_index_being_followed^ =
			(MAX_RINGBUFFER_VALUES + int(ghosts.tail) - turns_left) % MAX_RINGBUFFER_VALUES
		piece_to_follow^ = ghost_to_cell(ghosts.values[ghost_index_being_followed^])
	}
}


angle_from_vector :: proc(v0: Vector2) -> f32 {
	return math.atan2(v0.y, v0.x) * (180.0 / math.PI)

}
