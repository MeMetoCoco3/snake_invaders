package main
import "core:fmt"
import rl "vendor:raylib"


SCENES :: enum {
	ONE,
}

BORDER_SIZE :: 128

load_scenario :: proc(game: ^Game, scene_to_load: SCENES) {
	world := game.world

	id := add_entity(
		world,
		mask_static,
		[]Component {
			Position{{SCREEN_WIDTH / 2, BORDER_SIZE / 2}, {BORDER_SIZE, SCREEN_WIDTH}},
			Collider{{0, 0}, SCREEN_WIDTH, PLAYER_SIZE, true},
			Sprite{&atlas, Rect{{0, 96}, {32, 32}}, 90},
			Data{.STATIC, .ALIVE, .NEUTRAL},
		},
	)

	arquetype := world.archetypes[mask_static]

	id = add_entity(
		world,
		mask_static,
		[]Component {
			Position {
				{SCREEN_WIDTH / 2, SCREEN_HEIGHT - BORDER_SIZE / 2},
				{BORDER_SIZE, SCREEN_WIDTH},
			},
			Collider{{SCREEN_WIDTH, SCREEN_HEIGHT - PLAYER_SIZE}, SCREEN_WIDTH, PLAYER_SIZE, true},
			Sprite{&atlas, Rect{{0, 96}, {32, 32}}, 270},
			Data{.STATIC, .ALIVE, .NEUTRAL},
		},
	)

	id = add_entity(
		world,
		mask_static,
		[]Component {
			Position{{BORDER_SIZE / 2, SCREEN_WIDTH / 2}, {BORDER_SIZE, SCREEN_HEIGHT}},
			Collider{{0, 0}, PLAYER_SIZE, SCREEN_HEIGHT, true},
			Sprite{&atlas, Rect{{0, 96}, {32, 32}}, 0},
			Data{.STATIC, .ALIVE, .NEUTRAL},
		},
	)

	id = add_entity(
		world,
		mask_static,
		[]Component {
			Position {
				{SCREEN_WIDTH - BORDER_SIZE / 2, SCREEN_HEIGHT / 2},
				{BORDER_SIZE, SCREEN_HEIGHT},
			},
			Collider{{SCREEN_WIDTH - PLAYER_SIZE, 0}, PLAYER_SIZE, SCREEN_HEIGHT, true},
			Sprite{&atlas, Rect{{0, 96}, {32, 32}}, 180},
			Data{.STATIC, .ALIVE, .NEUTRAL},
		},
	)

	// CORNERS
	id = add_entity(
		world,
		mask_static,
		[]Component {
			Position{{128 / 2, 128 / 2}, {128, 128}},
			Sprite{&atlas, Rect{{32, 96}, {32, 32}}, 0},
			Collider{},
			Data{.STATIC, .ALIVE, .NEUTRAL},
		},
	)
	id = add_entity(
		world,
		mask_static,
		[]Component {
			Position{{SCREEN_WIDTH - 128 / 2, 128 / 2}, {128, 128}},
			Sprite{&atlas, Rect{{32, 96}, {32, 32}}, 90},
			Collider{},
			Data{.STATIC, .ALIVE, .NEUTRAL},
		},
	)
	id = add_entity(
		world,
		mask_static,
		[]Component {
			Position{{SCREEN_WIDTH - 128 / 2, SCREEN_HEIGHT - 128 / 2}, {128, 128}},
			Sprite{&atlas, Rect{{32, 96}, {32, 32}}, 180},
			Collider{},
			Data{.STATIC, .ALIVE, .NEUTRAL},
		},
	)
	id = add_entity(
		world,
		mask_static,
		[]Component {
			Position{{128 / 2, SCREEN_HEIGHT - 128 / 2}, {128, 128}},
			Sprite{&atlas, Rect{{32, 96}, {32, 32}}, 270},
			Collider{},
			Data{.STATIC, .ALIVE, .NEUTRAL},
		},
	)

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

	delete_logger(context.logger)

	rl.CloseAudioDevice()
	rl.CloseWindow()
}

free_all_entities :: proc(game: ^Game) {
	for _, archetype in game.world.archetypes {
		mask := archetype.component_mask
		clear(&archetype.entities_id)
		for component in COMPONENT_ID {
			if (component & mask) == component {
				switch component {
				case .POSITION:
					clear(&archetype.positions)
				case .VELOCITY:
					clear(&archetype.velocities)
				case .SPRITE:
					clear(&archetype.sprites)
				case .ANIMATION:
					clear(&archetype.animations)
				case .DATA:
					clear(&archetype.data)
				case .COLLIDER:
					clear(&archetype.colliders)
				case .IA:
					clear(&archetype.ias)
				case .PLAYER_DATA:
					clear(&archetype.players_data)
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
