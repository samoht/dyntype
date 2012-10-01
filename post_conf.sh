#!/bin/sh -e

PP_DIR=`ocamlfind query type_conv -predicates syntax,preprocessor -r -format "-I %d %a"`

echo "pp_command=\"camlp4o $PP_DIR\"" >> setup.data
