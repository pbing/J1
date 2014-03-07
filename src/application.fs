\ Application
module[ application"

include io-addr.fs
include hex-display.fs
include led.fs

: wait      ( u -- ) d# 0 do loop ;
: wait-1000 ( u -- ) d# 0 do d# 1000 wait loop ;

: main ( --)
  d# 1
  begin
    hex-select
    led-walk
    d# 100 wait-1000
  again ;

]module
