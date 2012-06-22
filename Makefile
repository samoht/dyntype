NAME      = dyntype

PA_FILES  = p4_helpers p4_type p4_value pa_type pa_value
LIB_FILES = type value

INCLS = $(shell ocamlfind query type-conv.syntax -predicates syntax,preprocessor -r -format "-I %d %a")

##########################################################
NAME_FILES = _build/pa_lib/pa_$(NAME).cmxa \
             _build/pa_lib/pa_$(NAME).cma \
             _build/lib/$(NAME).cma \
             _build/lib/$(NAME).cmxa

_PA_FILES  = $(addprefix _build/pa_lib/,$(PA_FILES))
__PA_FILES = $(addsuffix .cmi,$(_PA_FILES)) \
             $(addsuffix .cmo,$(_PA_FILES)) \
             $(addsuffix .cmx,$(_PA_FILES))

_LIB_FILES  = $(addprefix _build/lib/,$(LIB_FILES))
__LIB_FILES = $(addsuffix .cmi,$(_LIB_FILES)) \
              $(addsuffix .cmo,$(_LIB_FILES)) \
              $(addsuffix .cmx,$(_LIB_FILES))

FILES = $(NAME_FILES) $(__PA_FILES) $(__LIB_FILES)

all:
	ocamlbuild $(NAME).cmxa $(NAME).cma
	ocamlbuild pa_$(NAME).cma pa_$(NAME).cmxa


install:
	ocamlfind install $(NAME) META $(FILES)

uninstall:
	ocamlfind remove $(NAME)

clean:
	ocamlbuild -clean
	rm -rf suite.byte

.PHONY: test
test:
	ocamlbuild -pp "camlp4o $(INCLS) lib/$(NAME).cma pa_lib/pa_$(NAME).cma" suite.byte --

.PHONY: test_exp
test_exp:
	camlp4orf $(INCLS) _build/lib/$(NAME).cma _build/pa_lib/pa_$(NAME).cma lib_test/test_type.ml -printer o > _build/test_type_exp.ml
	camlp4orf $(INCLS) _build/lib/$(NAME).cma _build/pa_lib/pa_$(NAME).cma lib_test/test_value.ml -printer o > _build/test_value_exp.ml

