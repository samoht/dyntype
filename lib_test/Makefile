OCAMLMAKEFILE=../OCamlMakefile
ANNOTATE = yes

.PHONY: run
run: dc
	./$(RESULT) -verbose

PACKS = unix oUnit dyntype.value dyntype.syntax
PREDS = camlp4o

RESULT= run_test
TESTS=  test_value test_type

SOURCES= $(TESTS:%=%.ml) suite.ml

pc_%:
	$(MAKE) -f Makefile.debug $@

p_%:
	$(MAKE) -f Makefile.debug $@

pi_%:
	$(MAKE) -f Makefile.debug $@

i_%:
	$(MAKE) -f Makefile.debug $@

-include $(OCAMLMAKEFILE)
