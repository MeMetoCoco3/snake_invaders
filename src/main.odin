package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/rand"
import vmem "core:mem/virtual"
import rl "vendor:raylib"

DEBUG_COLISION :: #config(DEBUG_COLISION, false)

AFTER_DEATH := false

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 800
PLAYER_SIZE :: 32
BODY_WIDTH :: 32
GRID_SIZE :: PLAYER_SIZE / 4
PLAYER_SPEED :: 4
DASH_DURATION :: 120
RECOVER_DASH_TIME :: 240
RECOVER_DMG_TIME :: 90

MAX_HEALTH :: 3
MAX_NUM_BODY :: 20
MAX_NUM_MOVERS :: 100
MAX_NUM_CANDIES :: 10
CANDY_SIZE :: 32
CANDY_RESPAWN_TIME :: 20

MAX_NUM_ENEMIES :: 30
ENEMY_RESPAWN_TIME :: 50
ENEMY_SIZE :: 32
ENEMY_SPEED :: 1
ENEMY_COLLIDER_THRESHOLD :: 4
ENEMY_TIME_RELOAD :: 60
ENEMY_SIZE_BULLET :: 32
TIME_TO_CHANGE_STATE :: 200

EPSILON :: 0.5
EPSILON_COLISION :: 4
SMOOTHING :: 0.1
BULLET_SPEED :: PLAYER_SPEED * 1.5
BULLET_SIZE :: 16

NUM_RECTANGLES_ON_SCENE :: 100
NUM_ENTITIES :: 1000


player_mask := (COMPONENT_ID.POSITION | .VELOCITY | .ANIMATION | .DATA | .COLLIDER | .PLAYER_DATA)
body_mask := (COMPONENT_ID.VELOCITY | .SPRITE | .POSITION | .PLAYER_DATA | .DATA | .COLLIDER)
ghost_mask := (COMPONENT_ID.POSITION | .DATA | .COLLIDER | .PLAYER_DATA)
atlas: rl.Texture2D
tx_candy: rl.Texture2D

main :: proc() {
	context.logger = get_logger()
	log.info("START")

	arena: vmem.Arena
	arena_allocator := vmem.arena_allocator(&arena)
	context.allocator = arena_allocator

	rl.InitWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "snake_invaders")
	rl.InitAudioDevice()

	rl.SetTargetFPS(60)

	atlas = rl.LoadTexture("assets/atlas.png")
	tx_candy = rl.LoadTexture("assets/coin.png")

	load_animations()
	load_sprites()


	load_sounds()

	bg_music := bg_music
	rl.SetMusicVolume(bg_music, 0.01)
	rl.PlayMusicStream(bg_music)


	game := Game {
		audio = audio_system_t{fx = make([dynamic]^rl.Sound, 0, 20), bg_music = bg_music},
		arena = &arena,
	}


	load_scene(&game, .ONE)
	player_arquetype, ok := game.world.archetypes[player_mask]

	for !rl.WindowShouldClose() {
		rl.UpdateMusicStream(game.audio.bg_music)
		switch game.state {
		case .PLAY:
			fmt.println(game.candy_respawn_time)
			clear_dead(&game)
			update(&game)

			InputSystem(&game)
			IASystem(&game)
			CollisionSystem(&game)
			VelocitySystem(&game)

			rl.BeginDrawing()
			draw_game(&game)
			rl.EndDrawing()

		case .PAUSE:
			InputSystemPause(&game)
			rl.BeginDrawing()
			rl.DrawText("PAUSED GAME", SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2, 30, rl.RED)
			rl.ClearBackground(rl.BLACK)
			rl.EndDrawing()
		case .QUIT:
			clean_up(&game)
		case .DEAD:
			InputSystemPause(&game)
			rl.BeginDrawing()
			rl.DrawText("WANT TO PLAY AGAIN?", SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2, 30, rl.RED)
			rl.ClearBackground(rl.BLACK)
			rl.EndDrawing()
		}
	}
}


add_player :: proc(game: ^Game) {
	world := game.world
	id := add_entity(world, player_mask)

	player_arquetype := world.archetypes[player_mask]
	append(
		&player_arquetype.players_data,
		PlayerData {
			.NORMAL,
			20,
			Vector2{0, 0},
			Vector2{0, 0},
			true,
			RECOVER_DASH_TIME,
			RECOVER_DMG_TIME,
			MAX_HEALTH,
			0,
			false,
			false,
			0,
			0,
			PLAYER_SIZE,
			0,
		},
	)

	player_position := Position{Vector2{320, 320}, {PLAYER_SIZE, PLAYER_SIZE}}

	append(&player_arquetype.positions, player_position)
	append(&player_arquetype.velocities, Velocity{{0, 0}, PLAYER_SPEED})
	append(&player_arquetype.animations, animation_bank[ANIMATION.PLAYER])

	append(&player_arquetype.data, Data{.PLAYER, .ALIVE, .GOOD})
	append(
		&player_arquetype.colliders,
		Collider{player_position.pos, PLAYER_SIZE, PLAYER_SIZE, true},
	)

	game.player_body = Body{}
	game.player_position = &player_arquetype.positions[0]
	game.player_velocity = &player_arquetype.velocities[0]
	game.player_data = &player_arquetype.players_data[0]
}
