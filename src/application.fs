\ Application
\
\ * disable multi-tasking
\   hex-display will be updated every three seconds
\
\ * enable  multi-tasking
\   hex-display will be updated every millisecond

true constant multi-tasking

module[ application"

include io-addr.fs
include hex-display.fs
include led.fs

multi-tasking [IF]
    \ enable multi-tasking
    include continuation.fs
[ELSE]
    \ disable multi-tasking
    : pause ( -- ) ;
    : progress ( -- ) ;
[THEN]

: wait    ( u -- )   0do loop ;
: wait-ms ( u -- )   0do  pause  d# 1400 wait  loop ;

: task1 ( -- )
    d# 1
    begin
	led-walk
	d# 3000 wait-ms
    again ;


multi-tasking [IF]
    \ enable multi-tasking
    create /task1 130 allot \ 2 + 64 + 64

    : main ( --)
	/task1 taskptr !
	['] task1 launch

	begin
	    progress
	    hex-select
	again ;
[ELSE]
    \ disable multi-tasking
    : main ( --)
	d# 1
	begin
	    led-walk
	    d# 3000 wait-ms
	    hex-select
	again ;
[THEN]

]module
