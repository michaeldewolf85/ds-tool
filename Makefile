bin/ds-tool: obj/main.o
	mkdir -p bin
	ld obj/main.o -o bin/ds-tool
obj/main.o:
	mkdir -p obj
	as src/main.s -o obj/main.o
clean:
	rm -rf bin obj
