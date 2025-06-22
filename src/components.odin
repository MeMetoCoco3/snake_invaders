package main
import rl "vendor:raylib"

init_component :: proc(archetype: ^Archetype, component: COMPONENT_ID) {
	switch component {
	case .POSITION:
		archetype.positions = make([dynamic]Position, 0, 64)
	case .VELOCITY:
		archetype.positions = make([dynamic]Position, 0, 64)
	case .SPRITE:
		archetype.positions = make([dynamic]Position, 0, 64)
	case .ANIMATION:
		archetype.positions = make([dynamic]Position, 0, 64)
	case .COUNT:
	}
}


COMPONENT_ID :: enum u64 {
	POSITION  = 1,
	VELOCITY  = 2,
	SPRITE    = 4,
	ANIMATION = 8,
	KIND      = 16,
	COUNT     = 32,
}

Component :: union #no_nil {
	Position,
	Velocity,
	Sprite,
	Animation,
	Collider,
	Data,
}

Position :: struct {
	position: Vector2,
}

Velocity :: struct {
	direction: Vector2,
	speed:     f32,
}

Sprite :: struct {
	texture_id: TEXTURE,
}

Animation :: struct {
	image:          ^rl.Texture2D,
	w:              f32,
	h:              f32,
	_current_frame: int,
	num_frames:     int,
	frame_delay:    int,
	_time_on_frame: int,
	padding:        Vector2,
	offset:         Vector2,
	kind:           ANIMATION_KIND,
	angle_type:     ANIM_DIRECTION,
}

ANIMATION_KIND :: enum {
	STATIC,
	REPEAT,
	NONREPEAT,
}

ANIM_DIRECTION :: enum {
	DIRECTIONAL = 0,
	LR,
	IGNORE,
}

Collider :: struct {
	x, y: int,
	w, h: int,
}

Data :: struct {
	kind:  ENTITY_KIND,
	state: ENTITY_STATE,
	team:  ENTITY_TEAM,
}


ENTITY_KIND :: enum {
	STATIC,
	CANDY,
	ENEMY,
	BULLET,
}

ENTITY_STATE :: enum {
	DEAD,
	ALIVE,
}

ENTITY_TEAM :: enum {
	GOOD,
	BAD,
}
