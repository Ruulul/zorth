: dup  0 pick ;
: over 1 pick ;
: swap 1 roll ;
: rot  2 roll ;
: cr  10 emit ;
: (   40 delimiter ! parse drop 32 delimiter ! ;
: \   -1 delimiter ! parse drop 32 delimiter ! ;
: / /mod drop ;
: % /mod swap drop ;
: mod % ;