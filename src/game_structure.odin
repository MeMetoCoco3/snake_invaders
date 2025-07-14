package main

import "core:fmt"
import "core:math"
import "core:mem"
import vmem "core:mem/virtual"
import rl "vendor:raylib"
Vector2 :: [2]f32

Game :: struct {
	loops:              int,
	state:              GAME_STATE,
	player_position:    ^Position,
	player_velocity:    ^Velocity,
	player_data:        ^PlayerData,
	player_body:        Body,
	spawn_areas:        []rl.Rectangle,
	count_spawn_areas:  int,
	current_scene:      SCENES,
	candy_respawn_time: int,
	enemy_respawn_time: int,
	count_enemies:      int,
	count_candies:      int,
	directions:         ^Ringuffer_t(Vector2),
	audio:              audio_system_t,
	world:              ^World,
	arena:              ^mem.Allocator,
}

Body :: struct {
	first_cell_pos:  ^Position,
	first_cell_data: ^PlayerData,
	num_cells:       i8,
	ghost_pieces:    ^Ringuffer_t(cell_ghost_t),
	growing:         bool,
}

GAME_STATE :: enum {
	PLAY,
	PAUSE,
	DEAD,
	QUIT,
}

PLAYER_STATE :: enum {
	NORMAL,
	DASH,
}

cell_t :: struct {
	position, direction: Vector2,
	count_turns_left:    i8,
	size:                f32,
	collider:            Collider,
}

cell_ghost_t :: struct {
	entity_id:           u32,
	body_index:          u32,
	position, direction: Vector2,
	rotation:            f32,
}

radians_from_vector :: proc(v: Vector2) -> f32 {
	return math.atan2_f32(v.y, v.x)

}

vec2_normalize :: proc(v: ^Vector2) {
	x, y: f32
	if v.x == 0 {
		x = 0
	} else {
		x = v.x / abs(v.x)
	}
	if v.y == 0 {
		y = 0
	} else {
		y = v.y / abs(v.y)
	}
	v.x = x
	v.y = y
}

ANIMATION :: enum {
	PLAYER = 0,
	BULLET_G,
	ENEMY_SHOT,
	ENEMY_RUN,
	BIG_EXPLOSION,
	BULLET_B,
	CANDY,
	ANIM_COUNT,
}

SPRITE :: enum {
	PLAYER_IDLE = 0,
	PLAYER_EAT,
	BODY_STRAIGHT,
	BODY_TURN,
	TAIL,
	BORDER,
	CORNER,
	SPRITE_COUNT,
}

animation_bank: [ANIMATION.ANIM_COUNT]Animation
sprite_bank: [SPRITE.SPRITE_COUNT]Sprite
sound_bank: [FX.FX_COUNT]rl.Sound
bg_music: rl.Music

draw :: proc {
	draw_sprite,
	draw_animated_sprite,
}


draw_animated_sprite :: proc(
	position: Position,
	animation: ^Animation,
	direction: Vector2,
	team: ENTITY_TEAM,
	color: rl.Color,
) {
	if animation._current_frame >= animation.num_frames {
		animation._current_frame = 0
	}
	src_rec := rl.Rectangle {
		f32(animation.source_x + animation.w * f32(animation._current_frame)),
		f32(animation.source_y),
		animation.w,
		animation.h,
	}
	angle: f32 = 0.0
	switch animation.angle_type {
	case .LR:
		if direction.x <= 0 {
			src_rec.width *= -1
		}
	case .DIRECTIONAL:
		angle = angle_from_vector(direction) + animation.angle
	case .IGNORE:
	}

	dst_rec := rl.Rectangle {
		position.pos.x + position.size.x / 2,
		position.pos.y + position.size.y / 2,
		position.size.x,
		position.size.y,
	}

	origin := Vector2{position.size.x / 2, position.size.y / 2}
	rl.DrawTexturePro(animation.image^, src_rec, dst_rec, origin, angle, color)
	when DEBUG_COLISION {
		dst_rec.x -= position.size.x / 2
		dst_rec.y -= position.size.y / 2
		color := rl.WHITE
		switch team {
		case .NEUTRAL:
			color = rl.GRAY
		case .BAD:
			color = rl.RED
		case .GOOD:
			color = rl.BLUE
		}

		rl.DrawRectangleLinesEx(dst_rec, 1, color)
	}

	if animation._time_on_frame >= animation.frame_delay && animation.kind != .STATIC {
		animation._current_frame += 1
		animation._time_on_frame = 0
	}

	animation._time_on_frame += 1
}

draw_sprite :: proc(sprite: Sprite, position: Position) {
	src_rec := rl.Rectangle {
		sprite.src_rect.position.x,
		sprite.src_rect.position.y,
		sprite.src_rect.size.x,
		sprite.src_rect.size.y,
	}
	dst_rec := rl.Rectangle{position.pos.x, position.pos.y, position.size.x, position.size.y}
	origin := Vector2{position.size.x / 2, position.size.y / 2}
	rl.DrawTexturePro(sprite.image^, src_rec, dst_rec, origin, sprite.rotation, rl.WHITE)
}

add_sound :: proc(game: ^Game, sound: ^rl.Sound) {
	append(&game.audio.fx, sound)
}

play_sound :: proc(game: ^Game) {
	if len(game.audio.fx) > 0 {
		fx := game.audio.fx[0]
		unordered_remove(&game.audio.fx, 0)
		rl.PlaySound(fx^)
	}
}

load_sounds :: proc() {
	bg_music = rl.LoadMusicStream("assets/bg_music.mp3")

	sound_bank[FX.FX_EAT] = rl.LoadSound("assets/nom.mp3")
	sound_bank[FX.FX_SHOOT] = rl.LoadSound("assets/pow.mp3")
}

load_animations :: proc() {
	animation_bank[ANIMATION.PLAYER] = Animation {
		image          = &atlas,
		w              = PLAYER_SIZE,
		h              = PLAYER_SIZE,
		source_x       = 0,
		source_y       = 0,
		angle          = 90,
		_current_frame = 0,
		num_frames     = 0,
		frame_delay    = 0,
		_time_on_frame = 0,
		padding        = {0, 0},
		offset         = {0, 0},
		kind           = .STATIC,
		angle_type     = .DIRECTIONAL,
	}

	animation_bank[ANIMATION.BULLET_G] = Animation {
		image          = &atlas,
		w              = 32,
		h              = 32,
		source_x       = 0,
		source_y       = 64,
		_current_frame = 0,
		num_frames     = 2,
		frame_delay    = 8,
		_time_on_frame = 0,
		angle          = 90,
		padding        = {0, 0},
		offset         = {0, 0},
		kind           = .REPEAT,
		angle_type     = .DIRECTIONAL,
	}

	animation_bank[ANIMATION.BULLET_B] = Animation {
		image          = &atlas,
		w              = 32,
		h              = 32,
		source_x       = 64,
		source_y       = 64,
		_current_frame = 0,
		num_frames     = 2,
		frame_delay    = 8,
		angle          = 90,
		_time_on_frame = 0,
		padding        = {0, 0},
		offset         = {0, 0},
		kind           = .REPEAT,
		angle_type     = .DIRECTIONAL,
	}

	animation_bank[ANIMATION.ENEMY_SHOT] = Animation {
		image          = &atlas,
		w              = 32,
		h              = 32,
		source_x       = 0,
		source_y       = 128,
		_current_frame = 0,
		num_frames     = 1,
		frame_delay    = 8,
		_time_on_frame = 0,
		padding        = {0, 0},
		offset         = {0, 0},
		kind           = .STATIC,
		angle_type     = .LR,
	}

	animation_bank[ANIMATION.ENEMY_RUN] = Animation {
		image          = &atlas,
		w              = 32,
		h              = 32,
		source_x       = 32,
		source_y       = 128,
		_current_frame = 0,
		num_frames     = 4,
		frame_delay    = 8,
		_time_on_frame = 0,
		padding        = {0, 0},
		offset         = {0, 0},
		kind           = .REPEAT,
		angle_type     = .LR,
	}


	animation_bank[ANIMATION.BIG_EXPLOSION] = Animation {
		image          = &atlas,
		w              = 32,
		h              = 32,
		source_x       = 0,
		source_y       = 64,
		_current_frame = 0,
		num_frames     = 2,
		frame_delay    = 8,
		_time_on_frame = 0,
		padding        = {0, 0},
		offset         = {0, 0},
		kind           = .REPEAT,
		angle_type     = .DIRECTIONAL,
	}

	animation_bank[ANIMATION.CANDY] = Animation {
		image       = &tx_candy,
		w           = 16,
		h           = 16,
		source_x    = 0,
		source_y    = 0,
		num_frames  = 16,
		frame_delay = 4,
		kind        = .REPEAT,
		angle_type  = .IGNORE,
	}

}


load_sprites :: proc() {
	sprite_bank[SPRITE.PLAYER_IDLE] = Sprite {
		image    = &atlas,
		src_rect = Rect{{0, 0}, {32, 32}},
	}

	sprite_bank[SPRITE.PLAYER_EAT] = Sprite {
		image    = &atlas,
		src_rect = Rect{{32, 0}, {32, 32}},
	}

	sprite_bank[SPRITE.BODY_STRAIGHT] = Sprite {
		image    = &atlas,
		src_rect = Rect{{0, 32}, {32, 32}},
		rotation = 90,
	}

	sprite_bank[SPRITE.BODY_TURN] = Sprite {
		image    = &atlas,
		src_rect = Rect{{32, 32}, {32, 32}},
	}

	sprite_bank[SPRITE.TAIL] = Sprite {
		image    = &atlas,
		src_rect = Rect{{32, 64}, {32, 32}},
	}

	sprite_bank[SPRITE.BORDER] = Sprite {
		image    = &atlas,
		src_rect = Rect{{0, 96}, {32, 32}},
	}

	sprite_bank[SPRITE.CORNER] = Sprite {
		image    = &atlas,
		src_rect = Rect{{32, 96}, {32, 32}},
	}
}


draw_body_sprite :: proc(body: ^Body) {
	rb := body.ghost_pieces
	loop_index := rb.head

	for i in 0 ..< rb.count {
		cell := rb.values[loop_index]
		sprite := sprite_bank[SPRITE.BODY_TURN]
		angle := angle_from_vector(cell.direction)

		sprite.rotation = cell.rotation

		draw(sprite, Position{pos = cell.position + PLAYER_SIZE / 2, size = PLAYER_SIZE})

		loop_index = (loop_index + 1) % MAX_RINGBUFFER_VALUES
	}
}


unload_textures :: proc() {
	rl.UnloadTexture(atlas)
	rl.UnloadTexture(tx_candy)
}


unload_sounds :: proc() {
	for i in 0 ..< int(FX.FX_COUNT) {
		rl.UnloadSound(sound_bank[i])
	}
}

load_scene :: proc(game: ^Game, scene: SCENES, arena: ^mem.Allocator) {
	add_player(game.world)
	raw, _ := mem.alloc(size_of(Ringuffer_t(cell_ghost_t)), allocator = arena^)
	rb_ghost := cast(^Ringuffer_t(cell_ghost_t))raw
	rb_ghost.values = make([]cell_ghost_t, MAX_RINGBUFFER_VALUES, arena^)
	game.player_body.ghost_pieces = rb_ghost

	raw, _ = mem.alloc(size_of(Ringuffer_t(Vector2)), allocator = arena^)
	rb_dir := cast(^Ringuffer_t(Vector2))raw
	rb_dir.values = make([]Vector2, MAX_RINGBUFFER_VALUES, arena^)
	game.directions = rb_dir

	game.state = .PLAY
	game.current_scene = scene
	game.candy_respawn_time = 0
	game.enemy_respawn_time = 0
	load_scenario(game, scene)

}
