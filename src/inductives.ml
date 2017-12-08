open Declarations

open Info

(** Insert template levels as coq Sort parameters in an inductive declaration *)
let rec insert_params_in_arity params arity =
  match params with
  | [] -> arity
  | None::tl -> insert_params_in_arity tl arity
  | (Some lvl)::tl ->
    Dedukti.Pie ( (Dedukti.translate_univ_level lvl, Dedukti.coq_Sort),
                  insert_params_in_arity tl arity )

let rec insert_params_in_decl params decls =
  match (params, decls) with
  | [], _ -> decls
  | None::tl, h::t -> h::(insert_params_in_decl tl t)
  | (Some lvl)::tl, h::t ->
     (Dedukti.translate_univ_level lvl, Dedukti.coq_Sort) :: h :: (insert_params_in_decl tl t)
  | _ -> failwith "Error translating polymorphic arity"


(** An inductive definition is organised into:
    - [mutual_inductive_body] : a block of (co)inductive type definitions,
      containing a context of common parameter and list of [inductive_body]
    - [inductive_body] : a single inductive type definition,
      containing a name, an arity, and a list of constructor names and types **)

(** Translate the i-th inductive type in [mind_body]. *)
let translate_inductive info env label mind_body i =
  let ind_body = mind_body.mind_packets.(i) in (* Body of the current inductive type *)
  
  let name          = ind_body.mind_typename in
  let arity_context = ind_body.mind_arity_ctxt in
  let arity         = ind_body.mind_arity in
  
  let name' = Name.translate_element_name info env (Names.label_of_id name) in
  Debug.debug_string ("--- " ^ name');
  Debug.debug_coq_ctxt arity_context;
  
  let param_arity' = match arity with
  | RegularArity  ria -> begin
      (* Translate the regular inductive type. *)
      (* I : ||p1 : P1 -> ... -> pr : Pr -> x1 : A1 -> ... -> xn : An -> s|| *)
      let arity = Term.it_mkProd_or_LetIn (Term.mkSort ria.mind_sort) arity_context in
      Terms.translate_types info env (Info.empty ()) arity
    end
  | TemplateArity ta  -> begin
      Debug.debug_string "Template params levels:";
      List.iter (function   None -> Debug.debug_string "None"
                          | Some u -> Debug.debug_coq_level u) ta.template_param_levels;
      let uenv = Info.universe_env ta.template_param_levels in
      Debug.debug_string "Template level:";
      Debug.debug_coq_univ ta.template_level;
      Debug.debug_string "Arity context:";
      Debug.debug_coq_ctxt arity_context;
      let arity_sort = Term.Type ta.template_level in
      let arity = Term.it_mkProd_or_LetIn (Term.mkSort arity_sort) arity_context in
      Debug.debug_string "Arity";
      Debug.debug_coq_type arity;
      (* Arity without parameterization *)
      let arity' = Terms.translate_types info env uenv arity in
      let param_arity' = insert_params_in_arity ta.template_param_levels arity' in
      Debug.debug_dk_term param_arity';
      param_arity'
    end in
  Dedukti.print info.out (Dedukti.declaration false name' param_arity')

(** Translate the constructors of the i-th inductive type in [mind_body].
    cj : ( s1:Sort -> |p1| : Type(s1)   |   |p1| : ||P1||             ) ->
         ( s2:Sort -> |p2| : Type(s2)   |   |p1| : ||P1||(s1)         ) ->
         ( s3:Sort -> |p3| : Type(s3)   |   |p1| : ||P1||(s1,s2)      ) ->
         ... ->
         ( sr:Sort -> |pr| : Type(sr)   |   |pr| : ||Pr||(s1,...sr-1) ) ->
         yj1  : B1(s1,...,sr) ->
         ... ->
         yjkj : Bjkj(s1,...,sr) ->
         I [s1] p1 ... [sr] pr  yj1 ... yjkj
*)
let translate_constructors info env label mind_body i =
  (* Body of the current inductive type *)
  let ind_body = mind_body.mind_packets.(i) in
  
  (* Number of mutual inductive types *)
  let n_types = mind_body.mind_ntypes in
  
  let mind = Names.make_mind info.module_path Names.empty_dirpath label in
  let ind_terms = Array.init n_types (fun i -> Term.mkInd(mind, i)) in
  
  (* Substitute the inductive types as specified in the Coq code. *)
  let cons_types = Array.map (Vars.substl (List.rev (Array.to_list ind_terms)))                                     ind_body.mind_user_lc in
  let translate_name cname = Name.translate_element_name info env (Names.label_of_id cname) in
  let cons_names' = Array.map translate_name ind_body.mind_consnames in

  (* Number of constructors in the current type *)
  let n_cons = Array.length cons_names' in
  
  let cons_types' =
    match ind_body.mind_arity with
    | RegularArity  ria ->
      let translate_ty = Terms.translate_types info env (Info.empty ()) in
      Array.map translate_ty cons_types
    | TemplateArity ta  -> begin
        let uenv = Info.universe_env ta.template_param_levels in
        let cons_types' = Array.map (Terms.translate_types info env uenv) cons_types in
        (* Insert universe quantification before types *)
        Array.map (insert_params_in_arity ta.template_param_levels) cons_types'
      end in
  for j = 0 to n_cons - 1 do
    Dedukti.print info.out (Dedukti.declaration false cons_names'.(j) cons_types'.(j));
  done
  

(** Translate the match function for the i-th inductive type in [mind_body].

    match_I :
    [ s1:Sort -> ] -> p1 : ||P1||(s1)        ->
    [ s2:Sort -> ] -> p2 : ||P2||(s1,s2)     ->
    ... ->
    [ sr:Sort -> ] -> pr : ||Pr||(s1,...,sr) ->
    
    s : Sort ->
    P : (|x1| : ||A1|| -> ... -> |xn| : ||An|| ->
            ||I [s1] p1 ... [sr] pr x1 ... xn|| ->
            type s) ->
    
    case_c1 : (|y11| : ||B11|| -> ... -> |y1k1| : ||B1k1|| ->
               term s (P |u11| ... |u1n| (|c1 [s1] p1 ... [sr] pr y11 ... y1k1|))) -> ...
    ... ->
    case_cj : (|yj1| : ||Bj1|| -> ... -> |yjkj| : ||Bjkj|| ->
               term s (P |uj1| ... |ujn| (|c1 [s1] p1 ... [sr] pr yj1 ... yjkj|))) -> ...
    
    |x1| : ||A1|| -> ... -> |xn| : ||An|| ->
    x : ||I [s1] p1 ... [sr] pr x1 ... xn|| ->
    term s (P |x1| ... |xn| x)

*)
let translate_match info env label mind_body i =
  (* Body of the current inductive type *)
  let ind_body = mind_body.mind_packets.(i) in
  
  (* Number of mutual inductive types *)
  let n_types = mind_body.mind_ntypes in
  
  (* Number of parameters common to all definitions *)
  let n_params = mind_body.mind_nparams in
  
  (* Constructor names *)
  let cons_names = ind_body.mind_consnames in
  
  (* Number of constructors in the current type *)
  let n_cons = Array.length cons_names in
  
  let mind = Names.make_mind info.module_path Names.empty_dirpath label in
  let ind_terms = Array.init n_types (fun i -> Term.mkInd(mind, i)) in
  
  (* Constructor names start from 1. *)
  let cons_terms = Array.init n_cons (fun j -> Term.mkConstruct((mind, i), j + 1)) in
  
  let indtype_name = ind_body.mind_typename in
  let match_function_name' = Name.translate_identifier (Name.match_function indtype_name) in
  let match_function_var'  = Dedukti.var match_function_name' in
  Debug.debug_string ("###  " ^ match_function_name');
  
  let arity_context = ind_body.mind_arity_ctxt in
  
  (* Use the normalized types in the rest. *)
  let cons_types = Array.map (Vars.substl (List.rev (Array.to_list ind_terms)))
                             ind_body.mind_nf_lc in
  
  let params_context = mind_body.mind_params_ctxt in
  let arity_real_context, _ = Utils.list_chop ind_body.mind_nrealdecls arity_context in
  let ind_applied = Terms.apply_rel_context ind_terms.(i) (arity_real_context @ params_context) in
  let cons_context_types = Array.map Term.decompose_prod_assum cons_types in
  let cons_contexts = Array.map fst cons_context_types in
  let cons_types    = Array.map snd cons_context_types in
  let cons_real_contexts = Array.init n_cons (fun j ->
    fst (Utils.list_chop ind_body.mind_consnrealdecls.(j) cons_contexts.(j))) in 
  let cons_ind_args = Array.map (fun a -> snd (Inductive.find_inductive env a)) cons_types in
  let cons_ind_real_args = Array.init n_cons (fun j ->
    snd (Utils.list_chop n_params cons_ind_args.(j))) in
  let cons_applieds = Array.init n_cons (fun j ->
    Terms.apply_rel_context cons_terms.(j) (cons_real_contexts.(j) @ params_context))  in
  let uenv, (params_env, params_context') =
    match ind_body.mind_arity with
    | RegularArity  ria ->
       let uenv = Info.empty () in
       uenv, Terms.translate_rel_context info (Global.env ()) uenv params_context
    | TemplateArity ta  ->
       let uenv = Info.universe_env ta.template_param_levels in
       let (params_env, params_context') =
         Terms.translate_rel_context info (Global.env ()) uenv params_context in
       uenv, (params_env, insert_params_in_decl ta.template_param_levels params_context')
  in

  (* Create a fresh variable s and add it to the environment *)
  let return_sort_name = Name.fresh_of_string info params_env "s" in
  let return_sort_name' = Name.translate_identifier return_sort_name in
  let return_sort_var' = Dedukti.var return_sort_name' in
  let params_env = Name.push_identifier return_sort_name params_env in
  
  (* Create a fresh variable P and add it to the environment *)
  let return_type_name = Name.fresh_of_string info params_env "P" in
  let return_type_name' = Name.translate_identifier return_type_name in
  let return_type_var' = Dedukti.var return_type_name' in
  let params_env = Name.push_identifier return_type_name params_env in
  
  (* Create a fresh variables for each constructors of the inductive type
     and add them to the environment (why ?) *)
  let params_env, case_names' = Array.fold_left (fun (params_env, case_names') cons_name ->
    let case_name = Name.fresh_identifier info params_env ~prefix:"case" cons_name in
    let case_name' = Name.translate_identifier case_name in
    let params_env = Name.push_identifier case_name params_env in
    (params_env, case_name' :: case_names')) (params_env, []) cons_names in
  let case_names' = Array.of_list (List.rev case_names') in
  
  let arity_real_env, arity_real_context' =
    Terms.translate_rel_context info params_env uenv arity_real_context in
  let ind_applied' = Terms.translate_types info arity_real_env uenv ind_applied in
  
  Debug.debug_coq_term ind_applied;
  Debug.debug_dk_term  ind_applied';
  
  (* Create a fresh variable x and add it to the environment (why ?) *)
  let matched_name = Name.fresh_of_string info arity_real_env "x" in
  let matched_name' = Name.translate_identifier matched_name in
  let matched_var' = Dedukti.var matched_name' in
  let params_env = Name.push_identifier matched_name params_env in
  
  
  let cases' = Array.map Dedukti.var case_names' in
  let params' = List.map Dedukti.var (fst (List.split params_context')) in
  
  Debug.debug_coq_env params_env;
  Array.iter Debug.debug_coq_ctxt cons_real_contexts;
  let cons_real_env_contexts' = Array.map (Terms.translate_rel_context info params_env uenv)
                                          cons_real_contexts in
  let cons_real_envs = Array.map fst cons_real_env_contexts' in
  let cons_real_contexts' = Array.map snd cons_real_env_contexts' in
  Array.iter Debug.debug_coq_env cons_real_envs;
  
  let cons_ind_real_args' = Array.mapi (fun j -> Terms.translate_args info cons_real_envs.(j) uenv)
                                       cons_ind_real_args in
  let cons_applieds' = Array.mapi (fun j -> Terms.translate_constr info cons_real_envs.(j) uenv)
                                  cons_applieds in
  (* Combine the above. *)
  let case_types' = Array.init n_cons (fun j -> Dedukti.pies cons_real_contexts'.(j)
    (Dedukti.coq_term return_sort_var' (Dedukti.apps return_type_var' (cons_ind_real_args'.(j) @ [cons_applieds'.(j)])))) in
  let cases_context' = Array.to_list (Array.init n_cons (fun j -> (case_names'.(j), case_types'.(j)))) in
  let common_context' =
    params_context' @
      (return_sort_name', Dedukti.coq_Sort) ::
        (return_type_name', Dedukti.pies arity_real_context'
                                         (Dedukti.arr ind_applied'
                                                      (Dedukti.coq_U return_sort_var'))) ::
          cases_context' in
  let match_function_context' =
    common_context' @ arity_real_context' @ [matched_name', ind_applied'] in
  let match_function_type' = Dedukti.coq_term return_sort_var'
    (Dedukti.app
       (Dedukti.apply_context return_type_var' arity_real_context')
       matched_var') in
  Dedukti.print info.out
                (Dedukti.declaration true match_function_name'
                                     (Dedukti.pies match_function_context' match_function_type'));
  let match_function_applied' =
    Dedukti.apps match_function_var' (params' @ return_sort_var' :: return_type_var' :: Array.to_list cases') in
  let case_rules = Array.init n_cons (fun j ->
    let case_rule_context' = common_context' @ cons_real_contexts'.(j) in
    let case_rule_left' = Dedukti.apps match_function_applied' (cons_ind_real_args'.(j) @ [cons_applieds'.(j)]) in
    let case_rule_right' = Dedukti.apply_context cases'.(j) cons_real_contexts'.(j) in
    (case_rule_context', case_rule_left', case_rule_right')) in
  List.iter (Dedukti.print info.out) (List.map Dedukti.rewrite (Array.to_list case_rules))

