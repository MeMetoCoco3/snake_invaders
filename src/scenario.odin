package main
import "core:fmt"
import rl "vendor:raylib"

D_PLAYER_SIZE :: PLAYER_SIZE * 2

scene_t :: struct {
	scenario:       []Shape,
	entities:       []Entity,
	spawn_areas:    []Shape,
	count_entities: int,
	count_enemies:  int,
	count_candies:  int,
	count_bullets:  int,
	count_spawners: int,
	count_scenario: int,
}

SCENES :: enum {
	ONE,
}


load_scenario :: proc(scene_to_load: SCENES) -> ^scene_t {
	s := new(scene_t)

	colliders := make([]Shape, NUM_RECTANGLES_ON_SCENE)

	colliders_slice := [?]Shape {
		{{0, 0}, Rect{w = SCREEN_WIDTH, h = PLAYER_SIZE}},
		{{0, SCREEN_HEIGHT - PLAYER_SIZE}, Rect{w = SCREEN_WIDTH, h = PLAYER_SIZE}},
		{{0, 0}, Rect{w = PLAYER_SIZE, h = SCREEN_HEIGHT}},
		{{SCREEN_WIDTH - PLAYER_SIZE, 0}, Rect{w = PLAYER_SIZE, h = SCREEN_HEIGHT}},
	}

	spawn_areas := make([]Shape, NUM_RECTANGLES_ON_SCENE)
	spawn_areas_slice := []Shape {
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

	cnt: int
	for i in 0 ..< len(colliders_slice) {
		colliders[i] = colliders_slice[i]
		cnt += 1
	}

	s.count_scenario = cnt
	s.scenario = colliders

	cnt = 0
	for i in 0 ..< len(spawn_areas_slice) {
		spawn_areas[i] = spawn_areas_slice[i]
		cnt += 1
	}
	s.count_spawners = cnt
	s.spawn_areas = spawn_areas

	s.entities = make([]Entity, NUM_ENTITIES)
	s.count_entities = 0


	return s
}

clean_up :: proc(game: ^Game) {
	free(game.scene)
	unload_sounds()
	unload_textures()

	rl.UnloadMusicStream(game.audio.bg_music)


	rl.CloseAudioDevice()
	rl.CloseWindow()
}

get_rec_from_cell :: proc(a, b, c, d: int) -> Shape {
	x := a * PLAYER_SIZE
	y := c * PLAYER_SIZE

	w := (b * PLAYER_SIZE)
	h := (d * PLAYER_SIZE)

	return Shape{{f32(x), f32(y)}, Rect{w = f32(w), h = f32(h)}}
}
