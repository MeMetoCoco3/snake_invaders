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
	state:     STATE,
	shape:     SHAPE,
}


SCENES :: enum {
	ONE,
}

SHAPE :: enum {
	CIRCLE,
	RECTANGLE,
	SQUARE,
}


rectangle :: struct {
	position: vec2_t,
	w, h:     f32,
}


KIND :: enum {
	STATIC,
	BULLET,
	CANDY,
	ENEMY,
}

STATE :: enum {
	DEAD,
	ALIVE,
}

vec2_t :: struct {
	x, y: f32,
}


cell_t :: struct {
	position, direction: vec2_t,
	count_turns_left:    i8,
	size:                i8,
}

cell_ghost_t :: struct {
	position, direction: vec2_t,
}


Player :: struct {
	head:                  cell_t,
	next_dir:              vec2_t,
	body:                  [MAX_NUM_BODY]cell_t,
	health:                i8,
	num_cells:             i8,
	num_ghost_pieces:      i8,
	ghost_pieces:          ^Ringuffer_t,
	rotation:              f32,
	next_bullet_size:      f32,
	delay_for_size_bullet: f32,
}

Game :: struct {
	state:  bool,
	player: ^Player,
	scene:  ^scene_t,
}


oposite_directions :: proc(new, curr: vec2_t) -> bool {
	return new.x == -curr.x && new.y == -curr.y
}
