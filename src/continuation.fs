\ Continuation
\
\ Simple system for saving and restoring program state: the
\ data and return stacks.
\
\ Example usage for coroutines is
\
\ : task1 begin pause again ;
\ create /task1 130 allot \ 2 + 64 + 64
\ /task1 taskptr !
\ ' task1 launch
\ ... progress ... progress ... progress ...

variable taskptr
variable _dsp

\ save D and R in taskptr
: pause ( -- )
    dsp _dsp @ -  taskptr @ !
    taskptr @  dup cell+  swap @  dup>r

    \ data stack
    h# ff and
    begin  dup  while  >r  tuck !  cell+  r> 1-  repeat
    drop
    
    \ return stack
    r> d# 7 rshift  bounds
    begin  2dupxor  while  r> over !  cell+  repeat
    2drop ;

\ restore D and R from taskptr
: progress ( -- )
    dsp _dsp !
    taskptr @  dup@ cells
    dup>r  h# ff and
    over +  r> d# 8 rshift over +

    \ return stack
    begin  2dupxor  while  dup@ >r  cell-  repeat
    drop

    \ data stack
    begin  2dupxor  while  dup@ -rot  cell-  repeat
    2drop ;

\ init taskptr with rsp=1 and dsp=0
: launch ( xt -- )
    taskptr @  h# 0100 over !  cell+ ! ;
