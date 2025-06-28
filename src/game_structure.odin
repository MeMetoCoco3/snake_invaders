package main
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

Vector2 :: [2]f32

Game :: struct {
	state:              GAME_STATE,
	player_position:    ^Position,
	player_velocity:    ^Velocity,
	player_body:        Body,
	spawn_areas:        []rl.Rectangle,
	count_spawn_areas:  int,
	current_scene:      SCENES,
	candy_respawn_time: int,
	enemy_respawn_time: int,
	count_enemies:      int,
	count_candies:      int,
	audio:              audio_system_t,
	world:              ^World,
}

Body :: struct {
	cells:        [MAX_NUM_BODY]cell_t,
	num_cells:    i8,
	ghost_pieces: ^Ringuffer_t,
	growing:      bool,
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
	position, direction: Vector2,
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


draw_animated_sprite :: proc(position: Position, animation: ^Animation, velocity: Velocity) {
	if animation._current_frame >= animation.num_frames {
		animation._current_frame = 0
	}
	src_rec := rl.Rectangle{f32(32 * animation._current_frame), 0, animation.w, animation.h}

	angle: f32
	switch animation.angle_type {
	case .LR:
		if velocity.direction.x >= 0 {
			src_rec.width *= -1
		}
	case .DIRECTIONAL:
		angle = math.atan2(velocity.direction.y, velocity.direction.x) * 180 / math.PI
	case .IGNORE:
	}
	// fmt.println(position)
	// fmt.println("PITION:", position.size)
	// fmt.println("ANIM, POSITION", animation.w, animation.h)
	dst_rec := rl.Rectangle{position.pos.x, position.pos.y, position.size.x, position.size.y}

	origin := Vector2{0, 0}
	rl.DrawTexturePro(animation.image^, src_rec, dst_rec, origin, f32(angle), rl.WHITE)

	if animation._time_on_frame >= animation.frame_delay && animation.kind != .STATIC {
		animation._current_frame += 1
		animation._time_on_frame = 0
	}

	animation._time_on_frame += 1
}

draw_sprite :: proc(sprite: Sprite) {
	src_rec := rl.Rectangle {
		sprite.src_rect.position.x,
		sprite.src_rect.position.y,
		sprite.src_rect.size.x,
		sprite.src_rect.size.y,
	}
	dst_rec := rl.Rectangle {
		sprite.dst_rect.position.x,
		sprite.dst_rect.position.y,
		sprite.dst_rect.size.x,
		sprite.dst_rect.size.y,
	}

	origin := Vector2{sprite.dst_rect.size.x / 2, sprite.dst_rect.size.y / 2}
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
		w              = 32,
		h              = 32,
		source_origin  = Vector2{0, 0},
		_current_frame = 0,
		num_frames     = 0,
		frame_delay    = 0,
		_time_on_frame = 0,
		padding        = {0, 0},
		offset         = {0, 0},
		kind           = .STATIC,
		angle_type     = .IGNORE,
	}

	animation_bank[ANIMATION.BULLET_G] = Animation {
		image          = &atlas,
		w              = 32,
		h              = 32,
		source_origin  = Vector2{0, 64},
		_current_frame = 0,
		num_frames     = 2,
		frame_delay    = 8,
		_time_on_frame = 0,
		padding        = {0, 0},
		offset         = {0, 0},
		kind           = .REPEAT,
		angle_type     = .DIRECTIONAL,
	}

	animation_bank[ANIMATION.BULLET_B] = Animation {
		image          = &atlas,
		w              = 32,
		h              = 32,
		source_origin  = Vector2{64, 64},
		_current_frame = 0,
		num_frames     = 2,
		frame_delay    = 8,
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
		source_origin  = Vector2{0, 128},
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
		source_origin  = Vector2{32, 128},
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
		source_origin  = Vector2{0, 64},
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
		w           = PLAYER_SIZE,
		h           = PLAYER_SIZE,
		num_frames  = 16,
		frame_delay = 4,
		kind        = .REPEAT,
		angle_type  = .IGNORE,
	}

}
//
// load_sprites :: proc() {
// 	sprite_bank[SPRITE.PLAYER_IDLE] = Sprite {
// 		image         = &atlas,
// 		source_origin = {0, 0},
// 		size          = {32, 32},
// 	}
//
// 	sprite_bank[SPRITE.PLAYER_EAT] = Sprite {
// 		image         = &atlas,
// 		source_origin = {32, 0},
// 		size          = {32, 32},
// 	}
//
// 	sprite_bank[SPRITE.BODY_STRAIGHT] = Sprite {
// 		image         = &atlas,
// 		source_origin = {0, 32},
// 		size          = {32, 32},
// 	}
//
// 	sprite_bank[SPRITE.BODY_TURN] = Sprite {
// 		image         = &atlas,
// 		source_origin = {32, 32},
// 		size          = {32, 32},
// 	}
//
// 	sprite_bank[SPRITE.TAIL] = Sprite {
// 		image         = &atlas,
// 		source_origin = {32, 64},
// 		size          = {32, 32},
// 	}
//
// 	sprite_bank[SPRITE.BORDER] = Sprite {
// 		image         = &atlas,
// 		source_origin = {0, 96},
// 		size          = {32, 32},
// 	}
//
// 	sprite_bank[SPRITE.CORNER] = Sprite {
// 		image         = &atlas,
// 		source_origin = {32, 96},
// 		size          = {32, 32},
// 	}
//
//
// }

unload_atlas :: proc() {
	rl.UnloadTexture(atlas)
}


unload_sounds :: proc() {
	for i in 0 ..< int(FX.FX_COUNT) {
		rl.UnloadSound(sound_bank[i])
	}
}

load_scene :: proc(game: ^Game, scene: SCENES) {
	old_ghost_pieces := game.player_body.ghost_pieces
	game.player_position^ = {{360, 360}, {PLAYER_SIZE, PLAYER_SIZE}}


	game.player_body.ghost_pieces = old_ghost_pieces
	game.player_body.ghost_pieces^ = Ringuffer_t {
		values = [MAX_NUM_BODY]cell_ghost_t{},
		head   = 0,
		tail   = 0,
		count  = 0,
	}

	game.state = .PLAY
	game.current_scene = scene
	game.candy_respawn_time = 0
	game.enemy_respawn_time = 0

	load_scenario(game, scene)

}
