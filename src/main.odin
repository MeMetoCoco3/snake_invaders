package main

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/rand"
import vmem "core:mem/virtual"
import rl "vendor:raylib"

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

	LoadAnimations()
	LoadSprites()


	LoadSounds()

	bg_music := bg_music
	rl.SetMusicVolume(bg_music, 0.01)
	rl.PlayMusicStream(bg_music)


	game := Game {
		arena = &arena,
	}
	InitCamera(&game)
	LoadScene(&game, .ONE)

	for !rl.WindowShouldClose() {
		free_all(context.temp_allocator)
		game.fram_count += 1
		rl.UpdateMusicStream(game.audio.bg_music)
		switch game.state {
		case .PLAY:
			clear_dead(&game)
			update(&game)

			InputSystem(&game)
			IASystem(&game)
			CollisionSystem(&game)
			VelocitySystem(&game)

			DrawGame(&game)

		case .PAUSE:
			InputSystemPause(&game)

			rl.BeginDrawing()
			rl.DrawText("PAUSED GAME", SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2, 30, rl.RED)
			rl.ClearBackground(rl.BLACK)
			rl.EndDrawing()
		case .QUIT:
			CleanUp(&game)
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
	id := add_entity(
		world,
		player_mask,
		[]Component {
			PlayerData {
				.NORMAL,
				20,
				Vec2{0, 0},
				Vec2{0, 0},
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
			Position{Vec2{320, 320}, {PLAYER_SIZE, PLAYER_SIZE}},
			Velocity{{0, 0}, PLAYER_SPEED},
			Visual(animation_bank[ANIMATION.PLAYER]),
			Data{.PLAYER, .ALIVE, .GOOD},
			Collider{{320, 320}, PLAYER_SIZE, PLAYER_SIZE, true},
		},
	)

	arquetype := game.world.archetypes[player_mask]

	game.player_body = Body{}
	game.player_position = &arquetype.positions[0]
	game.player_velocity = &arquetype.velocities[0]
	game.player_data = &arquetype.players_data[0]
}
