-module(mates).
-export([perimetro/1]).
-import(math,[pi/0]).

perimetro({square,Side}) -> 4 * Side;
perimetro({circle,Radius}) -> pi() * 2 * Radius;
perimetro({triangle,A,B,C}) -> A + B + C.