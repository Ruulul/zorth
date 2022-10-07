: dup  0 pick ;
: 2drop drop drop ;
: over 1 pick ;
: swap 1 roll ;
: rot  2 roll ;
: cr  10 emit ;
: true -1 ;
: false 0 ;
variable delimiter
: reset-delimiter 32 delimiter ! ;
reset-delimiter
: (   40 delimiter ! parse 2drop reset-delimiter ;
: \   -1 delimiter ! parse 2drop reset-delimiter ;
: ."  34 delimiter ! parse  type reset-delimiter ;
: / /mod drop ;
: % /mod swap drop ;
: mod % ;