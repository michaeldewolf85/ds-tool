sources := $(shell find src -name *.s -type f)
objects := $(sources:src/%.s=build/%.o)

bin/ds: build/ds.o
	mkdir -p bin
	ld build/ds.o -o bin/ds
build/ds.o: $(sources)
	mkdir -p build
	as -g -I src/inc -o build/ds.o $(sources)
run: bin/ds
	./bin/ds
clean:
	rm -rf bin build
