package main

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
					if dataB.state == .DEAD || dataB == dataA {
						continue
					}

					colliderB := &archetypeB.colliders[j]
					positionB := &archetypeB.positions[j]

					switch dataB.kind {
					case .CANDY:
						center_candy :=
							colliderB.position + ({f32(colliderB.w), f32(colliderB.h)} / 2)
						if vec2_distance(centerA, center_candy) + EPSILON_COLISION < PLAYER_SIZE &&
						   dataB.state != .DEAD &&
						   is_player {

							add_sound(game, &sound_bank[FX.FX_EAT])
							grow_body(game.player)

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
								grow_body(game.player)
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

	center_player := game.player.position + PLAYER_SIZE / 2

	for arquetype in arquetypes {
		velocities := arquetype.velocities
		positions := arquetype.positions
		ias := arquetype.ias

		for i in 0 ..< len(arquetype.entities_id) {
			center_enemy := positions[i].position + ENEMY_SIZE / 2
			distance_to_player := vec2_distance(center_player, center_enemy)
			if ias[i]._time_for_change_state > TIME_TO_CHANGE_STATE {
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

			if ias[i].behavior == .SHOT {
				velocities[i].direction = {0, 0}
				if ias[i].reload_time >= ENEMY_TIME_RELOAD {
					spawn_bullet(game, positions[i].position, ENEMY_SIZE_BULLET, direction, .BAD)
					ias[i].reload_time = 0
				} else {
					ias[i].reload_time += 1
				}
			}

		}
	}
}


VelocitySystem :: proc(game: ^Game) {
	arquetypes, is_empty := query_archetype(
		game.world,
		COMPONENT_ID.VELOCITY | COMPONENT_ID.POSITION,
	)
	if is_empty {
		return
	}

	for arquetype in arquetypes {
		velocities := arquetype.velocities
		positions := arquetype.positions

		for i in 0 ..< len(arquetype.entities_id) {
			positions[i].position += (velocities[i].direction * velocities[i].speed)
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

	arquetypes, is_empty = query_archetype(
		game.world,
		COMPONENT_ID.POSITION | .ANIMATION | .VELOCITY,
	)
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
