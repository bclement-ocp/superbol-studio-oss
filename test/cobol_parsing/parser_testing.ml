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

module DIAGS = Cobol_common.Diagnostics

let show_parsed_tokens
    ?(verbose = false)
    ?(source_format = Cobol_config.(SF SFFixed))
    prog =
  let DIAGS.{ result = WithArtifacts (_, { tokens; _ }); _ } =
    Cobol_parser.parse_with_artifacts
      ~options:Cobol_parser.Options.{
          default with
          verbose;
          recovery = EnableRecovery { silence_benign_recoveries = true };
        } @@
    Cobol_preproc.preprocessor
      { init_libpath = [];
        init_config = Cobol_config.default;
        init_source_format = source_format } @@
    String { filename = "prog.cob"; contents = prog }
  in
  Cobol_parser.INTERNAL.pp_tokens Fmt.stdout (Lazy.force tokens)
