package main

import "core:fmt"
import "core:math"
import "core:mem"
import vmem "core:mem/virtual"
import rl "vendor:raylib"

Vec2 :: [2]f32

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
	directions:         ^Ringuffer_t(Vec2),
	audio:              audio_system_t,
	world:              ^World,
	arena:              ^vmem.Arena,
	fram_count:         int,
	camera:             rl.Camera2D,
}

Body :: struct {
	first_cell_pos:  ^Position,
	first_cell_data: ^PlayerData,
	num_cells:       i8,
	ghost_pieces:    ^Ringuffer_t(cell_ghost_t),
	growing:         bool,
	ghost_colliders: ^[dynamic]Collider,
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
	position, direction: Vec2,
	count_turns_left:    i8,
	size:                f32,
	collider:            Collider,
}

cell_ghost_t :: struct {
	entity_id:           u32,
	body_index:          u32,
	position, direction: Vec2,
	rotation:            f32,
}

Draw :: proc {
	draw_sprite,
	draw_animated_sprite,
}


draw_animated_sprite :: proc(
	position: Position,
	animation: ^Animation,
	direction: Vec2,
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

	origin := Vec2{position.size.x / 2, position.size.y / 2}
	rl.DrawTexturePro(animation.image^, src_rec, dst_rec, origin, angle, color)
	if DEBUG_COLISION {
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
	origin := Vec2{position.size.x / 2, position.size.y / 2}
	rl.DrawTexturePro(sprite.image^, src_rec, dst_rec, origin, sprite.rotation, rl.WHITE)
}

AddSound :: proc(game: ^Game, sound: ^rl.Sound) {
	append(&game.audio.fx, sound)
}

PlaySound :: proc(game: ^Game) {
	if len(game.audio.fx) > 0 {
		fx := game.audio.fx[0]
		unordered_remove(&game.audio.fx, 0)
		rl.PlaySound(fx^)
	}
}

LoadSounds :: proc() {
	bg_music = rl.LoadMusicStream("assets/bg_music.mp3")

	sound_bank[FX.FX_EAT] = rl.LoadSound("assets/nom.mp3")
	sound_bank[FX.FX_SHOOT] = rl.LoadSound("assets/pow.mp3")
}

LoadAnimations :: proc() {
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

	animation_bank[ANIMATION.SHIELD] = Animation {
		image          = &atlas,
		w              = 32,
		h              = 32,
		source_x       = 0,
		source_y       = 160,
		_current_frame = 0,
		num_frames     = 0,
		frame_delay    = 0,
		_time_on_frame = 0,
		angle          = 90,
		padding        = {0, 0},
		offset         = {0, 0},
		kind           = .STATIC,
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


LoadSprites :: proc() {
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

		Draw(sprite, Position{pos = cell.position + PLAYER_SIZE / 2, size = PLAYER_SIZE})

		loop_index = (loop_index + 1) % MAX_RINGBUFFER_VALUES
	}
}


UnloadTextures :: proc() {
	rl.UnloadTexture(atlas)
	rl.UnloadTexture(tx_candy)
}


UnloadSounds :: proc() {
	for i in 0 ..< int(FX.FX_COUNT) {
		rl.UnloadSound(sound_bank[i])
	}
}

LoadScene :: proc(game: ^Game, scene: SCENES) {
	game.world = new_world()
	add_player(game)
	set_body_0(game)
	set_directions_0(game)


	game.audio = audio_system_t {
		fx       = make([dynamic]^rl.Sound, 0, 20),
		bg_music = bg_music,
	}

	game.state = .PLAY
	game.current_scene = scene
	game.count_candies = 0
	game.count_enemies = 0
	game.candy_respawn_time = 0
	game.enemy_respawn_time = 0
	load_scenario(game, scene)

}
