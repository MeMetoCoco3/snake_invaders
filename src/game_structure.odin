package main
import "core:fmt"
import "core:math"
import rl "vendor:raylib"

Vector2 :: [2]f32


Game :: struct {
	state:              GAME_STATE,
	player:             ^Player,
	scene:              ^scene_t,
	current_scene:      SCENES,
	candy_respawn_time: int,
	enemy_respawn_time: int,
	audio:              audio_system_t,
}

GAME_STATE :: enum {
	PLAY,
	PAUSE,
	DEAD,
	QUIT,
}

Player :: struct {
	using head:       cell_t,
	next_dir:         Vector2,
	body:             [MAX_NUM_BODY]cell_t,
	speed:            i8,
	can_dash:         bool,
	time_on_dash:     i16,
	health:           i8,
	num_cells:        i8,
	num_ghost_pieces: i8,
	ghost_pieces:     ^Ringuffer_t,
	rotation:         f32,
	next_bullet_size: f32,
	growing:          bool,
	animation:        animation_t,
	state:            PLAYER_STATE,
}

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

Entity :: struct {
	using s:   Shape,
	direction: Vector2,
	kind:      ENTITY_KIND,
	speed:     f32,
	state:     ENTITY_STATE,
	animation: animation_t,
}

ENTITY_KIND :: enum {
	STATIC,
	CANDY,
}


ENTITY_STATE :: enum {
	DEAD,
	ALIVE,
}


Enemy :: struct {
	using entity:          Entity,
	behavior:              ENEMY_BEHAVIOR,
	reload_time:           f32,
	minimum_distance:      f32,
	maximum_distance:      f32,
	time_for_change_state: int,
}


ENEMY_BEHAVIOR :: enum {
	APROACH,
	SHOT,
	GOAWAY,
}


Bullet :: struct {
	using entity: Entity,
	team:         BULLET_TEAM,
}

BULLET_TEAM :: enum {
	GOOD,
	BAD,
}


ENEMY_SIZE_BULLET :: 16
TIME_TO_CHANGE_STATE :: 300


update_enemy :: proc(game: ^Game, enemy: ^Enemy) {
	distance_to_player := vec2_distance(game.player.position, enemy.position)

	if enemy.time_for_change_state > TIME_TO_CHANGE_STATE {
		enemy.time_for_change_state = 0
		switch {
		case distance_to_player > enemy.maximum_distance:
			enemy.behavior = .APROACH
		case distance_to_player < enemy.minimum_distance:
			enemy.behavior = .GOAWAY
		case:
			enemy.behavior = .SHOT
		}} else {
		enemy.time_for_change_state += 1
	}


	direction := (game.player.position - enemy.position) / distance_to_player
	if enemy.behavior == .SHOT {
		enemy.direction = {0, 0}
		if enemy.reload_time >= ENEMY_TIME_RELOAD {
			spawn_bullet(game, enemy.position, ENEMY_SIZE_BULLET, direction, .BAD)
			fmt.println(game.scene.count_bullets)
			enemy.reload_time = 0
		} else {
			enemy.reload_time += 1
		}
	}

	fmt.println("ENEMY DIRECTION", enemy.direction)
	enemy.position += (enemy.direction * enemy.speed)
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


// TODO: MANDAR A TOMAR POR CULO ESTO
Shape :: struct {
	position: Vector2,
	shape:    Shapes,
}

Shapes :: union #no_nil {
	Circle,
	Square,
	Rect,
}


Circle :: struct {
	r: f32,
}

Square :: struct {
	w: f32,
}

Rect :: struct {
	w, h: f32,
}


audio_system_t :: struct {
	bg_music: rl.Music,
	fx:       [dynamic]^rl.Sound,
}

FX :: enum {
	FX_EAT = 0,
	FX_SHOOT,
	FX_COUNT,
}

animation_t :: struct {
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

draw :: proc {
	draw_entity_animation,
	draw_player_animation,
}

draw_entity_animation :: proc(entity: ^Entity) {
	anim := &entity.animation
	if anim._current_frame >= anim.num_frames {
		anim._current_frame = 0
	}
	src_rec := rl.Rectangle{f32(32 * anim._current_frame), 0, anim.w, anim.h}

	angle: f32
	switch anim.angle_type {
	case .LR:
		if entity.direction.x > 0.1 {
			src_rec.width *= -1
		}
	case .DIRECTIONAL:
		angle = math.atan2(entity.direction.y, entity.direction.x) * 180 / math.PI
	case .IGNORE:
	}

	entity_size: [2]f32

	switch s in entity.shape {
	case Circle:
		entity_size = {s.r, s.r}
	case Rect:
		entity_size = {s.w, s.h}
	case Square:
		entity_size = {s.w, s.w}
	}


	dst_rec := rl.Rectangle{entity.position.x, entity.position.y, entity_size.x, entity_size.y}

	origin := Vector2{entity_size.x / 2, entity_size.y / 2}
	rl.DrawTexturePro(anim.image^, src_rec, dst_rec, origin, f32(angle), rl.WHITE)

	if anim._time_on_frame >= anim.frame_delay && anim.kind != .STATIC {
		anim._current_frame += 1
		anim._time_on_frame = 0
	}
	anim._time_on_frame += 1
}


draw_player_animation :: proc(player: ^Player) {
	src_rec := rl.Rectangle{0, 32, PLAYER_SIZE, PLAYER_SIZE}
	switch player.head.direction {
	case {0, 1}:
		player.rotation = 270
	case {0, -1}:
		player.rotation = 90
	case {1, 0}:
		player.rotation = 180
	case {-1, 0}:
		player.rotation = 0

	}

	dst_rec := rl.Rectangle {
		player.head.position.x + PLAYER_SIZE / 2,
		player.head.position.y + PLAYER_SIZE / 2,
		PLAYER_SIZE,
		PLAYER_SIZE,
	}
	origin := rl.Vector2{PLAYER_SIZE / 2, PLAYER_SIZE / 2}
	rl.DrawTexturePro(player.animation.image^, src_rec, dst_rec, origin, player.rotation, rl.WHITE)
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
	old_ghost_pieces := game.player.ghost_pieces

	game.player^ = {
		head = cell_t{Vector2{SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2}, {0, -1}, 0, PLAYER_SIZE},
		body = [MAX_NUM_BODY]cell_t{},
		health = 3,
		next_dir = {0, 0},
		rotation = 0,
		next_bullet_size = 0,
		speed = PLAYER_SPEED,
		animation = {
			image = &texture_bank[TEXTURE.TX_PLAYER],
			w = 16,
			h = 16,
			num_frames = 1,
			kind = .STATIC,
			angle_type = .DIRECTIONAL,
		},
		can_dash = true,
		time_on_dash = RECOVER_DASH_TIME,
		state = .NORMAL,
	}

	game.player.ghost_pieces = old_ghost_pieces
	game.player.ghost_pieces^ = Ringuffer_t {
		values = [MAX_NUM_BODY]cell_ghost_t{},
		head   = 0,
		tail   = 0,
		count  = 0,
	}

	game.state = .PLAY
	game.scene = load_scenario(scene)
	game.current_scene = scene
	game.candy_respawn_time = 0
	game.enemy_respawn_time = 0
}
