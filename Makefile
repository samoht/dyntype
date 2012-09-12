NAME      = dyntype

INCLS = $(shell ocamlfind query type_conv -predicates syntax,preprocessor -r -format "-I %d %a")

BASE_FILES = _build/pa_lib/pa_dyntype _build/lib/dyntype
FILES =  $(addsuffix .cmi,$(BASE_FILES)) $(addsuffix .cma,$(BASE_FILES)) $(addsuffix .cmxa,$(BASE_FILES)) $(addsuffix .a,$(BASE_FILES))

all:
	ocamlbuild $(NAME).cmxa $(NAME).cma
	ocamlbuild pa_$(NAME).cma pa_$(NAME).cmxs


install:
	ocamlfind remove $(NAME) || true
	ocamlfind install $(NAME) META -optional $(FILES)

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

