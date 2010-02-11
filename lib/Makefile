OCAMLMAKEFILE = ../OCamlMakefile
ANNOTATE = yes

SOURCES = value.ml p4_value.ml pa_value.ml type.ml p4_type.ml pa_type.ml
PACKS = type-conv
RESULT = pa_dyntype
USE_CAMLP4 = yes

.PHONY: all
all: bcl ncl
	@ :

install: all
	$(SUDO) ocamlfind install dyntype META type.{o,cm{i,o,x}} value.{o,cm{i,o,x}} pa_dyntype.cma p4_type.cmi p4_value.cmi

uninstall:
	$(SUDO) ocamlfind remove dyntype

reinstall:
	$(MAKE) uninstall
	$(MAKE) install

include $(OCAMLMAKEFILE)
