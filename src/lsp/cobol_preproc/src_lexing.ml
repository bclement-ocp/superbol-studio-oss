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

(** Various utilities for pre-processing cobol code into text and pseudo-text *)

open Cobol_common.Srcloc.TYPES
open Cobol_common.Srcloc.INFIX
open Text.TYPES

module DIAGS =  Cobol_common.Diagnostics

(* --- *)

let remove_blanks = Str.global_replace (Str.regexp " ") ""           (* '\t'? *)

(* SOURCE FORMAT *)

(* Paging *)

type free = |
type fixed = |
type _ paging =
  | FreePaging: free paging
  | FixedWidth: fixed_paging_params -> fixed paging
and fixed_paging_params =
  {
    cut_at_col: int;
    alphanum_padding: char option;
  }

let fixed_paging    = { cut_at_col = 72; alphanum_padding = Some ' ' }
let variable_paging = { fixed_paging with cut_at_col = 250 }
let xcard_paging    = { fixed_paging with cut_at_col = 255 }
let xopen_paging    = { fixed_paging with cut_at_col = 80 }
let crt_paging      = { fixed_paging with cut_at_col = 320 }
let terminal_paging = crt_paging
let cobolx_paging   = { cut_at_col = 255; alphanum_padding = None }

(* Actual format and indicator positioning *)

type 'k source_format = 'k indicator_position * 'k paging
and _ indicator_position =
  |    NoIndic:  free indicator_position
  | FixedIndic: fixed indicator_position
  | XOpenIndic: fixed indicator_position
  |   CRTIndic: fixed indicator_position
  |   TrmIndic: fixed indicator_position
  |  CBLXIndic: fixed indicator_position
and any_source_format =
  | SF: 'k source_format -> any_source_format                          [@@unboxed]

let same_source_formats
  : type k r. k source_format -> r source_format -> bool =
  fun (i1, p1) (i2, p2) -> match i1, i2 with
    |    NoIndic,    NoIndic -> true
    | FixedIndic, FixedIndic -> p1 = p2
    | XOpenIndic, XOpenIndic -> p1 = p2
    |   CRTIndic,   CRTIndic -> p1 = p2
    |   TrmIndic,   TrmIndic -> p1 = p2
    |  CBLXIndic,  CBLXIndic -> p1 = p2
    | _ -> false

let source_format_spec
  : type k. k source_format -> Cobol_config.source_format = function
  |    NoIndic, _ -> SFFree
  | FixedIndic, FixedWidth p when p == fixed_paging -> SFFixed
  | FixedIndic, FixedWidth p when p == variable_paging -> SFVariable
  | FixedIndic, FixedWidth _ (* when p == xcard_paging *) -> SFxCard
  | XOpenIndic, FixedWidth _ (* when p == xopen_paging *) -> SFXOpen
  |   CRTIndic, FixedWidth _ (* when p == crt_paging *) -> SFCRT
  |   TrmIndic, FixedWidth _ (* when p == terminal_paging *) -> SFTrm
  |  CBLXIndic, FixedWidth _ (* when p == cobolx_paging *) -> SFCOBOLX

let decypher_source_format ~dialect format =
  match String.uppercase_ascii @@format, dialect with
  (* SOURCEFORMAT"FREE" on MF means: X/Open free format *)
  (* cf https://www.microfocus.com/documentation/visual-\
       cobol/vc50pu7/VS2019/HRLHLHINTR01U008.html *)
  | "FREE", Cobol_config.DIALECT.MicroFocus -> Ok Cobol_config.SFXOpen
  | "FREE",                      _          -> Ok SFFree
  | "FIXED",                     _          -> Ok SFFixed
  | "VARIABLE",                  _          -> Ok SFVariable
  | "XOPEN",                     _          -> Ok SFXOpen
  | "XCARD",                     _          -> Ok SFxCard
  | "CRT",                       _          -> Ok SFCRT
  | "TERMINAL",                  _          -> Ok SFTrm
  | "COBOLX",                    _          -> Ok SFCOBOLX
  | _                                       -> Error (`SFUnknown format)

let select_source_format
  : Cobol_config.source_format -> any_source_format = function
  | SFFree     -> SF (   NoIndic, FreePaging)
  | SFFixed    -> SF (FixedIndic, FixedWidth    fixed_paging)
  | SFVariable -> SF (FixedIndic, FixedWidth variable_paging)
  | SFXOpen    -> SF (XOpenIndic, FixedWidth    xopen_paging)
  | SFxCard    -> SF (FixedIndic, FixedWidth    xcard_paging)
  | SFCRT      -> SF (  CRTIndic, FixedWidth      crt_paging)
  | SFTrm      -> SF (  TrmIndic, FixedWidth terminal_paging)
  | SFCOBOLX   -> SF ( CBLXIndic, FixedWidth   cobolx_paging)

(* --- *)

let first_area_b_column
  : type k. k source_format -> int option = function
  | _,                     FreePaging
  | XOpenIndic,            _            -> None
  | FixedIndic,            FixedWidth _ -> Some (7 + 4)
  |(CRTIndic | TrmIndic |
    CBLXIndic),            FixedWidth _ -> Some (1 + 4)

(* --- *)

type comment_entry_termination =                  (* skip until... *)
  | Newline                                       (* ... newline *)
  | Period                                        (* ... next period (unused) *)
  | AreaB of { first_area_b_column: int }         (* ... next word in area A *)

let comment_entry_termination
  : type k. k source_format -> comment_entry_termination = fun sf ->
  match sf, first_area_b_column sf with
  |(_         , FreePaging   ), _
  |(XOpenIndic, _            ), _
  |(_         , _            ), None    -> Newline
  | (FixedIndic, FixedWidth _), Some c -> AreaB { first_area_b_column = c }
  |((CRTIndic |
     TrmIndic |
     CBLXIndic), FixedWidth _), Some c -> AreaB { first_area_b_column = c }

(* --- *)

type 'k state =
  {
    lex_prods: text;
    continued: continued;
    pseudotext: (srcloc * text) option;
    cdir_seen: bool;
    newline: bool;
    on_period_only: bool; (*newline on TextWord "." only if true, on any TextWord when false *)
    diags: DIAGS.Set.t;
    config: 'k config;
  }
and continued =
  | CNone
  | CText of {
      str: string with_loc;                                       (** content *)
      txt: prefix_kind;
    }
and prefix_kind =
  | CAlphanum of {
      qte: quotation;             (** quotation style *)
      knd: literal_kind;          (** possible typing prefix (N, X, B, etc.) *)
      cld: bool;                  (** holds if properly closed with quotation *)
      tbc: bool;                  (** to be continued flag (must) *)
      unclosed_ebcdics: bool Lazy.t;
    }
and 'k config =
  {
    debug: bool;
    source_format: 'k source_format;
  }

(* TODO: get rid of `on_period_only` *)
let init_state on_period_only: 'k source_format -> 'k state = fun source_format ->
  {
    lex_prods = [];
    continued = CNone;
    pseudotext = None;
    cdir_seen = false;
    newline = true;
    diags = DIAGS.Set.none;
    on_period_only;
    config =
      {
        debug = false;
        source_format;
      }
  }

let diagnostics { diags; _ } = diags

let source_format { config = { source_format; _ }; _ } =
  source_format

let allow_debug { config = { debug; _ }; _ } =
  debug

(* Just check there are no buffered stuffs.  *)
let flushed = function
  | { lex_prods = []; continued = CNone; pseudotext = None; _ } -> true
  | _ -> false

let flush state =
  { state with lex_prods = []; cdir_seen = false }, List.rev state.lex_prods

let reset_cont state =
  { state with continued = CNone }

let lex_diag ~severity state =
  DIAGS.Cont.kdiag severity
    (fun d -> { state with diags = DIAGS.Set.cons d state.diags })

let lex_error state = lex_diag ~severity:DIAGS.Error state

let change_source_format ({ config; _ } as state) { payload = sf; loc } =
  if flushed state
  then Ok { state with config = { config with source_format = sf } }
  else Error (lex_error state ~loc "Forbidden@ change@ of@ source@ format")

let pos_column Lexing.{ pos_bol; pos_cnum; _ } =         (* count cols from 1 *)
  pos_cnum - pos_bol + 1

let raw_loc ~start_pos ~end_pos { newline; config = { source_format; _ }; _ } =
  let in_area_a = newline && match first_area_b_column source_format with
    | None -> false
    | Some c -> pos_column start_pos < c
  in
  Cobol_common.Srcloc.raw ~in_area_a (start_pos, end_pos)

let emit prod ({ pseudotext; cdir_seen; _ } as state) =
  match pseudotext with
  | None ->
      { state with lex_prods = prod :: state.lex_prods;
                   cdir_seen = cdir_seen || Text.cdirp prod;
                   newline = false }
  | Some (start_loc, prods) ->
      { state with pseudotext = Some (start_loc, prod :: prods);
                   cdir_seen = cdir_seen || Text.cdirp prod;
                   newline = false }

let append t state =
  match state, t with
  | { pseudotext = None;
      lex_prods = { payload = TextWord w; loc = wloc } :: tl; _ },
    { payload = TextWord s; loc = tloc } ->
      let prod = TextWord (w ^ s) &@ (Cobol_common.Srcloc.concat wloc tloc) in
      { state with lex_prods = prod :: tl;
                   newline = false }
  | { pseudotext = Some (start_loc, { payload = TextWord w;
                                      loc = wloc} :: prods); _ },
    { payload = TextWord s; loc = tloc } ->
      let prod = TextWord (w ^ s) &@ (Cobol_common.Srcloc.concat wloc tloc) in
      { state with pseudotext = Some (start_loc, prod :: prods);
                   newline = false }
  | _, { loc; _ } ->
      lex_error state ~loc "Unexpected@ `%a'@ in@ continuation" Text.pp_word t

let new_line state lexbuf =
  Lexing.new_line lexbuf;
  match state.lex_prods, state.cdir_seen with
  | { payload = (Pseudo _ | Eof); _ } :: _, _ | _, true ->
      flush { state with newline = true }
  | { payload = (TextWord "." ); _ } :: _, _
    when state.on_period_only ->
      flush { state with newline = true }
  | { payload = (TextWord _ | Alphanum _); _ } :: _, _
    when not @@ state.on_period_only ->
      flush { state with newline = true }
  | _ ->
      { state with newline = true }, []

(* --- *)

type _ c = Char: char c | Str: string c | Integer: int c

let format_for (type k) : k c -> (k -> 'a, _, _, 'a) format4 = function
  | Char    -> "%c"
  | Str     -> "%s"
  | Integer -> "%d"

let unexpected (type k) (kind: k c)
    ?(knd: Pretty.simple = "character")
    ?(c: k option)
    ?(severity = DIAGS.Error)
    ~k state lexbuf =
  let loc =
    let end_pos = Lexing.lexeme_end_p lexbuf in
    let start_pos = match kind with
      | Str | Integer -> Lexing.lexeme_start_p lexbuf
      | Char -> { end_pos with pos_cnum = end_pos.pos_cnum - 1 }  (* last char *)
    in
    raw_loc ~start_pos ~end_pos state
  in
  let state = match c with
    | None ->
        lex_diag state "Unexpected@ %(%)" knd ~severity ~loc
    | Some c ->
        lex_diag state ("Unexpected@ %(%):@ `"^^format_for kind^^"'") knd c
          ~severity ~loc
  in
  k state lexbuf

(* --- *)

(* Switch to upper-cased representation already: *)
let textword s =
  TextWord (String.uppercase_ascii ~&s) &@<- s

let cdirword: string with_loc -> text_word with_loc = fun { payload = s; loc } ->
  let prefix = if String.(length s > 2 && sub s 0 2 <> ">>") then ">>" else "" in
  CDirWord (String.uppercase_ascii @@ prefix ^ remove_blanks s) &@ loc


let rev_pseudotext: text -> _ state -> pseudotext * _ state = fun text state ->
  List.fold_left begin fun (acc, state) pt -> match ~&pt with
    | TextWord w ->
        (Text.pseudo_string (w &@<- pt)) :: acc, state
    | Alphanum a ->
        (PseudoAlphanum a &@<- pt) :: acc, state
    | _ ->
        acc, lex_error state ~loc:~@pt "Unexpected@ `%a'@ in@ pseudotext"
          Text.pp_word pt
  end ([], state) text

let pseudotext_delimiter ~loc = function
  | { pseudotext = None; _ } as state ->
      { state with pseudotext = Some (loc, []);
                   newline = false }
  | { pseudotext = Some (start_loc, prods); _ } as state ->
      assert (state.continued = CNone);
      (* Here, we assume pseudotext only spans in a single text file. *)
      let start_pos = Cobol_common.Srcloc.start_pos start_loc
      and _, end_pos = Cobol_common.Srcloc.as_lexloc loc in
      let loc = raw_loc ~start_pos ~end_pos state in
      let state = { state with pseudotext = None; newline = false } in
      let pseudotext, state = rev_pseudotext prods state in
      emit (Pseudo pseudotext &@ loc) state


(* Hackish approach to deal with picture strings ending with a period or comma:
   thankfully, they must be immediately followed by another period or comma and
   terminate the sentence.  As a result, text words may either terminate with
   two periods, two commas, or no period or comma at all.

   We just intercept the emission of each text word s ending with either a dot
   or a comma, and emit the dot separately or discard the comma.

   TODO: This currently applies in pseudo-text too; is this the expected
   behavior? *)
let gen emit0 = function
  | { payload = TextWord str; loc } as s ->
      let len = String.length str in
      (* XXX: may pos' end up with an invalid column number? *)
      if len > 1 && str.[String.length str - 1] = '.' then
        let sloc = Cobol_common.Srcloc.trunc_suffix 1 loc
        and ploc = Cobol_common.Srcloc.suffix 1 loc in
        fun state ->
          emit0 (textword (String.sub str 0 (len - 1) &@ sloc)) state |>
          emit (TextWord "." &@ ploc)
      else if len > 1 && str.[String.length str - 1] = ',' then
        let sloc = Cobol_common.Srcloc.trunc_suffix 1 loc in
        emit0 @@ textword (String.sub str 0 (len - 1) &@ sloc)
      else
        emit0 s
  | s ->
      emit0 s

let emit s = gen emit s
let append = gen append

let flush_continued ?(force = false) state = match state.continued with
  | CNone ->
      state
  | CText { txt = CAlphanum { tbc = true; _ }; _ } when not force ->
      state
  | CText { str = { payload = str; loc };
            txt = CAlphanum { qte; knd; cld = true; tbc = false; _ } } ->
      emit (Alphanum { knd; qte; str } &@ loc) (reset_cont state)
  | CText { str = { payload = str; loc };
            txt = CAlphanum { qte; knd; _ } } when force ->
      lex_error (reset_cont state) ~loc "Missing@ continuation@ of@ `%s'" str |>
      emit (Alphanum { knd; qte; str } &@ loc)
  | CText { str = { payload = str; loc };
            txt = CAlphanum { qte; knd; _ } } ->
      (* Missing continuation error is delayed until the final tokenization
         stage to account for quotes in comment paragraphs. *)
      emit (AlphanumPrefix { knd; qte; str } &@ loc) (reset_cont state)

let eof state lexbuf =
  let start_pos = Lexing.lexeme_start_p lexbuf
  and end_pos = Lexing.lexeme_end_p lexbuf in
  let loc = raw_loc ~start_pos ~end_pos state in
  let state = flush_continued ~force:true state in  (* checks state.continued *)
  match state.pseudotext with                       (* and state.pseudotext  *)
  | None ->
      emit (Eof &@ loc) state
  | Some (start_loc, _prods) ->
      let state = { state with pseudotext = None } in
      (* As in `pseudotext_delimiter`, we assume pseudotext only spans in a
         single text file. *)
      let start_pos = Cobol_common.Srcloc.start_pos start_loc
      and _, end_pos = Cobol_common.Srcloc.as_lexloc loc in
      let loc = raw_loc ~start_pos ~end_pos state in
      lex_error state ~loc "Unterminated@ pseudotext" |>
      emit (Eof &@ loc)

(* --- *)

type line_fitting = Nominal | Tacked

let text_word ?(cont = false) ?(fitting = Nominal) w state =
  ignore fitting;
  match state.continued with
  | CNone when cont ->
      append (textword w) state
  | CNone ->
      emit (textword w) state
  | CText _ ->
      let state = flush_continued ~force:true state in
      let state = lex_error state ~loc:~@w "Unexpected@ text@ word" in
      emit (textword w) state


let to_be_continued_alphanum: string -> bool =
  fun s -> match s.[0], Str.last_chars s 2 with
    | '"', "\"-"
    | '\'', "'-" -> true
    | _ -> false
    | exception Invalid_argument _ -> false

let closed_alphanum: string -> bool =
  (* Note we allow alphanumeric tokens to be empty, although some old standards
     may forbid them; this may be checked later on though. *)
  let count_char c s =
    String.to_seq s |> Seq.fold_left (fun i c' -> if c == c' then succ i else i) 0
  in
  fun s ->
    String.length s >= 2 &&
    match s.[0], (Str.last_chars s 1, Str.last_chars s 2) with
    | '\'', ("'", _ | _, "'-") -> count_char '\'' s mod 2 == 0
    | '"', ("\"", _ | _, "\"-") -> count_char '"' s mod 2 == 0
    | _ -> false                                                    (* in case *)
    | exception Invalid_argument _ -> true                          (* in case *)

let strip_left_quote str =
  String.sub str 1 (String.length str - 1)

let strip_right_quote str =
  String.sub str 0 (String.length str - 1)

let strip_quotes str =
  let len = String.length str in
  if to_be_continued_alphanum str then String.sub str 1 (len - 3)
  else if closed_alphanum str then String.sub str 1 (len - 2)
  else String.sub str 1 (len - 1)

let unclosed_ebcdics =
  (* NOTE: applies on internal representation, i.e, without surrounding
     quotes/apostrophes. *)
  let symc = "[0-9][0-9, ]*" in                            (* symbolic EBCDIC *)
  let dblq = "\\([^\"]\\|\"" ^ symc ^ "\"\\|\"\"\\)*\"" ^ symc in
  let splq = "\\([^']\\|'" ^ symc ^ "\"\\|''\\)*'" ^ symc in
  let re = Str.regexp ("^\\(" ^ dblq ^ "\\|" ^ splq ^ "\\)$") in
  fun str -> Str.string_match re str 0

let quoted_alphanum ?(fitting = Nominal) ~knd
    ({ payload = str; _ } as str') state =
  (* Note substitution of doubled quotation or apostrophe marks is delayed until
     after text manipulation stage. *)
  let cld = closed_alphanum str
  and tbc = to_be_continued_alphanum str
  and qte = if str.[0] = '\'' then Apostrophe else Quote in
  match state.continued with
  | CNone when fitting = Nominal && cld && not tbc ->
      emit (Alphanum { knd; qte; str = strip_quotes str } &@<- str') state
  | CNone ->
      let str = strip_quotes str in
      let unclosed_ebcdics = lazy (unclosed_ebcdics str) in
      { state with
        continued = CText { str = str &@<- str';
                            txt = CAlphanum { qte; knd; cld; tbc;
                                              unclosed_ebcdics }; };
        newline = false }
  | CText { str = s0;
            txt = CAlphanum { qte = q0; knd = k0; _ }; _ } ->
      let state =
        if q0 <> qte
        then lex_error state ~loc:~@str' "Mismatch@ in@ continuation@ of@ \
                                          alphanumeric@ literal@ (expected@ \
                                          `%a'@ quotation@ character)\
                                         " Text.pp_quote q0
        else state
      in
      let str = ~&s0 ^ strip_left_quote str
      and strloc = Cobol_common.Srcloc.concat ~@s0 ~@str' in
      let cld = match qte with
        | Quote -> closed_alphanum ("\"" ^ str)
        | Apostrophe -> closed_alphanum ("'" ^ str)
      in
      let str = if cld then strip_right_quote str else str in
      if fitting = Nominal && cld && not tbc then
        emit (Alphanum { knd = k0; qte; str } &@ strloc) (reset_cont state)
      else
        let unclosed_ebcdics = lazy (unclosed_ebcdics str) in
        { state with
          continued = CText { str = str &@ strloc;
                              txt = CAlphanum { qte; knd = k0; cld; tbc;
                                                unclosed_ebcdics } };
          newline = false }

type alphanumeric_continuation =
  | Nominal
  | Closed of Text.quotation
  | UnclosedEBCDICs of Text.quotation

let continue_quoted_alphanum state = match state.continued with
  | CText { txt = CAlphanum { qte; cld; tbc; _ }; _ }
    when cld && not tbc ->
      Closed qte
  | CText { txt = CAlphanum { qte; cld; tbc; unclosed_ebcdics; _ }; _ }
    when not cld && not tbc && Lazy.force unclosed_ebcdics ->
      UnclosedEBCDICs qte
  | _ ->
      Nominal

(* --- *)

let extract_knd str state lexbuf =
  let open struct
    exception UnexpectedChar of char
    exception UnexpectedStr
  end in
  let unexpected =
    unexpected ~knd:"opening delimiter for alphanumeric literal" in
  try
    (* TODO: use start_pos & end_pos instead (see below) *)
    let s, knd = match str.[0] with
      | '"' | '\'' -> str, Basic
      | 'B' -> Str.string_after str 1, Bool
      | 'X' -> Str.string_after str 1, Hex
      | 'Z' -> Str.string_after str 1, NullTerm
      | 'N' -> Str.string_after str 1, National
      | c -> raise @@ UnexpectedChar c
    in
    let s, knd = match s.[0], knd with
      |('"' | '\''), knd -> s, knd
      | 'X', Bool -> Str.string_after s 1, BoolX
      | 'X', National -> Str.string_after s 1, NationalX
      | _ -> raise @@ UnexpectedStr
    in
    s, knd, state
  with
  | UnexpectedChar c ->
      unexpected Char ~c state lexbuf
        ~k:(fun state _lexbuf -> Str.string_after str 1, Basic, state)
  | UnexpectedStr ->
      unexpected Str state lexbuf
        ~k:(fun state _lexbuf -> Str.string_after str 2, Basic, state)


type lexeme_info = string * Lexing.position * Lexing.position
let lexeme_info lexbuf : lexeme_info =
  Lexing.(lexeme lexbuf, lexeme_start_p lexbuf, lexeme_end_p lexbuf)

let trunc_to_col n ((s, sp, ep) as info: lexeme_info) =
  let sc = pos_column sp and ec = pos_column ep in
  assert (sc <= n);        (* starts on last column (CHECKME: always avoided?) *)
  if ec <= n
  then
    info, if ec = n + 1 then Tacked else Nominal
  else                  (* truncate lexeme and shift end position accordingly *)
    let s = String.sub s 0 (n - sc + 1) in
    (s, sp, { ep with pos_cnum = ep.pos_cnum - ec + n + 1}), Tacked

let fixed_text mk ({ config = { source_format; _ }; _ } as state) lexbuf =
  let _, FixedWidth { cut_at_col; _ } = source_format in
  let (_, start_pos, _) as lexinf = lexeme_info lexbuf in
  if pos_column start_pos > cut_at_col then
    state, Tacked
  else
    let (s, start_pos, end_pos), fitting = trunc_to_col cut_at_col lexinf in
    let sloc = raw_loc ~start_pos ~end_pos state in
    mk ?fitting:(Some fitting) (s &@ sloc) state, fitting

let fixed_text_word ?cont = fixed_text (text_word ?cont)
let fixed_nocont mk = fixed_text (fun ?fitting s -> ignore fitting; emit (mk s))
let fixed_cdir_word = fixed_nocont cdirword  (* cannot be broken across lines *)
let fixed_eqeq = fixed_text begin fun ?fitting -> function
    | { payload = "=="; loc } ->
        pseudotext_delimiter ~loc
    | { payload = str; _ } as s ->
        assert (str = "=");                                (* necessarily "=" *)
        text_word ?fitting s
  end

let continuing_unclosed_ebcdics = function
  | { continued = CText { txt = CAlphanum { unclosed_ebcdics; _ }; _ }; _ } ->
      Lazy.force unclosed_ebcdics
  | _ -> false

let fixed_alphanum_lit
    ?(doubled_opener = false)
    ({ config = { source_format; _ }; _ } as state)
    lexbuf
  =
  let _, FixedWidth { cut_at_col; alphanum_padding } = source_format in
  let (_, start_pos, end_pos) as lexinf = lexeme_info lexbuf in
  let end_col = pos_column end_pos in
  assert (pos_column end_pos > 0);     (* should never have zero-length token *)
  if pos_column start_pos > cut_at_col then
    state, Tacked
  else
    let (s, start_pos, end_pos), fitting = trunc_to_col cut_at_col lexinf in
    let s, knd, state = extract_knd s state lexbuf in
    let s, end_pos, fitting =
      (* Actually double the opening delimiter ('\'' or '"'), to have the
         doubled quote/apostrophe character prefix after stripping of opening
         and closing delimiters in `quoted_alphanum`.  *)
      let s = if doubled_opener then String.sub s 0 1 ^ s else s in
      let length_to_right_col = cut_at_col - end_col + 1 in
      if closed_alphanum s || length_to_right_col <= 0 ||
         continuing_unclosed_ebcdics state
      then s, end_pos, fitting
      else match alphanum_padding with
        | None ->
            s, end_pos, Tacked
        | Some c ->
            let pos_cnum = end_pos.pos_cnum + length_to_right_col in
            let end_pos = { end_pos with pos_cnum } in
            s ^ String.make length_to_right_col c, end_pos, Tacked
    in
    let loc = raw_loc ~start_pos ~end_pos state in
    quoted_alphanum ~fitting ~knd (s &@ loc) state, fitting

(* --- *)

let fixed_text mk ~ktkd ~knom state lexbuf =
  let state, fitting = mk state lexbuf in
  (if fitting = Tacked then ktkd else knom) state lexbuf

let text_word ?cont = fixed_text (fixed_text_word ?cont)
let cdir_word s = fixed_text fixed_cdir_word s
let eqeq s = fixed_text fixed_eqeq s
let alphanum_lit ?doubled_opener =
  fixed_text (fixed_alphanum_lit ?doubled_opener)

(* Free-format versions: *)

let free_srctok mk state lexbuf =
  let s = Lexing.lexeme lexbuf in
  let start_pos = Lexing.lexeme_start_p lexbuf
  and end_pos = Lexing.lexeme_end_p lexbuf in
  mk (s &@ raw_loc ~start_pos ~end_pos state) state

let emit_srctok mk = free_srctok (fun s -> emit (mk s))

let free_text_word s = emit_srctok textword s
let free_cdir_word s = emit_srctok cdirword s
let free_eqeq s = free_srctok (fun { loc; _ } -> pseudotext_delimiter ~loc) s
let free_alphanum_lit state lexbuf =
  let s = Lexing.lexeme lexbuf
  and start_pos = Lexing.lexeme_start_p lexbuf
  and end_pos = Lexing.lexeme_end_p lexbuf in
  (* TODO: pass (start_pos, end_pos) to extract_knd *)
  let s, knd, state = extract_knd s state lexbuf in
  quoted_alphanum ~knd (s &@ raw_loc ~start_pos ~end_pos state) state

(* --- *)

let free_text mk ~k state lexbuf = k (mk state lexbuf) lexbuf

let text_word' ~k = free_text free_text_word ~k
let cdir_word' ~k = free_text free_cdir_word ~k
let eqeq' ~k = free_text free_eqeq ~k
let alphanum_lit' ~k = free_text free_alphanum_lit ~k

(* --- *)
