package main
import rl "vendor:raylib"

init_component :: proc(archetype: ^Archetype, component: COMPONENT_ID) {
	switch component {
	case .POSITION:
		archetype.positions = make([dynamic]Position, 0, 64)
	case .VELOCITY:
		archetype.velocities = make([dynamic]Velocity, 0, 64)
	case .SPRITE:
		archetype.sprites = make([dynamic]Sprite, 0, 64)
	case .ANIMATION:
		archetype.animations = make([dynamic]Animation, 0, 64)
	case .DATA:
		archetype.data = make([dynamic]Data, 0, 64)
	case .COLLIDER:
		archetype.colliders = make([dynamic]Collider, 0, 64)
	case .IA:
		archetype.ias = make([dynamic]IA, 0, 64)
	case .PLAYER_DATA:
		archetype.players_data = make([dynamic]PlayerData, 0, 64)
	case .COUNT:
	}
}

add_components :: proc(arch: ^Archetype, components: []Component) {
	for component in components {
		switch kind in component {
		case Position:
			append(&arch.positions, kind)
		case Velocity:
			append(&arch.velocities, kind)
		case Sprite:
			append(&arch.sprites, kind)
		case Animation:
			append(&arch.animations, kind)
		case Data:
			append(&arch.data, kind)
		case Collider:
			append(&arch.colliders, kind)
		case IA:
			append(&arch.ias, kind)
		case PlayerData:
			append(&arch.players_data, kind)
		}
	}

}


COMPONENT_ID :: enum u64 {
	POSITION    = 1,
	VELOCITY    = 2,
	SPRITE      = 4,
	ANIMATION   = 8,
	DATA        = 16,
	COLLIDER    = 32,
	IA          = 64,
	PLAYER_DATA = 128,
	COUNT       = 256,
}

Component :: union #no_nil {
	Position,
	Velocity,
	Sprite,
	Animation,
	Data,
	Collider,
	IA,
	PlayerData,
}

Position :: struct {
	pos:  Vector2,
	size: Vector2,
}

Velocity :: struct {
	direction: Vector2,
	speed:     f32,
}

Sprite :: struct {
	image:    ^rl.Texture2D,
	src_rect: Rect,
	rotation: f32,
}

Rect :: struct {
	position: Vector2,
	size:     Vector2,
}


Animation :: struct {
	image:              ^rl.Texture2D,
	source_x, source_y: f32,
	w:                  f32,
	h:                  f32,
	_current_frame:     int,
	num_frames:         int,
	frame_delay:        int,
	_time_on_frame:     int,
	padding:            Vector2,
	offset:             Vector2,
	kind:               ANIMATION_KIND,
	angle_type:         ANIM_DIRECTION,
	angle:              f32,
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
	position: Vector2,
	w, h:     int,
	active:   bool,
}


Data :: struct {
	kind:  ENTITY_KIND,
	state: ENTITY_STATE,
	team:  ENTITY_TEAM,
}

IA :: struct {
	behavior:               ENEMY_BEHAVIOR,
	reload_time:            f32,
	minimum_distance:       f32,
	maximum_distance:       f32,
	_time_for_change_state: int,
}

PlayerData :: struct {
	player_state:     PLAYER_STATE,
	distance:         f32,
	next_dir:         Vector2,
	previous_dir:     Vector2,
	can_dash:         bool,
	// going_to_collide: bool,
	// distance_to_move: f32,
	time_on_dash:     i32,
	time_since_dmg:   i32,
	health:           i32,
	next_bullet_size: f32,
	growing:          bool,
	gona_dash:        bool,
	cells_to_grow:    int,
	body_index:       i8,
	time_since_turn:  int,
	count_turn_left:  int,
}

ENEMY_BEHAVIOR :: enum {
	APPROACH,
	SHOT,
	GOAWAY,
}

ENTITY_KIND :: enum {
	STATIC,
	PLAYER,
	BODY,
	GHOST_PIECE,
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
	NEUTRAL,
}
