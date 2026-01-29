VPATH := $(shell find src -type d)
sources := $(shell find src -name *.s -type f)
objects := $(sources:src/%.s=build/%.o)

bin/ds: $(objects)
	mkdir -p bin
	ld $(objects) -o bin/ds
build/%.o: %.s
	mkdir -p $(VPATH:src/%=build/%)
	as -g -I src/inc -o $@ $<
run: bin/ds
	./bin/ds
debug: bin/ds
	gdb ./bin/ds
clean:
	rm -rf bin build
