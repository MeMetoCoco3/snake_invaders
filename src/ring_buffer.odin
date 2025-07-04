package main
import "core:fmt"

MAX_RINGBUFFER_VALUES :: 20

Ringuffer_t :: struct {
	values: []cell_ghost_t,
	head:   i8,
	tail:   i8,
	count:  i8,
}


put_cell :: proc(rb: ^Ringuffer_t, cell: cell_ghost_t) {
	if rb.count >= MAX_RINGBUFFER_VALUES {
		return
	}
	rb.values[rb.tail] = cell

	rb.tail = (rb.tail + 1) % MAX_RINGBUFFER_VALUES
	rb.count += 1
}


pop_cell :: proc(rb: ^Ringuffer_t) -> (cell_ghost_t, bool) {
	if rb.count == 0 {
		return cell_ghost_t{}, false
	}

	popped_cell := rb.values[rb.head]

	rb.head = (rb.head + 1) % MAX_RINGBUFFER_VALUES
	rb.count -= 1

	return popped_cell, true
}

peek_head :: proc(rb: ^Ringuffer_t) -> (cell_ghost_t, bool) {
	if rb.count == 0 {
		return cell_ghost_t{}, false
	}
	return rb.values[rb.head], true
}

peek_tail :: proc(rb: ^Ringuffer_t) -> (cell_ghost_t, bool) {
	if rb.count == 0 {
		return cell_ghost_t{}, false
	}
	return rb.values[rb.tail], true
}
