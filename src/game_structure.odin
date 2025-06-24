package main
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

Vector2 :: [2]f32

Game :: struct {
	state:              GAME_STATE,
	player_position:    ^Position,
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
	cells:            [MAX_NUM_BODY]cell_t,
	num_cells:        i8,
	ghost_pieces:     ^Ringuffer_t,
	num_ghost_pieces: i8,
	growing:          bool,
}

GAME_STATE :: enum {
	PLAY,
	PAUSE,
	DEAD,
	QUIT,
}


// Player :: struct {
// 	using head:       cell_t,
// 	next_dir:         Vector2,
// 	speed:            i8,
// 	can_dash:         bool,
// 	time_on_dash:     i16,
// 	health:           i8,
// 	num_cells:        i8,
// 	num_ghost_pieces: i8,
// 	ghost_pieces:     ^Ringuffer_t,
// 	rotation:         f32,
// 	next_bullet_size: f32,
// 	growing:          bool,
// 	animation:        Animation,
// 	state:            PLAYER_STATE,
// }

PLAYER_STATE :: enum {
	NORMAL,
	DASH,
}

cell_t :: struct {
	position, direction: Vector2,
	count_turns_left:    i8,
	size:                f32,
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

TEXTURE :: enum {
	TX_PLAYER = 0,
	TX_ENEMY,
	TX_BULLET,
	TX_BIG_EXPLOSION,
	TX_CANDY,
	TX_COUNT,
}

texture_bank: [TEXTURE.TX_COUNT]rl.Texture2D
sound_bank: [FX.FX_COUNT]rl.Sound
bg_music: rl.Music

draw :: proc {// draw_entity_animation,
	// draw_player_animation,
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

	dst_rec := rl.Rectangle{position.pos.x, position.pos.y, animation.w, animation.h}

	origin := Vector2{animation.w / 2, animation.h / 2}
	rl.DrawTexturePro(animation.image^, src_rec, dst_rec, origin, f32(angle), rl.WHITE)

	if animation._time_on_frame >= animation.frame_delay && animation.kind != .STATIC {
		animation._current_frame += 1
		animation._time_on_frame = 0
	}

	animation._time_on_frame += 1
}

draw_sprite :: proc(position: Position, sprite: Sprite) {
	src_rec := rl.Rectangle {
		sprite.source_position.x,
		sprite.source_position.y,
		sprite.size.x,
		sprite.size.y,
	}
	// ORIGIN: Marks the point of rotation, relative to the rectangle, i will live it at 0,0
	dst_rec := rl.Rectangle{position.pos.x, position.pos.y, position.size.x, position.size.y}

	rl.DrawTexturePro(sprite.texture_id^, src_rec, dst_rec, {0, 0}, 0, rl.WHITE)
}

//
// draw_player_animation :: proc(player: ^Player) {
// 	src_rec := rl.Rectangle{0, 32, PLAYER_SIZE, PLAYER_SIZE}
// 	switch player.head.direction {
// 	case {0, 1}:
// 		player.rotation = 270
// 	case {0, -1}:
// 		player.rotation = 90
// 	case {1, 0}:
// 		player.rotation = 180
// 	case {-1, 0}:
// 		player.rotation = 0
//
// 	}
//
// 	dst_rec := rl.Rectangle {
// 		player.head.position.x + PLAYER_SIZE / 2,
// 		player.head.position.y + PLAYER_SIZE / 2,
// 		PLAYER_SIZE,
// 		PLAYER_SIZE,
// 	}
// 	origin := rl.Vector2{PLAYER_SIZE / 2, PLAYER_SIZE / 2}
// 	rl.DrawTexturePro(player.animation.image^, src_rec, dst_rec, origin, player.rotation, rl.WHITE)
// }
//

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

load_textures :: proc() {
	texture_bank[TEXTURE.TX_PLAYER] = rl.LoadTexture("assets/tileset.png")
	texture_bank[TEXTURE.TX_ENEMY] = rl.LoadTexture("assets/ghost.png")
	texture_bank[TEXTURE.TX_BULLET] = rl.LoadTexture("assets/player-shoot.png")
	texture_bank[TEXTURE.TX_CANDY] = rl.LoadTexture("assets/coin.png")
	texture_bank[TEXTURE.TX_BIG_EXPLOSION] = rl.LoadTexture("assets/big-explosion.png")
}

unload_textures :: proc() {
	for i in 0 ..< int(TEXTURE.TX_COUNT) {
		rl.UnloadTexture(texture_bank[i])
	}
}


unload_sounds :: proc() {
	for i in 0 ..< int(FX.FX_COUNT) {
		rl.UnloadSound(sound_bank[i])
	}
}

load_scene :: proc(game: ^Game, scene: SCENES) {
	old_ghost_pieces := game.player_body.ghost_pieces
	game.player_position^ = {{SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2}, {0, 0}}


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
