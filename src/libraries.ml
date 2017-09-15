(** Translation of Coq libraries *)

open Pp

let print m = msg_with Format.std_formatter (m ++ str "\n")

let destination = ref "."

let set_destination dest =
  print (str "Setting destination: " ++ str dest);
  destination := dest


(** Translate the library referred to by [qualid].
    A libray is a module that corresponds to a file on disk. **)
let translate_qualified_library qualid =
  print (str "Exporting " ++ Libnames.pr_qualid qualid);
  let module_path = Nametab.locate_module qualid in
  let module_body = Global.lookup_module module_path in
  let dir_path = Nametab.dirpath_of_module module_path in
  let filename = Filename.concat !destination (Name.translate_dir_path dir_path) in
  let out = open_out (filename ^ ".dk") in
  let formatter = Format.formatter_of_out_channel out in
  let info = Info.init formatter dir_path in
  let flush_and_close () =
    Format.pp_print_flush formatter ();
    close_out out
  in
  begin try
    Dedukti.print formatter (Dedukti.comment "This file was automatically generated by Coqine.");
    Dedukti.print formatter (Dedukti.command "NAME" [Name.translate_dir_path dir_path]);
    Modules.translate_module_body info (Global.env ()) module_body;
    Dedukti.print formatter (Dedukti.comment "End of translation")
  with
  | e ->
    flush_and_close ();
    raise e
  end;
  flush_and_close ()


(** Translate the library referred to by [reference]. *)
let translate_library reference =
  let loc, qualid = Libnames.qualid_of_reference reference in
  let lib_loc, lib_path, lib_phys_path = Library.locate_qualified_library qualid in
  Library.require_library_from_dirpath [ (lib_path, Libnames.string_of_qualid qualid) ] None;
  Tsorts.set_universes (Global.universes ());
  translate_qualified_library qualid

(** Translate all loaded libraries. **)
let translate_all () =
  let dirpaths = Library.loaded_libraries () in
  let qualids = List.map Libnames.qualid_of_dirpath dirpaths in
  Tsorts.set_universes (Global.universes ());
  List.iter translate_qualified_library qualids


let test () =
  print (str "Test")


let show_universes_constraints () =
  print (str "");
  print (str "-----------------------------------------------");
  print (str "|    Printing global universes constraints    |");
  print (str "-----------------------------------------------");
  let universes = UGraph.sort_universes (Global.universes ()) in
  let register constraint_type j k =
    match constraint_type with
    | Univ.Lt -> print (str j ++ str " <  " ++ str k)
    | Univ.Le -> print (str j ++ str " <= " ++ str k)
    | Univ.Eq -> print (str j ++ str " == " ++ str k)
  in
  UGraph.dump_universes register universes;
  print (str "-----------------------------------------------");
  print (str "")


