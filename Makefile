build:
	@rm -f odin 
	odin build ./src/ -out:snake_invaders

exec: 
	./snake_invaders
run:
	odin run ./src/
run_c: 
	odin run ./src/ -define:DEBUG_COLISION=true
debug: 
	odin build ./src/ -out:debug_invaders -o:none -debug
	gdb  debug_invaders
