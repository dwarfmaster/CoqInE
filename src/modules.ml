(** Translation of Coq modules *)

open Declarations

let translate_constant_type out env constant_type =
  match constant_type with
  | NonPolymorphicType(a) ->
      Terms.translate_types out env a
  | PolymorphicArity(rel_context, polymorphic_arity) ->
      failwith "Polymorphic arity"

let translate_constant_body out env label constant_body =
  let name = Name.translate_label label in
  (* TODO: Handle [constant_body.const_hyps] *)
  let const_type' = translate_constant_type out env constant_body.const_type in
  match constant_body.const_body with
  | Undef(inline) ->
      Dedukti.print out (Dedukti.declaration name const_type')
  | Def(constr_substituted) ->
      let constr' = Terms.translate_constr out env (Declarations.force constr_substituted) in
      Dedukti.print out (Dedukti.definition false name const_type' constr')
  | OpaqueDef(lazy_constr) ->
      let constr' = Terms.translate_constr out env (Declarations.force_opaque lazy_constr) in
      Dedukti.print out (Dedukti.definition true name const_type' constr')

let rec translate_module_body out env module_body =
  match module_body.mod_expr with
  | Some(struct_expr_body) -> translate_struct_expr_body out env struct_expr_body
  | None -> failwith "Empty module body"

and translate_struct_expr_body out env struct_expr_body =
  match struct_expr_body with
  | SEBstruct(structure_body) -> translate_structure_body out env structure_body
  | _ -> ()

and translate_structure_body out env structure_body =
  List.iter (translate_structure_field_body out env) structure_body

and translate_structure_field_body out env (label, structure_field_body) =
  match structure_field_body with
  | SFBconst(constant_body) -> translate_constant_body out env label constant_body
  | _ -> ()

