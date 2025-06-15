build:
	@rm -f odin 
	odin build ./src/ -out:snake_invaders
exec: 
	./snake_invaders
run:
	odin run ./src/
debug: 
	odin build ./src/ -out:debug_invaders -o:none -debug
	gdb -tui debug_invaders
