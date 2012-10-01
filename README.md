`Dyntype` is a syntax extension which makes OCaml types and values easier to manipulate programmatically.  It consists of two parts, to manipulate types and values separately.

Installation
============

You can download the latest distribution from Github at <http://github.com/mirage/dyntype>.  It depends on:

* `ocaml`: 3.12.1+ is required for the latest `camlp4` extension. Earlier versions will definitely not work.

* `type-conv`: available from <https://ocaml.janestreet.com>, version 108.07.00 or higher.  If you have an older version of `type-conv`, please downgrade to dyntype-0.8.5 instead of this version.

The library installs an ocamlfind META file, so use it with the `dyntype.syntax` package.  To compile a file `foo.ml` with Dyntype and findlib, do:

    ocamlfind ocamlopt -syntax camlp4o -package dyntype.syntax -c t.ml

To link it into a standalone executable:

    ocamlfind ocamlopt -syntax camlp4o -linkpkg -package dyntype.syntax t.ml

You can report issues using the Github issue tracker at <http://github.com/mirage/dyntype/issues>, or mail the authors at <mailto:mirage@recoil.org>.  If you use Dyntype somewhere, feel free to drop us a short line and we can add your project to the Wiki as well.

We recommend you install Dyntype using the OPAM package manager, available at <http://opam.ocamlpro.com>.

Dynamic Types
=============

The type library converts an ML type definition annotated with the keyword `type_of` into a finite ML value representing that type and usable at runtime.  For a given type `t`, the library will generate a value `type_of_t` of type `Type.t` defined as:

    module Type = struct
      type t =
        | Unit | Bool | Float | Char | String
        | Int of int option
        | Arrow of t * t
        | Option of t
        | Enum of t
        | Tuple of t list
        | Dict of [`R|`O] * ( string * [`RW|`RO] * t ) list
        | Sum of [`P|`N] * ( string * t list ) list
        | Ext of string * t
        | Rec of string * t
        | Var of string
    end

This is a simpler representation than the full syntax exposed by `camlp4` (e.g. objects and records are coalesced into a `Dict` value).

The basic types are similar to the usual OCaml basic types, i.e. `Bool`, `Float`, `Char` and `String`, which can be composed using `Arrow`. Integers have an additional bit-width range parameter that can be 31-, 32-, 63- or 64-bit depending on the exact OCaml type and host architecture, or unlimited for `BigInt` types.  These basic types can be composed to form either a `Tuple`, a record (`R) or an object (`O) with `Dict`, or a normal (`N) or polymorphic (`P) variant with `Sum`.

For example, consider the following code fragment:

    type tuple = int32 * string with type_of
    type record = { mutable foo : string } with type_of
    type variant = Foo | Bar of bool with type_of

This fragment will generate the following additional values:

    let type_of_tuple = Ext ( "tuple", Tuple [ Int (Some 32); String ] )
    let type_of_record = Ext ( "record", Dict ( `R, [ ("foo", `RW, String) ]) )
    let type_of_variant = Ext ( "variant", Sum (`N, [ ("Foo", []) ; ("Bar", [Bool]) ]) )

Types variables are handled by induction on the type structure in which they are used.  Hence, the type definition...

    type t = x option with type_of

...will generate the ML expression: 

    let type_of_t = Ext ( "t", Option type_of_x)

In this case, `type_of_x` has to be defined for the program to compile. This definition may have either been automatically generated previously by `type_of`, or have been defined by the user. The latter option makes the `type_of` library easily extensible, especially for abstract types.

Recursive types
---------------

Recursive types are handled carefully in order to always keep a finite representation of the ML type. This is done using the constructors `Rec` and `Var`. `Rec(v, t)` is the binding of the type variable `v` to the type expression `t`. `Var v` always appears in the scope of a corresponding `Rec(v,t)` and is equivalent to the substitution of `Var v` by `t` in `t`.

The following example shows the automatically generated code for simple recursive types:

    (* User-defined datatype *)
    type t = { x : x } and x = { t : t } with type_of

    (* Auto-generated code *)
    let type_of_t = Rec ( "t", Dict (`N, [ "x", Ext ( "x", Dict (`N, [ "t", Var "t"]) ) ]) )
    let type_of_x = Rec ( "x", Dict (`N, [ "t", Ext ( "t", Dict (`N, [ "x", Var "x"]) ) ]) )

Dynamic Values
==============

The purpose of the `value` library is to make runtime value introspection available in OCaml. It works on any ML type definition annotated with the keyword `value` a pair of functions which marshall/unmarshall any value of that type into a simpler and well-defined ML value. Hence, for a given type `t`, the library generates two functions `value_of_t : t -> Value.t` and `t_of_value : Value.t -> t`, where `Value.t` is defined as:

    module Value = struct
      type t =
        | Int of int64 | Bool of bool | Float of float | String of string
        | Arrow of string
        | Enum of t list
        | Tuple of t list
        | Dict of (string * t) list
        | Sum of string * t list
        | Null
        | Value of t
        | Ext of (string * int64) * t
        | Rec of (string * int64) * t
        | Var of (string * int64)
    end

Values whose type uses a type variable are built by induction on that type, as with the `type` library described earlier. For a type variable `t`, the user can add the keyword `value` to the type definition of `t`, and let the `value` library generates the `value_of_t` and `t_of_value` functions. In the following example, `value_of_x` and `x_of_value` might either be auto-generated from the definition of `t` or be user-defined:

    (* User-defined datatype *)
    type t = x option with value

    (* Auto-generated code *)
    let value_of_t = function
      | None -> Ext (("t", 0), Null)
      | Some x -> Ext (("t", 0), Value (value_of_x x))

    let t_of_value = function
      | Ext(("t", _), Null) -> None
      | Ext(("t", _), Value x) -> Some (x_of_value x)
      | _ -> failwith "runtime error"
