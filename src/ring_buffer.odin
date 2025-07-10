package main
import "core:fmt"
import "core:math"
MAX_RINGBUFFER_VALUES :: 20

Ringuffer_t :: struct($T: typeid) {
	values: []T,
	head:   i8,
	tail:   i8,
	count:  i8,
}


print_ringbuffer :: proc(rb: ^Ringuffer_t($T)) {
	fmt.printfln("HEAD %v, TAIL %v, COUNT %v", rb.head, rb.tail, rb.count)
	fmt.print("[")
	for i: i8 = 0; i < rb.count; i += 1 {
		index := (rb.head + i) % MAX_RINGBUFFER_VALUES
		val := rb.values[index]
		fmt.printf("%v %v", index, val)
		if i < rb.count - 1 {
			fmt.print(", ")
		}
	}
	fmt.println("]")
}

put_cell :: proc(rb: ^Ringuffer_t($T), val: T) -> bool {
	// if rb.count >= MAX_RINGBUFFER_VALUES {
	// 	return false
	// }
	rb.values[rb.tail] = val

	rb.tail = (rb.tail + 1) % MAX_RINGBUFFER_VALUES
	rb.count += 1
	return true
}


pop_cell :: proc(rb: ^Ringuffer_t($T)) -> (T, bool) {
	if rb.count == 0 {
		return T{}, false
	}

	popped_val := rb.values[rb.head]

	rb.head = (rb.head + 1) % MAX_RINGBUFFER_VALUES
	rb.count -= 1

	return popped_val, true
}

peek_head :: proc(rb: ^Ringuffer_t($T)) -> (T, bool) {
	if rb.count == 0 {
		return T{}, false
	}
	return rb.values[rb.head], true
}

peek_last :: proc(rb: ^Ringuffer_t($T)) -> (T, bool) {
	if rb.count == 0 {
		return T{}, false
	}

	last_index := (MAX_RINGBUFFER_VALUES + rb.tail - 1) % MAX_RINGBUFFER_VALUES
	return rb.values[int(last_index)], true
}
