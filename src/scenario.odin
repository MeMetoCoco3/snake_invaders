package main
import "core:fmt"
import rl "vendor:raylib"


SCENES :: enum {
	ONE,
}

BORDER_SIZE :: 128

load_scenario :: proc(game: ^Game, scene_to_load: SCENES) {
	world := game.world

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

CleanUp :: proc(game: ^Game) {
	FreeAllEntities(game)
	fmt.println("AFTER FREE GAME")
	UnloadSounds()
	UnloadTextures()

	rl.UnloadMusicStream(game.audio.bg_music)

	delete_logger(context.logger)

	rl.CloseAudioDevice()
	rl.CloseWindow()
}

FreeAllEntities :: proc(game: ^Game) {
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
