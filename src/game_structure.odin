package main
import "core:fmt"
import rl "vendor:raylib"
NUM_RECTANGLES_ON_SCENE :: 100
NUM_ENTITIES :: 1000

Entity :: struct {
	using s:   Shape,
	direction: vec2_t,
	kind:      KIND,
	speed:     f32,
	state:     STATE,
}

SCENES :: enum {
	ONE,
}

Shapes :: union #no_nil {
	Circle,
	Square,
	Rect,
}

GAME_STATE :: enum {
	PLAY,
	PAUSE,
	DEAD,
	QUIT,
}

Shape :: struct {
	position: vec2_t,
	shape:    Shapes,
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

KIND :: enum {
	STATIC,
	BULLET,
	CANDY,
	ENEMY,
}

CELL_STATE :: enum {
	NORMAL,
	GROW,
	SHRINK,
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
	size:                f32,
	state:               CELL_STATE,
}

cell_ghost_t :: struct {
	position, direction: vec2_t,
}

audio_system_t :: struct {
	bg_music: rl.Music,
	fx:       [dynamic]^rl.Sound,
}


Player :: struct {
	head:             cell_t,
	next_dir:         vec2_t,
	body:             [MAX_NUM_BODY]cell_t,
	health:           i8,
	num_cells:        i8,
	num_ghost_pieces: i8,
	ghost_pieces:     ^Ringuffer_t,
	rotation:         f32,
	next_bullet_size: f32,
	growing:          bool,
}

Game :: struct {
	state:              GAME_STATE,
	player:             ^Player,
	scene:              ^scene_t,
	current_scene:      SCENES,
	candy_respawn_time: int,
	enemy_respawn_time: int,
	audio:              audio_system_t,
}

FX :: enum {
	FX_EAT = 0,
	FX_SHOOT,
	FX_COUNT,
}

sound_bank: [FX.FX_COUNT]rl.Sound

add_sound :: proc(game: ^Game, sound: ^rl.Sound) {
	append(&game.audio.fx, sound)
}

load_sounds :: proc() {
	sound_bank[FX.FX_EAT] = rl.LoadSound("assets/nom.mp3")
	sound_bank[FX.FX_SHOOT] = rl.LoadSound("assets/pow.mp3")
}

unload_sounds :: proc() {
	for i in 0 ..< int(FX.FX_COUNT) {
		rl.UnloadSound(sound_bank[i])
	}
}

load_scene :: proc(game: ^Game, scene: SCENES) {
	old_ghost_pieces := game.player.ghost_pieces

	game.audio.bg_music = rl.LoadMusicStream("assets/bg_music.mp3")
	rl.SetMusicVolume(game.audio.bg_music, 0.001)
	rl.PlayMusicStream(game.audio.bg_music)
	load_sounds()


	game.player^ = Player {
		head             = cell_t {
			vec2_t{SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2},
			{0, -1},
			0,
			PLAYER_SIZE,
			.NORMAL,
		},
		body             = [MAX_NUM_BODY]cell_t{},
		health           = 3,
		next_dir         = {0, 0},
		rotation         = 0,
		next_bullet_size = 0,
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
