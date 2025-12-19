bin/ds: build/ds.o
	mkdir -p bin
	ld build/ds.o -o bin/ds
build/ds.o: src/main.s
	mkdir -p build
	as --gstabs -I src/inc -o build/ds.o src/main.s src/proc/read.s src/proc/evaluate.s src/lib/util.s
run: bin/ds
	./bin/ds
print: $(wildcard *.s)
	ls -la  $?
clean:
	rm -rf bin build
