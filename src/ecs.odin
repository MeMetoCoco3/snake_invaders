package main

import "core:fmt"
import rl "vendor:raylib"

Archetype :: struct {
	component_mask: COMPONENT_ID,
	entities_id:    [dynamic]u32,
	positions:      [dynamic]Position,
	velocities:     [dynamic]Velocity,
	sprites:        [dynamic]Sprite,
	animations:     [dynamic]Animation,
	data:           [dynamic]Data,
	colliders:      [dynamic]Collider,
	ias:            [dynamic]IA,
	players_data:   [dynamic]PlayerData,
}

Entity :: struct {
	id:        u32,
	archetype: ^Archetype,
}

World :: struct {
	entity_count: u32,
	archetypes:   map[COMPONENT_ID]^Archetype,
}

new_world :: proc() -> ^World {
	world := new(World)
	world.entity_count = 0
	world.archetypes = make(map[COMPONENT_ID]^Archetype)
	return world
}


add_entity :: proc(world: ^World, mask: COMPONENT_ID) -> u32 {
	arch := world.archetypes[mask]
	if arch == nil {
		arch = alloc_archetype(mask)
		world.archetypes[mask] = arch
	}

	entity_id := world.entity_count
	world.entity_count += 1

	append(&arch.entities_id, entity_id)
	return entity_id
}

kill_entity :: proc(archetype: ^Archetype, id: u32) {
	for entity_id, i in archetype.entities_id {
		if entity_id == id {
			archetype.data[i].state = .DEAD
		}
	}
}

alloc_archetype :: proc(mask: COMPONENT_ID) -> ^Archetype {
	archetype := new(Archetype)
	archetype.component_mask = mask


	for i := COMPONENT_ID.POSITION; i != .COUNT; {
		if (i & mask) == i {
			init_component(archetype, i)
		}
		i = COMPONENT_ID(u64(i) << 1)
	}

	return archetype
}


query_archetype :: proc(world: ^World, mask: COMPONENT_ID) -> ([dynamic]^Archetype, bool) {
	archetypes := make([dynamic]^Archetype) //  TODO: IM NOT FREEING THIS!!
	empty := true
	for k, v in world.archetypes {
		if (k & mask) == mask {
			append(&archetypes, v)
			empty = false
		}
	}

	return archetypes, empty
}
