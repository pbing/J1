# Create firmware

j1.mif j1.lst: *.fs Makefile
	gforth -e 'include main.fs bye'

sim: j1.mif
	cp $< ../sim

syn: j1.mif
	cp $< ../syn
