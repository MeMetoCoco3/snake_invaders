package main
import "core:fmt"


D_PLAYER_SIZE :: PLAYER_SIZE * 2

scene_t :: struct {
	scenario:       []rectangle,
	entities:       []Entity,
	spawn_areas:    []rectangle,
	count_entities: int,
	count_enemies:  int,
	count_candies:  int,
	count_bullets:  int,
	count_spawners: int,
}


scene :: proc(s: SCENES) -> ^scene_t {
	s := new(scene_t)

	colliders := make([]rectangle, NUM_RECTANGLES_ON_SCENE)

	colliders_slice := []rectangle {
		{position = {0, 0}, w = SCREEN_WIDTH, h = PLAYER_SIZE},
		{position = {0, SCREEN_HEIGHT - PLAYER_SIZE}, w = SCREEN_WIDTH, h = PLAYER_SIZE},
		{position = {0, 0}, w = PLAYER_SIZE, h = SCREEN_HEIGHT},
		{position = {SCREEN_WIDTH - PLAYER_SIZE, 0}, w = PLAYER_SIZE, h = SCREEN_HEIGHT},
	}


	spawn_areas := make([]rectangle, NUM_RECTANGLES_ON_SCENE)
	spawn_areas_slice := []rectangle {
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

	for i in 0 ..< len(colliders_slice) {
		colliders[i] = colliders_slice[i]
	}
	s.scenario = colliders


	cnt: int
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


get_rec_from_cell :: proc(a, b, c, d: int) -> rectangle {
	x := a * PLAYER_SIZE
	y := c * PLAYER_SIZE

	w := (b * PLAYER_SIZE)
	h := (d * PLAYER_SIZE)

	return rectangle{position = {f32(x), f32(y)}, w = f32(w), h = f32(h)}
}
