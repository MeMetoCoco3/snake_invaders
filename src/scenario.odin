package main
import "core:fmt"
import rl "vendor:raylib"


SCENES :: enum {
	ONE,
}


load_scenario :: proc(game: ^Game, scene_to_load: SCENES) {
	world := game.world

	mask := COMPONENT_ID.COLLIDER | .SPRITE | .DATA | .POSITION

	add_entity(world, mask)
	arquetype := world.archetypes[mask]

	append(&arquetype.positions, Position{{0, 0}, {SCREEN_WIDTH, PLAYER_SIZE}})
	append(&arquetype.colliders, Collider{{0, 0}, SCREEN_WIDTH, PLAYER_SIZE})
	append(
		&arquetype.sprites,
		Sprite {
			&texture_bank[TEXTURE.TX_ENEMY],
			{SCREEN_WIDTH, PLAYER_SIZE},
			{SCREEN_WIDTH, PLAYER_SIZE},
		},
	)
	append(&arquetype.data, Data{.STATIC, .ALIVE, .NEUTRAL, .NORMAL})

	add_entity(world, mask)
	append(
		&arquetype.positions,
		Position{{0, SCREEN_HEIGHT - PLAYER_SIZE}, {SCREEN_WIDTH, PLAYER_SIZE}},
	)
	append(
		&arquetype.colliders,
		Collider{{0, SCREEN_HEIGHT - PLAYER_SIZE}, SCREEN_WIDTH, PLAYER_SIZE},
	)
	append(
		&arquetype.sprites,
		Sprite {
			&texture_bank[TEXTURE.TX_ENEMY],
			{SCREEN_WIDTH, PLAYER_SIZE},
			{SCREEN_WIDTH, PLAYER_SIZE},
		},
	)
	append(&arquetype.data, Data{.STATIC, .ALIVE, .NEUTRAL, .NORMAL})

	add_entity(world, mask)
	append(&arquetype.positions, Position{{0, 0}, {PLAYER_SIZE, SCREEN_HEIGHT}})
	append(&arquetype.colliders, Collider{{0, 0}, PLAYER_SIZE, SCREEN_HEIGHT})
	append(
		&arquetype.sprites,
		Sprite {
			&texture_bank[TEXTURE.TX_ENEMY],
			{PLAYER_SIZE, SCREEN_HEIGHT},
			{PLAYER_SIZE, SCREEN_HEIGHT},
		},
	)
	append(&arquetype.data, Data{.STATIC, .ALIVE, .NEUTRAL, .NORMAL})

	add_entity(world, mask)
	append(
		&arquetype.positions,
		Position{{SCREEN_WIDTH - PLAYER_SIZE, 0}, {PLAYER_SIZE, SCREEN_HEIGHT}},
	)
	append(
		&arquetype.colliders,
		Collider{{SCREEN_WIDTH - PLAYER_SIZE, 0}, PLAYER_SIZE, SCREEN_HEIGHT},
	)
	append(
		&arquetype.sprites,
		Sprite {
			&texture_bank[TEXTURE.TX_ENEMY],
			{PLAYER_SIZE, SCREEN_HEIGHT},
			{PLAYER_SIZE, SCREEN_HEIGHT},
		},
	)
	append(&arquetype.data, Data{.STATIC, .ALIVE, .NEUTRAL, .NORMAL})


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
	free(game)
	unload_sounds()
	unload_textures()

	rl.UnloadMusicStream(game.audio.bg_music)

	rl.CloseAudioDevice()
	rl.CloseWindow()
}

get_rec_from_cell :: proc(a, b, c, d: int) -> rl.Rectangle {
	x := a * PLAYER_SIZE
	y := c * PLAYER_SIZE

	w := (b * PLAYER_SIZE)
	h := (d * PLAYER_SIZE)

	return rl.Rectangle{f32(x), f32(y), f32(w), f32(h)}
}
