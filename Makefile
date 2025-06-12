build:
	@rm -f odin 
	odin build ./src/ -out:snake_invaders
exec: 
	./snake_invaders
run:
	odin run ./src/
build_debug: 
	odin build ./src/ -out:debug_invaders -o:none -debug
debug: 
	gdb debug_invaders
