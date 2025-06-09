build:
	@rm -f odin 
	odin build ./src/ -out:snake_invaders
exec: 
	./snake_invaders
run:
	odin run ./src/
