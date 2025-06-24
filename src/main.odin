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
MAX_NUM_CANDIES :: 1
CANDY_SIZE :: 16
CANDY_RESPAWN_TIME :: 2

MAX_NUM_ENEMIES :: 1
ENEMY_RESPAWN_TIME :: 10
ENEMY_SIZE :: 16
ENEMY_SPEED :: 1
ENEMY_COLLIDER_THRESHOLD :: 4
ENEMY_TIME_RELOAD :: 60
ENEMY_SIZE_BULLET :: 16
TIME_TO_CHANGE_STATE :: 200

EPSILON :: 0.5
EPSILON_COLISION :: 4
SMOOTHING :: 0.1
BULLET_SPEED :: 2
BULLET_SIZE :: 16

NUM_RECTANGLES_ON_SCENE :: 100
NUM_ENTITIES :: 1000

player_mask := COMPONENT_ID.POSITION | .VELOCITY | .ANIMATION | .DATA | .COLLIDER | .PLAYER_DATA

main :: proc() {
	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "snake_invaders")
	rl.InitAudioDevice()

	rl.SetTargetFPS(60)

	load_sounds()
	load_textures()

	bg_music := bg_music
	rl.SetMusicVolume(bg_music, 0.001)
	rl.PlayMusicStream(bg_music)

	world := new_world()

	add_player(world)
	player_arquetype := world.archetypes[player_mask]

	game := Game {
		player_body = Body{ghost_pieces = &Ringuffer_t{}, cells = [MAX_NUM_BODY]cell_t{}},
		player_position = &player_arquetype.positions[0],
		world = world,
		audio = audio_system_t{fx = make([dynamic]^rl.Sound, 0, 20), bg_music = bg_music},
	}

	load_scene(&game, .ONE)


	for !rl.WindowShouldClose() {
		rl.UpdateMusicStream(game.audio.bg_music)
		switch game.state {
		case .PLAY:
			clear_dead(&game)

			InputSystem(&game)

			IASystem(&game)
			CollisionSystem(&game)
			VelocitySystem(&game)

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


add_player :: proc(world: ^World) {
	add_entity(world, player_mask)

	player_arquetype := world.archetypes[player_mask]
	append(
		&player_arquetype.players_data,
		PlayerData{.NORMAL, Vector2{0, 0}, true, RECOVER_DASH_TIME, 3, 0, false},
	)

	player_position := Vector2{SCREEN_WIDTH / 2 + 10, SCREEN_HEIGHT / 2 + 10}
	append(&player_arquetype.positions, Position{player_position, {PLAYER_SIZE, PLAYER_SIZE}})
	append(&player_arquetype.velocities, Velocity{{0, 0}, PLAYER_SPEED})
	append(
		&player_arquetype.animations,
		Animation {
			image = &texture_bank[TEXTURE.TX_PLAYER],
			w = 16,
			h = 16,
			num_frames = 1,
			kind = .STATIC,
			angle_type = .DIRECTIONAL,
		},
	)
	append(&player_arquetype.data, Data{.PLAYER, .ALIVE, .GOOD, .NORMAL})
	append(
		&player_arquetype.colliders,
		Collider {
			player_position + EPSILON_COLISION,
			PLAYER_SIZE - 2 * EPSILON_COLISION,
			PLAYER_SIZE - 2 * EPSILON_COLISION,
		},
	)
}
