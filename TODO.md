## RANDOM STUFF
-  Enemies need an animation as Visual component.

## Stuff done
- ~Fix ghost pieces after shotting.~
    - ~When picking candy and already shotting we have to change the size of last piece for full and new piece for last one.~
    - ~We need to check ghost pieces when consuming~
    - ~We need to fix drawing position of pieces being consumed~

- ~Add state to the game~
- ~Load scenes.~
- ~Change shotting so it works correctly.~
- ~Add visuals and sounds.BANK OF ANIMATIONS~
- ~Mkae use of odin vector multiplication~
- ~Compose player from entity~
- ~BUG WHEN DEAD AND PRESS ENTER: animation was being overwritten on load scene~

- ~Transform ecs functions to get a slice not com | com | com~
- ~Make ghost_cells have collider~
- ~Add state to enemies.~
- ~Enemy3: Coin thief~

## Stuff to do
- Apply vtable for draw call on every Visual, probably warp it on struct like ia, and just pass the data, if more needed like pos, we will see
- Enemy4: Walker (walks towards you or some shit)
- Enemy5: Dasher (dashes towards you or some shit)
- Add other objectives for player.


## Stuff I tried and did not work
- We cant make use of the bitsets from odin,because we would need extra space, and an enum cannot be a long int
