(*
 * Copyright (c) 2009 Anil Madhavapeddy <anil@recoil.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

open Printf

(* --- Type definitions *)

type sql_type = 
  |Int     |Real
  |Text    |Blob
  |Null    

type table_type =
  |Exposed        (* table is an exposed external type *)
  |Transient      (* table is internal (e.g. list) *)

type field_info =
  |External_and_internal_field
  |External_field
  |Internal_field
  |Internal_tuple_field of string * int (* is a tuple to field string at pos int *)
  |Internal_autoid
  |External_foreign of string

type env = {
  e_tables: table list;
}
and table = {
  t_name: string;
  t_fields: field list;
  t_type: table_type;
  t_child: string list; (* sub-tables created from this one *)
}
and field = {
  f_name: string;
  f_typ: sql_type;
  f_ctyp: Types.typ option;
  f_opt: bool;
  f_info: field_info;
}

(* --- String conversion functions *)

let string_map del fn v =
  String.concat del (List.map fn v)

let string_of_sql_type f = 
  match f.f_typ, f.f_info with
  |Int,Internal_autoid -> "INTEGER PRIMARY KEY AUTOINCREMENT"
  |Int,_ -> "INTEGER"
  |Real,_ -> "REAL"
  |Text,_ -> "TEXT"
  |Blob,_ -> "BLOB"
  |Null,_ -> "NULL"    

let string_of_field_info = function
  |External_and_internal_field -> "E+I"
  |External_field -> "E"
  |Internal_field -> "I"
  |External_foreign f -> sprintf "F[%s]" f
  |Internal_tuple_field (s,i) -> sprintf "T%d" i
  |Internal_autoid -> "A"

let string_of_field f =
  sprintf "%s (%s):%s%s" f.f_name (string_of_field_info f.f_info) (string_of_sql_type f) (if f.f_opt then " opt" else "")
let string_of_table t =
  sprintf "%s (children=%s): [ %s ] " t.t_name (String.concat ", " t.t_child) (string_map ", " string_of_field t.t_fields)
let string_of_env e =
  string_map "\n" string_of_table e.e_tables

(* --- Helper functions to manipulate environment *)

let empty_env = { e_tables = [] }

let find_table env name =
  try
    Some (List.find (fun t -> t.t_name = name) env.e_tables)
  with
    Not_found -> None

(* replace the table in the env and return new env *)
let replace_table env table =
  { e_tables = table :: 
    (List.filter (fun t -> t.t_name <> table.t_name) env.e_tables)
  }

let new_table ~name ~fields ~parent env =
  (* stick in the new table *)
  let ty = match parent with |None -> Exposed |Some _ -> Transient in
  let env = replace_table env (match find_table env name with 
    |None -> { t_name=name; t_fields=fields; t_type=ty; t_child=[] }
    |Some table -> failwith (sprintf "new_table: clash %s" name) 
  ) in
  (* check if the table is a child and update parent child list if so *)
  match parent with
    |None -> env
    |Some t -> begin
      match find_table env t with
      |None -> failwith (sprintf "couldnt find parent table %s" t)
      |Some ptable -> replace_table env { ptable with t_child=name::ptable.t_child }
    end

exception Field_name_not_unique
(* add field to the specified table, and return a modified env *)
let add_field ~opt ~ctyp ~info env t field_name field_type =
  let ctyp = match ctyp,opt with 
    |Some ctyp,true -> Some (Types.Option (Types.loc_of_typ ctyp, ctyp)) 
    |_ -> ctyp
  in
  let field = { f_name=field_name; f_typ=field_type; f_opt=opt; f_ctyp=ctyp; f_info=info } in
  match find_table env t with
  |Some table -> begin
    (* sanity check that the name is unique in the field list *)
    match List.filter (fun f -> f.f_name = field.f_name) table.t_fields with
    |[] -> 
      (* generate new table and replace it in the environment *)
      let table' = {table with t_fields = field :: table.t_fields } in
      replace_table env table'
    |_ -> raise Field_name_not_unique
  end
  |None ->
    prerr_endline (sprintf "warning: add_field: %s:f U %s:T failed" field.f_name t);
    env

(* --- Accessor functions to filter the environment *)

(* list of tables for top-level code generation *)
let exposed_tables env =
  List.filter (fun t ->
     t.t_type = Exposed
   ) env.e_tables

(* helper fn to lookup a table in the env and apply a function to it *)
let with_table fn env t =
  match find_table env t with
  |None -> 
    failwith (sprintf "internal error: exposed fields table '%s' not found" t)
  |Some table ->
    fn env table

let filter_fields_with_table fn =
   with_table (fun env table ->
     List.filter fn table.t_fields
   )

(* list of fields suitable for external ocaml interface *)
let exposed_fields =
   filter_fields_with_table (fun f ->
     match f.f_info with
     |External_and_internal_field
     |External_field 
     |Internal_autoid
     |External_foreign _ -> true
     |Internal_field
     |Internal_tuple_field _ -> false
   )

(* list of fields suitable for SQL statements *)
let sql_fields =
   filter_fields_with_table (fun f ->
     match f.f_info with
     |External_and_internal_field
     |External_foreign _
     |Internal_tuple_field _
     |Internal_field 
     |Internal_autoid -> true
     |External_field -> false
   )

(* same as sql_fields but with the auto_id field filtered out *)
let sql_fields_no_autoid =
   filter_fields_with_table (fun f ->
     match f.f_info with
     |External_and_internal_field
     |External_foreign _
     |Internal_field
     |Internal_tuple_field _ -> true
     |Internal_autoid
     |External_field -> false
   )

(* get the foreign single fields (ie foreign tables which arent lists) *)
let foreign_single_fields =
  filter_fields_with_table (fun f ->
    match f.f_info with
    |External_foreign _ -> true
    |_ -> false
  )

(* retrieve the single Auto_id field from a table *)
let auto_id_field =
  with_table (fun env table ->
    match List.filter (fun f -> f.f_info = Internal_autoid) table.t_fields with
    |[f] -> f
    |[] -> failwith (sprintf "auto_id_field: %s: no entry" table.t_name)
    |_ -> failwith (sprintf "auto_id_field: %s: multiple entries" table.t_name)
 
  )

(* extract the ocaml type field for a field *)
let ctyp_of_field f =
  match f.f_ctyp with
  |None -> failwith ("ctyp_of_field: " ^ f.f_name)
  |Some c -> c

(* retrieve fields which came from a tuple and group them by name *)
let tuple_fields =
  with_table (fun env table ->
    let h = Hashtbl.create 1 in
    List.iter (fun f -> match f.f_info with
      |Internal_tuple_field (n,pos) ->  begin
        let l = try Hashtbl.find h n with Not_found -> [] in
        Hashtbl.replace h n (f::l)
      end
      |_ -> ()
    ) table.t_fields;
    h
  )
(* --- Process functions to convert OCaml types into SQL *)

exception Type_not_allowed of string
let rec process ?(opt=false) ?(ctyp=None) ?(info=External_and_internal_field) env t ml_field =
  let n = ml_field.Types.f_id in
  let ctyp = Some ml_field.Types.f_typ in
  match ml_field.Types.f_typ with
  (* basic types *)
  |Types.Unit _        -> add_field ~opt ~ctyp ~info env t n Int
  |Types.Int  _        -> add_field ~opt ~ctyp ~info env t n Int
  |Types.Int32 _       -> add_field ~opt ~ctyp ~info env t n Int
  |Types.Int64 _       -> add_field ~opt ~ctyp ~info env t n Int
  |Types.Bool _        -> add_field ~opt ~ctyp ~info env t n Int
  |Types.Char _        -> add_field ~opt ~ctyp ~info env t n Int
  |Types.Float _       -> add_field ~opt ~ctyp ~info env t n Real
  |Types.String _      -> add_field ~opt ~ctyp ~info env t n Text 
  (* complex types *)
  |Types.Apply(_,[],id,[]) ->
    add_field ~opt ~ctyp ~info:(External_foreign id) env t n Int
  |Types.Record (loc,fl)
  |Types.Object (loc,fl) -> 
    (* add an id to the current table *)
    let env = add_field ~opt ~ctyp ~info:(External_foreign n) env t n Int in
    (* add a new table to the environment *)
    let env = new_table ~name:n ~fields:[] ~parent:None env in
    (* process the fields in the new record *)
    let env = add_field ~opt:true ~ctyp:(Some (Types.Int64 loc))
       ~info:(Internal_autoid) env n "id" Int in
    List.fold_right (fun field env -> process env n field) fl env
  |Types.Array (_,ty)
  |Types.List (_,ty)   ->
    (* create a new table for the list lookup *)
    let t' = sprintf "%s_%s_list" t n in
    (* add table to env to represent the list *)
    let env = new_table ~name:t' ~fields:[] ~parent:(Some t) env in
    (* add in the list fields to the new table *)
    let env = add_field ~opt ~ctyp ~info:External_field env t n Null in
    let env = add_field ~opt ~ctyp ~info:(External_foreign t) env t' t Int in
    let env = add_field ~opt ~ctyp ~info:Internal_field env t' "_idx" Int in
    process env t' { ml_field with Types.f_typ=ty }
  |Types.Tuple (_,tyl) ->
    let i = ref 0 in
    let env = add_field ~opt ~ctyp ~info:External_field env t n Null in
    List.fold_left (fun env ty ->
      incr i;
      let info = Internal_tuple_field (ml_field.Types.f_id, !i) in
      process ~info env t { ml_field with Types.f_id=sprintf "%s%d" n !i; f_typ=ty }
    ) env tyl
  |Types.Option (_,ty) ->
    process ~opt:true env t { ml_field with Types.f_typ=ty }
  |Types.Variant (loc, itl) -> 
    (* Just unoptimised with a unique set of columns per branch at the moment *)
    let env = new_table ~name:n ~fields:[] ~parent:(Some t) env in
    let env = add_field ~opt ~ctyp ~info env n "_idx" Int in
    List.fold_right (fun (id,tyl) env ->
       process env n { ml_field with Types.f_id=id; f_typ=Types.Tuple(loc, tyl) }
    ) itl env
  (* types we dont handle for the moment *)
  |Types.Ref _
  |Types.PolyVar _
  |Types.Var _
  |Types.Abstract _ 
  |Types.Apply _
  |Types.Arrow _ as x -> raise (Type_not_allowed (Types.string_of_typ x))

let process_top t =
  let env = { e_tables = [] } in
   process env "top" t

