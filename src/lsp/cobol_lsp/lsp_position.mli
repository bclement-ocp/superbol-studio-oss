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

(** This module has utility functions to use {!Lsp.Types.Position} and
    {!Lsp.Types.Range} types with {!Srcloc.lexloc} and {!Srcloc.srcloc}. *)

(** Range of length [0], at position [0, 0] *)
val none_range: Lsp.Types.Range.t

(** [range_of_lexloc] creates a representation of the given lexical location
    that is suitable for the LSP library. *)
val range_of_lexloc: Cobol_common.Srcloc.lexloc -> Lsp.Types.Range.t

(** [is_before_lexloc pos lexloc] holds when [pos] is strictly before
    [lexloc] *)
val is_before_lexloc: Lsp.Types.Position.t -> Cobol_common.Srcloc.lexloc -> bool

(** [is_after_lexloc pos lexloc] holds when [pos] is strictly after [lexloc] *)
val is_after_lexloc: Lsp.Types.Position.t -> Cobol_common.Srcloc.lexloc -> bool

(** [is_in_lexloc pos lexloc] holds when [pos] is neither before or after
    [lexloc] *)
val is_in_lexloc: Lsp.Types.Position.t -> Cobol_common.Srcloc.lexloc -> bool

(** [contains_lexloc range lexloc] holds when [lexloc] is strictly contained
    within [range]. *)
val contains_lexloc: Lsp.Types.Range.t -> Cobol_common.Srcloc.lexloc -> bool

(* --- *)

val range_of_srcloc_in
  : filename:string
  -> Cobol_common.Srcloc.srcloc
  -> Lsp.Types.Range.t

val is_in_srcloc
  : filename:string
  -> Lsp.Types.Position.t
  -> Cobol_common.Srcloc.srcloc
  -> bool

(* --- *)

(** [sieve ~filename ~pos] is a folder visitor that skips any localized AST node
    whose source location does not include the given position. To be used as a
    mixin component so it overrides [fold'] last. *)
class ['x] sieve: filename:string -> pos:Lsp.Types.Position.t ->
  object
    method fold'
      : 'n. ('n Cobol_common.Srcloc.with_loc, 'x) Cobol_common.Visitor.fold
  end
