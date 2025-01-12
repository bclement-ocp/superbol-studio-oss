(**************************************************************************)
(*                                                                        *)
(*                        SuperBOL OSS Studio                             *)
(*                                                                        *)
(*  Copyright (c) 2022-2023 OCamlPro SAS                                  *)
(*                                                                        *)
(* All rights reserved.                                                   *)
(* This source code is licensed under the GNU Affero General Public       *)
(* License version 3 found in the LICENSE.md file in the root directory   *)
(* of this source tree.                                                   *)
(*                                                                        *)
(**************************************************************************)

open EzCompat
open Ezcmd.V2
open EZCMD.TYPES

type t = {
  config: (module Cobol_config.T);
  source_format: Cobol_config.source_format_spec;
  libpath: string list;
  verbose: bool;
  recovery: Cobol_parser.recovery;
  show: [`Pending] list;
}

let showable =
  [
    ["pending"], `Pending;
  ]

let iter_comma_separated_spec ~showable ~option_name ~f spec =
  EzString.split_simplify spec ',' |>
  List.fold_left begin fun unknowns spec ->
    let spec' = String.(lowercase_ascii @@ trim @@ spec) in
    match
      List.find_map begin fun (sl, tag) ->
        if List.mem spec' sl then Some tag else None
      end showable
    with
    | Some tag -> f tag; unknowns
    | None -> StringSet.add spec unknowns
  end StringSet.empty |>
  fun unknowns ->
  if not (StringSet.is_empty unknowns) then
    raise @@ Stdlib.Arg.Bad
      Pretty.(to_string "@[Unknown@ arguments@ for@ `%s':@ %a@]"
                option_name
                (list ~fopen:"" ~fsep:",@ " ~fclose:"" string)
                (StringSet.elements unknowns))

let get () =
  let conf = ref "" in                                    (* Fixed by default *)
  let dialect = ref None in
  let strict = ref false in
  let format = ref Cobol_config.Auto in                   (* Fixed by default *)
  let formats = ["free"; "Free"; "FREE";
                 "fixed"; "Fixed"; "FIXED";
                 "cobolx"; "Cobolx"; "CobolX"; "COBOLX"] in
  let libpath = ref ["."] in
  let recovery = ref true in
  let show = ref [`Pending] in                                     (* default *)
  let silence spec =
    iter_comma_separated_spec ~showable ~option_name:"--silence" spec
      ~f:(fun tag -> show := List.filter ((<>) tag) !show)
  in

  let args = [

    ["conf"], Arg.Set_string conf,
    EZCMD.info ~docv:"CONF_FILE" "Set the configuration file to be used";

    ["dialect"; "std"], Arg.Symbol
      (Cobol_config.DIALECT.all_canonical_names,
       fun d -> dialect := Some (Cobol_config.DIALECT.of_string d)),
    EZCMD.info ~docv:"DIALECT"
      "Set the dialect to bu used (overriden by `--conf` if used)";

    ["strict"], Arg.Set strict,
    EZCMD.info "Use the strict configuration";

    ["source-format"],
    Arg.Symbol (formats, fun f -> format := match String.uppercase_ascii f with
        | "FIXED" -> Cobol_config.SF Cobol_config.SFFixed
        | "FREE" -> SF SFFree
        | "COBOLX" -> SF SFCOBOLX
        | _ ->
            Cobol_common.Diagnostics.Now.warn
              Fmt.stderr
              "Unkown source format: %s, setting to default"
              f;
            Auto),
    EZCMD.info ~docv:"SOURCE_FORMAT"
      "Set the format of source code; allowed values are: { FIXED (the default), \
       FREE}\nOverrides `format` from configuration file if present.";

    ["free"], Arg.Unit (fun () -> format := SF SFFree),
    EZCMD.info "Shorthand for `--source-format FREE`";

    ["recovery"], Arg.Set_bool recovery,
    EZCMD.info @@
    Pretty.to_string "Enable/disable parser recovery after syntax errors \
                      (default: %b)" !recovery;

    ["silence"], Arg.String silence,
    EZCMD.info "Silence specific messages";

    ["I"], Arg.String (fun s -> libpath := s :: !libpath),
    EZCMD.info ~docv:"DIRECTORY" "Add DIRECTORY to library search path";
  ] in


  let get () =
    let config =
      let strict = !strict in
      let dialect = !dialect in
      match !conf, dialect with
      | "", None -> Cobol_config.default
      | "", Some d -> Cobol_common.do_any (Cobol_config.from_dialect ~strict) d
      | s, None -> Cobol_common.do_any (Cobol_config.from_file ?dialect) s
      | _ -> Pretty.failwith "Flags `--conf` and `--dialect` or `--std` cannot be \
                              used together"
    in
    let source_format =
      match !format with
      | Auto ->
          let module Config = (val config: Cobol_config.T) in
          Config.format#value
      | SF _ -> !format
    in
    let recovery =
      if !recovery
      then Cobol_parser.EnableRecovery { silence_benign_recoveries = false }
      else Cobol_parser.DisableRecovery
    in
    let verbose = !Globals.verbosity > 0 in
    { config ; source_format ; libpath = !libpath ; recovery; verbose;
      show = !show }

  in
  get, args
