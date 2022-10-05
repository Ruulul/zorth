: dup  0 pick ;
: over 1 pick ;
: swap 1 roll ;
: rot  2 roll ;
: cr  10 emit ;
: ( 40 delimiter ! parse drop ;
: \ -1 delimiter ! parse drop ;
: / /mod drop ;
: mod /mod swap drop ;