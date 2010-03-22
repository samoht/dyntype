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
	$(SUDO) ocamlfind install dyntype META \
		type.o type.cmi type.cmo type.cmx \
		value.o value.cmi value.cmo value.cmx \
		pa_dyntype.cma p4_type.cmi p4_value.cmi

java:
	ocamljava -I +camlp4 -c value.mli value.ml type.mli type.ml

javainstall:
	cp value.cmj value.jo type.cmj type.jo $(shell ocamlfind printconf path)/dyntype/

uninstall:
	$(SUDO) ocamlfind remove dyntype

reinstall:
	$(MAKE) uninstall
	$(MAKE) install

include $(OCAMLMAKEFILE)
