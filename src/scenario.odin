package main
import "core:fmt"
import rl "vendor:raylib"


SCENES :: enum {
	ONE,
}

BORDER_SIZE :: 128

load_scenario :: proc(game: ^Game, scene_to_load: SCENES) {
	world := game.world

	mask := COMPONENT_ID.COLLIDER | .SPRITE | .DATA | .POSITION

	add_entity(world, mask)
	arquetype := world.archetypes[mask]

	append(
		&arquetype.positions,
		Position{{SCREEN_WIDTH / 2, BORDER_SIZE / 2}, {BORDER_SIZE, SCREEN_WIDTH}},
	)

	append(&arquetype.colliders, Collider{{0, 0}, SCREEN_WIDTH, PLAYER_SIZE})
	append(&arquetype.sprites, Sprite{&atlas, Rect{{0, 96}, {32, 32}}, 90})

	append(&arquetype.data, Data{.STATIC, .ALIVE, .NEUTRAL})

	add_entity(world, mask)
	append(
		&arquetype.positions,
		Position {
			{SCREEN_WIDTH / 2, SCREEN_HEIGHT - BORDER_SIZE / 2},
			{BORDER_SIZE, SCREEN_HEIGHT},
		},
	)
	append(
		&arquetype.colliders,
		Collider{{SCREEN_WIDTH, SCREEN_HEIGHT - PLAYER_SIZE}, SCREEN_WIDTH, PLAYER_SIZE},
	)
	append(&arquetype.sprites, Sprite{&atlas, Rect{{0, 96}, {32, 32}}, 270})
	append(&arquetype.data, Data{.STATIC, .ALIVE, .NEUTRAL})

	add_entity(world, mask)

	append(
		&arquetype.positions,
		Position{{BORDER_SIZE / 2, SCREEN_WIDTH / 2}, {BORDER_SIZE, SCREEN_HEIGHT}},
	)
	append(&arquetype.colliders, Collider{{0, 0}, PLAYER_SIZE, SCREEN_HEIGHT})
	append(&arquetype.sprites, Sprite{&atlas, Rect{{0, 96}, {32, 32}}, 0})

	append(&arquetype.data, Data{.STATIC, .ALIVE, .NEUTRAL})

	add_entity(world, mask)
	append(
		&arquetype.positions,
		Position{{SCREEN_WIDTH - BORDER_SIZE / 2, SCREEN_WIDTH / 2}, {BORDER_SIZE, SCREEN_HEIGHT}},
	)
	append(
		&arquetype.colliders,
		Collider{{SCREEN_WIDTH - PLAYER_SIZE, 0}, PLAYER_SIZE, SCREEN_HEIGHT},
	)
	append(
		&arquetype.sprites,
		Sprite{&atlas, Rect{{0, 96}, {32, 32}}, 180},

		// Sprite{&atlas, Rect{{0, 96}, {32, 32}}, Rect{{672 + 128 / 2, 800 / 2}, {128, 800}}, 180},
	)
	append(&arquetype.data, Data{.STATIC, .ALIVE, .NEUTRAL})


	// CORNERS
	add_entity(world, mask)
	append(&arquetype.positions, Position{{0, SCREEN_HEIGHT - PLAYER_SIZE}, {32, 32}})
	append(
		&arquetype.colliders,
		Collider{{0, SCREEN_HEIGHT - PLAYER_SIZE}, SCREEN_WIDTH, PLAYER_SIZE},
	)
	append(
		&arquetype.sprites,
		Sprite {
			&atlas,
			Rect{{32, 96}, {32, 32}},
			// Rect{{800 - 128 / 2, 0 + 128 / 2}, {128, 128}},
			90,
		},
	)
	append(&arquetype.data, Data{.STATIC, .ALIVE, .NEUTRAL})


	add_entity(world, mask)
	append(&arquetype.positions, Position{{0, SCREEN_HEIGHT - PLAYER_SIZE}, {32, 32}})
	append(
		&arquetype.colliders,
		Collider{{0, SCREEN_HEIGHT - PLAYER_SIZE}, SCREEN_WIDTH, PLAYER_SIZE},
	)
	append(
		&arquetype.sprites,
		Sprite{&atlas, Rect{{32, 96}, {32, 32}}, 0},
		// Rect{{0 + 128 / 2, 0 + 128 / 2}, {128, 128}},
	)
	append(&arquetype.data, Data{.STATIC, .ALIVE, .NEUTRAL})


	add_entity(world, mask)
	append(&arquetype.positions, Position{{0, SCREEN_HEIGHT - PLAYER_SIZE}, {32, 32}})
	append(
		&arquetype.colliders,
		Collider{{0, SCREEN_HEIGHT - PLAYER_SIZE}, SCREEN_WIDTH, PLAYER_SIZE},
	)
	append(
		&arquetype.sprites,
		Sprite {
			&atlas,
			Rect{{32, 96}, {32, 32}},

			// Rect{{800 - 128 / 2, 800 - 128 / 2}, {128, 128}},
			180,
		},
	)
	append(&arquetype.data, Data{.STATIC, .ALIVE, .NEUTRAL})


	add_entity(world, mask)
	append(&arquetype.positions, Position{{0, SCREEN_HEIGHT - PLAYER_SIZE}, {32, 32}})
	append(
		&arquetype.colliders,
		Collider{{0, SCREEN_HEIGHT - PLAYER_SIZE}, SCREEN_WIDTH, PLAYER_SIZE},
	)
	append(
		&arquetype.sprites,
		Sprite {
			&atlas,
			Rect{{32, 96}, {32, 32}},
			// Rect{{0 + 128 / 2, 800 - 128 / 2}, {128, 128}},
			270,
		},
	)
	append(&arquetype.data, Data{.STATIC, .ALIVE, .NEUTRAL})


	spawn_areas := make([]rl.Rectangle, NUM_RECTANGLES_ON_SCENE)
	spawn_areas_slice := [?]rl.Rectangle {
		get_rec_from_cell(10, (SCREEN_WIDTH / PLAYER_SIZE) - 20, 2, 2),
		get_rec_from_cell(
			10,
			(SCREEN_WIDTH / PLAYER_SIZE) - 20,
			(SCREEN_HEIGHT / PLAYER_SIZE) - 4,
			2,
		),
		get_rec_from_cell(2, 2, 10, (SCREEN_HEIGHT / PLAYER_SIZE) - 20),
		get_rec_from_cell(
			(SCREEN_WIDTH / PLAYER_SIZE) - 4,
			2,
			10,
			(SCREEN_HEIGHT / PLAYER_SIZE) - 20,
		),
	}

	cnt := 0
	for i in 0 ..< len(spawn_areas_slice) {
		spawn_areas[i] = spawn_areas_slice[i]
		cnt += 1
	}

	game.spawn_areas = spawn_areas
	game.count_spawn_areas = cnt
}

clean_up :: proc(game: ^Game) {
	free_all_entities(game)
	fmt.println("AFTER FREE GAME")
	unload_sounds()
	unload_textures()

	rl.UnloadMusicStream(game.audio.bg_music)

	rl.CloseAudioDevice()
	rl.CloseWindow()
}

free_all_entities :: proc(game: ^Game) {
	for _, archetype in game.world.archetypes {
		mask := archetype.component_mask
		for component in COMPONENT_ID {
			if (component & mask) == component {
				switch component {
				case .POSITION:
					delete(archetype.positions)
				case .VELOCITY:
					delete(archetype.velocities)
				case .SPRITE:
					delete(archetype.sprites)
				case .ANIMATION:
					delete(archetype.animations)
				case .DATA:
					delete(archetype.data)
				case .COLLIDER:
					delete(archetype.colliders)
				case .IA:
					delete(archetype.ias)
				case .PLAYER_DATA:
					delete(archetype.players_data)
				case .COUNT:
				}
			}
		}
	}


}

get_rec_from_cell :: proc(a, b, c, d: int) -> rl.Rectangle {
	x := a * PLAYER_SIZE
	y := c * PLAYER_SIZE

	w := (b * PLAYER_SIZE)
	h := (d * PLAYER_SIZE)

	return rl.Rectangle{f32(x), f32(y), f32(w), f32(h)}
}
