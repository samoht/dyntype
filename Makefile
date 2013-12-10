.PHONY: all clean install build
all: build doc

J ?= 2
PREFIX ?= /usr/local
NAME=dyntype

ifeq "$(NO_EXECUTABLES)" ""
TESTS ?= --enable-tests
endif

setup.bin: setup.ml
	ocamlopt.opt -o $@ $< || ocamlopt -o $@ $< || ocamlc -o $@ $<
	rm -f setup.cmx setup.cmi setup.o setup.cmo

setup.data: setup.bin
	./setup.bin -configure --prefix $(PREFIX) $(TESTS)

build: setup.data setup.bin
	./setup.bin -build -j $(J)

doc: setup.data setup.bin
	./setup.bin -doc

install: setup.bin
	./setup.bin -install

test: setup.bin build
	./setup.bin -test

fulltest: setup.bin build
	./setup.bin -test

reinstall: setup.bin
	ocamlfind remove $(NAME) || true
	./setup.bin -reinstall

clean:
	ocamlbuild -clean
	rm -f setup.data setup.log setup.bin
