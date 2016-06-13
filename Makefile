%.o:%.asm
	yasm -f elf64 -g dwarf2 $<

all: mclient sclient mserver sserver

mclient: mclient.o sig.o base.o
	gcc $^ -o $@

sclient: sclient.o sig.o base.o
	ld $^ -o $@ 

mserver: mserver.o sig.o base.o
	gcc $^ -o $@

sserver: sserver.o sig.o base.o
	ld $^ -o $@ 

clean:
	rm -f *.o *.s mclient sclient mserver sserver
