bin/ds: build/main.o
	mkdir -p bin
	ld build/main.o -o bin/ds
build/main.o: src/main.s
	mkdir -p build
	as --gstabs -I src/inc -o build/main.o src/main.s
run: bin/ds
	./bin/ds
clean:
	rm -rf bin build
