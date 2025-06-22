package main
import rl "vendor:raylib"
Archetype :: struct {
	component_mask: u64,
	entities_id:    [dynamic]u32,
	positions:      [dynamic]Position,
	velocities:     [dynamic]Velocity,
	sprites:        [dynamic]Sprite,
}

Entity :: struct {
	id:        u32,
	archetype: ^Archetype,
	index:     u64,
}

World :: struct {
	entity_count: u32,
	archetypes:   map[u64]^Archetype,
}

new_world :: proc() -> ^World {
	world := new(World)
	world.entity_count = 0
	world.archetypes = make(map[u64]^Archetype)
	return world
}


add_entity :: proc(world: ^World, mask: u64, components: []Component) {
	arch := world.archetypes[mask]
	if arch == nil {
		arch = alloc_archetype(mask)
		world.archetypes[mask] = arch
	}

	entity_id := world.entity_count
	world.entity_count += 1

	append(&arch.entities_id, entity_id)

	for component in components {
		switch type in component {
		case Position:
			append(&arch.positions, component.(Position))
		case Velocity:
			append(&arch.velocities, component.(Velocity))
		case Sprite:
			append(&arch.sprites, component.(Sprite))
		}
	}

}


alloc_archetype :: proc(mask: u64) -> ^Archetype {
	archetype := new(Archetype)
	archetype.component_mask = mask


	for i := COMPONENT_ID.POSITION; i != .COUNT; {
		if (u64(i) & mask) == u64(i) {
			init_component(archetype, i)
		}
		i = u64(i) << 1
	}

	return archetype
}


query_archetype :: proc(world: ^World, mask: u64) -> []^Archetype {
	archetypes := make([dynamic]^Archetype)
	for k, v in world.archetypes {
		if (k & mask) == mask {
			append(&archetypes, v)
		}
	}

	return archetypes
}
