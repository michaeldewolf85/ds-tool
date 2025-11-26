bin/ds-tool: obj/main.o
	mkdir -p bin
	ld obj/main.o -o bin/ds-tool
obj/main.o:
	mkdir -p obj
	as -I src/inc -o obj/main.o src/main.s
run: bin/ds-tool
	./bin/ds-tool
clean:
	rm -rf bin obj
