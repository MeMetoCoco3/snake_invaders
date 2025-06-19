package main

import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 800
PLAYER_SIZE :: 16
PLAYER_SPEED :: 2
DASH_DURATION :: 30
RECOVER_DASH_TIME :: 240

MAX_NUM_BODY :: 20
MAX_NUM_MOVERS :: 100
MAX_NUM_CANDIES :: 10
CANDY_SIZE :: 16
CANDY_RESPAWN_TIME :: 20


MAX_NUM_ENEMIES :: 10
ENEMY_RESPAWN_TIME :: 100
ENEMY_SPEED :: 1
ENEMY_COLLIDER_THRESHOLD :: 4

EPSILON :: 0.5

SMOOTHING :: 0.1
BULLET_SPEED :: 4
BULLET_SIZE :: 16

NUM_RECTANGLES_ON_SCENE :: 100
NUM_ENTITIES :: 1000


main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "snake_invaders")
	rl.InitAudioDevice()

	rl.SetTargetFPS(60)

	load_sounds()
	load_textures()

	bg_music := rl.LoadMusicStream("assets/bg_music.mp3")
	rl.SetMusicVolume(bg_music, 0.001)
	rl.PlayMusicStream(bg_music)


	game := Game {
		player = &Player{ghost_pieces = &Ringuffer_t{}, body = [MAX_NUM_BODY]cell_t{}},
		scene = &scene_t{},
		audio = audio_system_t{fx = make([dynamic]^rl.Sound, 0, 20), bg_music = bg_music},
	}

	load_scene(&game, .ONE)


	for !rl.WindowShouldClose() {
		rl.UpdateMusicStream(game.audio.bg_music)
		switch game.state {
		case .PLAY:
			get_input(&game)
			update(&game)

			rl.BeginDrawing()
			draw_game(&game)
			rl.ClearBackground(rl.BLACK)
			rl.EndDrawing()

		case .PAUSE:
			get_input_pause(&game)
			rl.BeginDrawing()
			rl.DrawText("PAUSED GAME", SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2, 30, rl.RED)
			rl.ClearBackground(rl.BLACK)
			rl.EndDrawing()
		case .QUIT:
			clean_up(&game)
		case .DEAD:
			text_position := Vector2{SCREEN_WIDTH, SCREEN_HEIGHT} / 2
			get_input_pause(&game)
			rl.BeginDrawing()

			rl.DrawTextEx(rl.GetFontDefault(), "WANT TO PLAY AGAIN?", text_position, 30, 6, rl.RED)
			rl.ClearBackground(rl.BLACK)
			rl.EndDrawing()

		}
	}
}
