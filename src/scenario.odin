package main
import "core:fmt"

NUM_RECTANGLES_ON_SCENE :: 100
NUM_ENTITIES :: 1000

Entity :: struct {
	position:  vec2_t,
	direction: vec2_t,
	w:         f32,
	h:         f32,
	kind:      KIND,
	speed:     f32,
}

SCENES :: enum {
	ONE,
}

rectangle :: struct {
	position: vec2_t,
	w, h:     f32,
}

scene_t :: struct {
	scenario:       []rectangle,
	entities:       []Entity,
	count_entities: int,
	count_candies:  int,
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
	cnt := 0
	for i in 0 ..< len(colliders_slice) {
		colliders[i] = colliders_slice[i]
		cnt += 1
	}

	s.scenario = colliders
	s.entities = make([]Entity, NUM_ENTITIES)
	s.count_entities = 0
	return s
}
