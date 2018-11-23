
val add_sort_params : Dedukti.var list -> Dedukti.term -> Dedukti.term

val instantiate_univ_params :
  Info.env -> Dedukti.var -> Univ.AUContext.t -> Univ.Instance.t -> Dedukti.term

val set_universes : UGraph.t -> unit

val translate_level    : Info.env -> Univ.Level.t    -> Translator.cic_universe
val translate_universe : Info.env -> Univ.Universe.t -> Translator.cic_universe
val translate_sort     : Info.env -> Sorts.t         -> Translator.cic_universe

val convertible_sort   : Info.env -> Sorts.t -> Sorts.t -> bool

val translate_template_params : Univ.Level.t option list -> (string * Dedukti.var) list

val translate_univ_poly_params : Univ.Instance.t -> string list

val translate_univ_poly_constraints : Univ.Constraint.t ->
  (Dedukti.term * Dedukti.term * Univ.Constraint.elt) list
