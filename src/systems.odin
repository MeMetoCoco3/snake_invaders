package main

import rl "vendor:raylib"


audio_system_t :: struct {
	bg_music: rl.Music,
	fx:       [dynamic]^rl.Sound,
}

FX :: enum {
	FX_EAT = 0,
	FX_SHOOT,
	FX_COUNT,
}


VelocitySystem :: proc(game: ^Game) {
	arquetypes := query_archetype(game.world, .Velocity | .Position)

	for arquetype in arquetypes {
		velocities := arquetype.velocities
		positions := arquetype.positions

		for i in 0 ..< len(arquetype.entities_id) {
			positions[i].position += (velocities[i].direction * velocities[i].speed)
		}
	}

}


PositionSystem :: proc(game: ^Game)
RenderingSystem :: proc(game: ^Game)
