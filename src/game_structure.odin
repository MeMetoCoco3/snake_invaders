package main
import "core:fmt"
import "core:math"
import rl "vendor:raylib"
NUM_RECTANGLES_ON_SCENE :: 100
NUM_ENTITIES :: 1000

Vector2 :: [2]f32


Entity :: struct {
	using s:   Shape,
	direction: Vector2,
	kind:      KIND,
	speed:     f32,
	state:     STATE,
	animation: animation_t,
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
	position: Vector2,
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


cell_t :: struct {
	position, direction: Vector2,
	count_turns_left:    i8,
	size:                f32,
	state:               CELL_STATE,
}

cell_ghost_t :: struct {
	position, direction: Vector2,
}

audio_system_t :: struct {
	bg_music: rl.Music,
	fx:       [dynamic]^rl.Sound,
}

// TODO: REFACTOR THIS
Player :: struct {
	using e:          Entity,
	head:             cell_t,
	next_dir:         Vector2,
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

TEXTURE :: enum {
	TX_PLAYER = 0,
	TX_ENEMY,
	TX_BULLET,
	TX_BIG_EXPLOSION,
	TX_COUNT,
}

ANIM_DIRECTION :: enum {
	DIRECTIONAL = 0,
	LR,
}
texture_bank: [TEXTURE.TX_COUNT]rl.Texture2D
sound_bank: [FX.FX_COUNT]rl.Sound

// TODO: SHOULD I HIDE SOME OF THIS SHIT BECAUSE IT IS NOT IMPORTANT TO HAVEIT OUTSIDEOF THE FUNCTIONS? like time on frame or current_frame
animation_t :: struct {
	image:         ^rl.Texture2D,
	w:             f32,
	h:             f32,
	current_frame: int,
	num_frames:    int,
	frame_delay:   int,
	time_on_frame: int,
	padding:       Vector2,
	offset:        Vector2,
	kind:          ANIMATION_KIND,
	angle_type:    ANIM_DIRECTION,
}

ANIMATION_KIND :: enum {
	STATIC,
	REPEAT,
	NONREPEAT,
}

draw_entity :: proc(entity: ^Entity) {
	anim := &entity.animation
	if anim.current_frame >= anim.num_frames {
		anim.current_frame = 0
	}
	src_rec := rl.Rectangle{f32(32 * anim.current_frame), 0, anim.w, anim.h}

	angle: f32
	dst_width := anim.w

	switch anim.angle_type {
	case .LR:
		if entity.direction.x > 0.1 {
			src_rec.width *= -1
		}
	case .DIRECTIONAL:
		angle = math.atan2(entity.direction.y, entity.direction.x) * 180 / math.PI
		fmt.println("angle", angle)
	}


	// TODO: MAYBEHERE PUT ANIM TIMES THE SIZEOF THE ENTITY
	dst_rec := rl.Rectangle{entity.position.x, entity.position.y, dst_width, anim.h}

	origin := Vector2{anim.w / 2, anim.h / 2}
	rl.DrawTexturePro(anim.image^, src_rec, dst_rec, origin, f32(angle), rl.WHITE)

	if anim.time_on_frame >= anim.frame_delay && anim.kind != .STATIC {
		anim.current_frame += 1
		anim.time_on_frame = 0
	}
	anim.time_on_frame += 1
}


// TODO: DEPRECATE THIS FOR A MORE GENERAL DRAW_ENTITY or DRAW ANIMATION
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
	sound_bank[FX.FX_EAT] = rl.LoadSound("assets/nom.mp3")
	sound_bank[FX.FX_SHOOT] = rl.LoadSound("assets/pow.mp3")
}

load_textures :: proc() {
	texture_bank[TEXTURE.TX_PLAYER] = rl.LoadTexture("assets/tileset.png")
	texture_bank[TEXTURE.TX_ENEMY] = rl.LoadTexture("assets/ghost.png")
	texture_bank[TEXTURE.TX_BULLET] = rl.LoadTexture("assets/player-shoot.png")
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

	game.audio.bg_music = rl.LoadMusicStream("assets/bg_music.mp3")
	rl.SetMusicVolume(game.audio.bg_music, 0.001)
	rl.PlayMusicStream(game.audio.bg_music)
	// TODO: TAKE THIS OUT OF HERE
	load_sounds()
	load_textures()

	game.player^ = Player {
		head             = cell_t {
			Vector2{SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2},
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
