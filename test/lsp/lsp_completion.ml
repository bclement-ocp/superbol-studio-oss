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

open EzCompat                                                    (* StringMap *)
open Lsp.Types
open Lsp_testing

let escaped_string ppf (item: CompletionItem.t) =
  let quoted = Pretty.to_string "%S" item.label in
  Fmt.string ppf @@
  String.sub quoted 1 (-2 + String.length quoted)

let completion_positions (doc, positions) : string -> unit =
  let { end_with_postproc; projdir }, server = make_lsp_project () in
  let server, prog = add_cobol_doc server ~projdir "prog.cob" doc in
  let location_as_srcloc = new srcloc_resuscitator_cache in
  let completions_at_position ?key (position: Position.t) =
    let location =
      let range = Range.create ~start:position ~end_:position in
      Location.create ~range ~uri:prog.uri
    in
    let params = CompletionParams.create ~position ~textDocument:prog () in
    Pretty.out "%a%a(line %d, character %d):\n"
      location_as_srcloc#pp location
      Fmt.(option ~none:nop (string ++ sp)) key
      position.line position.character;
    begin
      match LSP.Request.completion ~eager:false server params with
      | None ->
        Pretty.out "Failed completion@."
      | Some `CompletionList { items; _ } when items == [] ->
        Pretty.out "Empty completion list@."
      | Some `CompletionList { items; _ } ->
        Pretty.out "@.@[<hv 4>Basic (%d entries):@;%a@]@\n"
          (List.length items)
          (Fmt.list ~sep:Fmt.sp escaped_string)
          items
    end;
    match LSP.Request.completion ~eager:true server params with
    | None ->
      Pretty.out "Failed eager-completion@."
    | Some `CompletionList { items; _ } when items == [] ->
      Pretty.out "Empty eager-completion list@."
    | Some `CompletionList { items; _ } ->
      Pretty.out "@[<hv 4>Eager (%d entries):@;%a@]@\n"
        (List.length items)
        (Fmt.list ~sep:Fmt.sp escaped_string)
        items;
  in
  StringMap.iter (fun n p -> completions_at_position ~key:n p) positions.pos_map;
  List.iter (fun p -> completions_at_position p) positions.pos_anonymous;
  end_with_postproc

let%expect_test "case-detection-testing-completion" =
  let end_with_postproc = completion_positions @@ extract_position_markers {cobol|
        IDENTIFICATION _|_DI_|_VISION.
        PROGRAM-ID. prog.
        PROCEDURE di_|_vision.
          STOP RUN.
  |cobol}
 in
  end_with_postproc [%expect.output];
  [%expect {|
    {"params":{"diagnostics":[],"uri":"file://__rootdir__/prog.cob"},"method":"textDocument/publishDiagnostics","jsonrpc":"2.0"}
    __rootdir__/prog.cob:2.23:
       1
       2 >         IDENTIFICATION DIVISION.
    ----                          ^
       3           PROGRAM-ID. prog.
       4           PROCEDURE division.
    (line 1, character 23):
    Basic (1 entries): DIVISION.\n
    Eager (1 entries): DIVISION.\n
    __rootdir__/prog.cob:2.25:
       1
       2 >         IDENTIFICATION DIVISION.
    ----                            ^
       3           PROGRAM-ID. prog.
       4           PROCEDURE division.
    (line 1, character 25):
    Basic (1 entries): DIVISION.\n
    Eager (1 entries): DIVISION.\n
    __rootdir__/prog.cob:4.20:
       1
       2           IDENTIFICATION DIVISION.
       3           PROGRAM-ID. prog.
       4 >         PROCEDURE division.
    ----                       ^
       5             STOP RUN.
       6
    (line 3, character 20):
    Basic (1 entries): division
    Eager (1 entries): division |}]

let%expect_test "word-delimeter-testing-completion" =
  let end_with_postproc = completion_positions @@ extract_position_markers {cobol|
    _|_    IDENTIFICATION _|_DIVI_|_SION_|_._|_
_|_        PROGRAM-ID. prog.
        PROCEDURE DIVISION.
          DISPLAY FUNCTION MIN(1 2)_|_
          STOP RUN.
  |cobol}
 in
  end_with_postproc [%expect.output];
  [%expect {|
    {"params":{"diagnostics":[],"uri":"file://__rootdir__/prog.cob"},"method":"textDocument/publishDiagnostics","jsonrpc":"2.0"}
    __rootdir__/prog.cob:2.4:
       1
       2 >         IDENTIFICATION DIVISION.
    ----       ^
       3           PROGRAM-ID. prog.
       4           PROCEDURE DIVISION.
    (line 1, character 4):
    Basic (7 entries):
        CLASS-ID
        CONTROL
        FUNCTION-ID
        ID
        IDENTIFICATION
        INTERFACE-ID
        PROGRAM-ID
    Eager (7 entries):
        CLASS-ID.\n
        CONTROL DIVISION.\n
        FUNCTION-ID
        ID DIVISION.\n
        IDENTIFICATION DIVISION.\n
        INTERFACE-ID.\n
        PROGRAM-ID
    __rootdir__/prog.cob:2.23:
       1
       2 >         IDENTIFICATION DIVISION.
    ----                          ^
       3           PROGRAM-ID. prog.
       4           PROCEDURE DIVISION.
    (line 1, character 23):
    Basic (1 entries): DIVISION.\n
    Eager (1 entries): DIVISION.\n
    __rootdir__/prog.cob:2.27:
       1
       2 >         IDENTIFICATION DIVISION.
    ----                              ^
       3           PROGRAM-ID. prog.
       4           PROCEDURE DIVISION.
    (line 1, character 27):
    Basic (1 entries): DIVISION.\n
    Eager (1 entries): DIVISION.\n
    __rootdir__/prog.cob:2.31:
       1
       2 >         IDENTIFICATION DIVISION.
    ----                                  ^
       3           PROGRAM-ID. prog.
       4           PROCEDURE DIVISION.
    (line 1, character 31):
    Basic (1 entries): DIVISION.\n
    Eager (1 entries): DIVISION.\n
    __rootdir__/prog.cob:2.32:
       1
       2 >         IDENTIFICATION DIVISION.
    ----                                   ^
       3           PROGRAM-ID. prog.
       4           PROCEDURE DIVISION.
    (line 1, character 32):
    Basic (11 entries):
        AUTHOR
        CLASS-ID
        DATE-COMPILED
        DATE-MODIFIED
        DATE-WRITTEN
        FUNCTION-ID
        INSTALLATION
        INTERFACE-ID
        PROGRAM-ID
        REMARKS
        SECURITY
    Eager (11 entries):
        AUTHOR.\n
        CLASS-ID.\n
        DATE-COMPILED.\n
        DATE-MODIFIED.\n
        DATE-WRITTEN.\n
        FUNCTION-ID
        INSTALLATION.\n
        INTERFACE-ID.\n
        PROGRAM-ID
        REMARKS.\n
        SECURITY.\n
    __rootdir__/prog.cob:3.0:
       1
       2           IDENTIFICATION DIVISION.
       3 >         PROGRAM-ID. prog.
    ----   ^
       4           PROCEDURE DIVISION.
       5             DISPLAY FUNCTION MIN(1 2)
    (line 2, character 0):
    Basic (11 entries):
        AUTHOR
        CLASS-ID
        DATE-COMPILED
        DATE-MODIFIED
        DATE-WRITTEN
        FUNCTION-ID
        INSTALLATION
        INTERFACE-ID
        PROGRAM-ID
        REMARKS
        SECURITY
    Eager (11 entries):
        AUTHOR.\n
        CLASS-ID.\n
        DATE-COMPILED.\n
        DATE-MODIFIED.\n
        DATE-WRITTEN.\n
        FUNCTION-ID
        INSTALLATION.\n
        INTERFACE-ID.\n
        PROGRAM-ID
        REMARKS.\n
        SECURITY.\n
    __rootdir__/prog.cob:5.35:
       2           IDENTIFICATION DIVISION.
       3           PROGRAM-ID. prog.
       4           PROCEDURE DIVISION.
       5 >           DISPLAY FUNCTION MIN(1 2)
    ----                                      ^
       6             STOP RUN.
       7
    (line 4, character 35):
    Basic (103 entries):
        ACCEPT
        ADD
        ADDRESS
        ALL
        ALLOCATE
        ALTER
        AS FACTORY OF
        AS UNIVERSAL
        AS
        AT
        BACKGROUND-COLOR
        BELL
        BLANK
        BLINK
        CALL
        CANCEL
        CLOSE
        COL
        COLUMN
        COMPUTE
        CONTINUE
        CONTROL
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END-DISPLAY
        ENTER
        ENTRY
        ERASE
        EVALUATE
        EXCEPTION
        EXCEPTION-OBJECT
        EXIT
        FOREGROUND-COLOR
        FREE
        FUNCTION
        GENERATE
        GO
        GOBACK
        GRID
        HIGHLIGHT
        HIGH-VALUES
        IF
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        LEFTLINE
        LINAGE-COUNTER
        LINE
        LINE-COUNTER
        LOWLIGHT
        LOW-VALUES
        MERGE
        MODE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        NOT ON EXCEPTION
        NULL
        ON EXCEPTION
        OPEN
        OVERLINE
        PAGE-COUNTER
        PERFORM
        .\n
        POSITION
        PURGE
        QUOTES
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REVERSE-VIDEO
        REWRITE
        SEARCH
        SELF
        SEND
        SET
        SIZE
        SORT
        SPACES
        START
        STOP
        STRING
        SUBTRACT
        SUPER
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNDERLINE
        UNLOCK
        UNSTRING
        UPON
        VALIDATE
        WITH
        WITH NO ADVANCING
        WRITE
        ZEROS
    Eager (101 entries):
        ACCEPT
        ADD
        ADDRESS OF
        ALL
        ALLOCATE
        ALTER
        AS
        AT
        BACKGROUND-COLOR
        BELL
        BLANK
        BLINK
        CALL
        CANCEL
        CLOSE
        COL
        COLUMN
        COMPUTE
        CONTINUE
        CONTROL
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END-DISPLAY
        ENTER
        ENTRY
        ERASE
        EVALUATE
        EXCEPTION
        EXCEPTION-OBJECT
        EXIT
        FOREGROUND-COLOR
        FREE
        FUNCTION
        GENERATE
        GO
        GOBACK
        GRID
        HIGHLIGHT
        HIGH-VALUES
        IF
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        LEFTLINE
        LINAGE-COUNTER
        LINE
        LINE-COUNTER
        LOWLIGHT
        LOW-VALUES
        MERGE
        MODE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        NOT ON EXCEPTION
        NULL
        ON EXCEPTION
        OPEN
        OVERLINE
        PAGE-COUNTER
        PERFORM
        .\n
        POSITION
        PURGE
        QUOTES
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REVERSE-VIDEO
        REWRITE
        SEARCH
        SELF
        SEND
        SET
        SIZE
        SORT
        SPACES
        START
        STOP
        STRING
        SUBTRACT
        SUPER
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNDERLINE
        UNLOCK
        UNSTRING
        UPON
        VALIDATE
        WITH
        WITH NO ADVANCING
        WRITE
        ZEROS |}]

let%expect_test "division-and-section-completion" =
  let end_with_postproc = completion_positions @@ extract_position_markers {cobol|
        _|_IDENTIFICATION DIVISION._|_
        PROGRAM-ID _|_. _|_prog.
        _|_DATA _|_DIVISION.
        _|_WORKING-STORAGE _|_SECTION.
        01 DATA-NAME PIC X.
        _|_PROCEDURE _|_DIVISION.
          DISPLAY DATA-NAME
          STOP RUN.
  |cobol} in
  end_with_postproc [%expect.output];
  [%expect {|
    {"params":{"diagnostics":[],"uri":"file://__rootdir__/prog.cob"},"method":"textDocument/publishDiagnostics","jsonrpc":"2.0"}
    __rootdir__/prog.cob:2.8:
       1
       2 >         IDENTIFICATION DIVISION.
    ----           ^
       3           PROGRAM-ID . prog.
       4           DATA DIVISION.
    (line 1, character 8):
    Basic (7 entries):
        CLASS-ID
        CONTROL
        FUNCTION-ID
        ID
        IDENTIFICATION
        INTERFACE-ID
        PROGRAM-ID
    Eager (7 entries):
        CLASS-ID.\n
        CONTROL DIVISION.\n
        FUNCTION-ID
        ID DIVISION.\n
        IDENTIFICATION DIVISION.\n
        INTERFACE-ID.\n
        PROGRAM-ID
    __rootdir__/prog.cob:2.32:
       1
       2 >         IDENTIFICATION DIVISION.
    ----                                   ^
       3           PROGRAM-ID . prog.
       4           DATA DIVISION.
    (line 1, character 32):
    Basic (11 entries):
        AUTHOR
        CLASS-ID
        DATE-COMPILED
        DATE-MODIFIED
        DATE-WRITTEN
        FUNCTION-ID
        INSTALLATION
        INTERFACE-ID
        PROGRAM-ID
        REMARKS
        SECURITY
    Eager (11 entries):
        AUTHOR.\n
        CLASS-ID.\n
        DATE-COMPILED.\n
        DATE-MODIFIED.\n
        DATE-WRITTEN.\n
        FUNCTION-ID
        INSTALLATION.\n
        INTERFACE-ID.\n
        PROGRAM-ID
        REMARKS.\n
        SECURITY.\n
    __rootdir__/prog.cob:3.19:
       1
       2           IDENTIFICATION DIVISION.
       3 >         PROGRAM-ID . prog.
    ----                      ^
       4           DATA DIVISION.
       5           WORKING-STORAGE SECTION.
    (line 2, character 19):
    Basic (7 entries): ALL HIGH-VALUES LOW-VALUES .\n QUOTES SPACES ZEROS
    Eager (7 entries): ALL HIGH-VALUES LOW-VALUES .\n QUOTES SPACES ZEROS
    __rootdir__/prog.cob:3.21:
       1
       2           IDENTIFICATION DIVISION.
       3 >         PROGRAM-ID . prog.
    ----                        ^
       4           DATA DIVISION.
       5           WORKING-STORAGE SECTION.
    (line 2, character 21):
    Basic (6 entries): ALL HIGH-VALUES LOW-VALUES QUOTES SPACES ZEROS
    Eager (6 entries): ALL HIGH-VALUES LOW-VALUES QUOTES SPACES ZEROS
    __rootdir__/prog.cob:4.8:
       1
       2           IDENTIFICATION DIVISION.
       3           PROGRAM-ID . prog.
       4 >         DATA DIVISION.
    ----           ^
       5           WORKING-STORAGE SECTION.
       6           01 DATA-NAME PIC X.
    (line 3, character 8):
    Basic (29 entries):
        AUTHOR
        COMMUNICATION
        CONFIGURATION
        DATA
        DATE-COMPILED
        DATE-MODIFIED
        DATE-WRITTEN
        END PROGRAM
        ENVIRONMENT
        FD
        FILE
        FILE-CONTROL
        ID
        IDENTIFICATION
        INPUT-OUTPUT
        INSTALLATION
        I-O-CONTROL
        LINKAGE
        LOCAL-STORAGE
        OPTIONS
        PROCEDURE
        PROGRAM-ID
        REMARKS
        REPORT
        SCREEN
        SD
        SECURITY
        SELECT
        WORKING-STORAGE
    Eager (29 entries):
        AUTHOR.\n
        COMMUNICATION SECTION.\n
        CONFIGURATION SECTION.\n
        DATA DIVISION.\n
        DATE-COMPILED.\n
        DATE-MODIFIED.\n
        DATE-WRITTEN.\n
        END PROGRAM
        ENVIRONMENT DIVISION.\n
        FD
        FILE SECTION.\n
        FILE-CONTROL.\n
        ID DIVISION.\n
        IDENTIFICATION DIVISION.\n
        INPUT-OUTPUT SECTION.\n
        INSTALLATION.\n
        I-O-CONTROL.\n
        LINKAGE SECTION.\n
        LOCAL-STORAGE SECTION.\n
        OPTIONS.\n
        PROCEDURE DIVISION
        PROGRAM-ID
        REMARKS.\n
        REPORT SECTION.\n
        SCREEN SECTION.\n
        SD
        SECURITY.\n
        SELECT
        WORKING-STORAGE SECTION.\n
    __rootdir__/prog.cob:4.13:
       1
       2           IDENTIFICATION DIVISION.
       3           PROGRAM-ID . prog.
       4 >         DATA DIVISION.
    ----                ^
       5           WORKING-STORAGE SECTION.
       6           01 DATA-NAME PIC X.
    (line 3, character 13):
    Basic (1 entries): DIVISION.\n
    Eager (1 entries): DIVISION.\n
    __rootdir__/prog.cob:5.8:
       2           IDENTIFICATION DIVISION.
       3           PROGRAM-ID . prog.
       4           DATA DIVISION.
       5 >         WORKING-STORAGE SECTION.
    ----           ^
       6           01 DATA-NAME PIC X.
       7           PROCEDURE DIVISION.
    (line 4, character 8):
    Basic (15 entries):
        COMMUNICATION
        DATA
        END PROGRAM
        FD
        FILE
        ID
        IDENTIFICATION
        LINKAGE
        LOCAL-STORAGE
        PROCEDURE
        PROGRAM-ID
        REPORT
        SCREEN
        SD
        WORKING-STORAGE
    Eager (15 entries):
        COMMUNICATION SECTION.\n
        DATA DIVISION.\n
        END PROGRAM
        FD
        FILE SECTION.\n
        ID DIVISION.\n
        IDENTIFICATION DIVISION.\n
        LINKAGE SECTION.\n
        LOCAL-STORAGE SECTION.\n
        PROCEDURE DIVISION
        PROGRAM-ID
        REPORT SECTION.\n
        SCREEN SECTION.\n
        SD
        WORKING-STORAGE SECTION.\n
    __rootdir__/prog.cob:5.24:
       2           IDENTIFICATION DIVISION.
       3           PROGRAM-ID . prog.
       4           DATA DIVISION.
       5 >         WORKING-STORAGE SECTION.
    ----                           ^
       6           01 DATA-NAME PIC X.
       7           PROCEDURE DIVISION.
    (line 4, character 24):
    Basic (1 entries): SECTION.\n
    Eager (1 entries): SECTION.\n
    __rootdir__/prog.cob:7.8:
       4           DATA DIVISION.
       5           WORKING-STORAGE SECTION.
       6           01 DATA-NAME PIC X.
       7 >         PROCEDURE DIVISION.
    ----           ^
       8             DISPLAY DATA-NAME
       9             STOP RUN.
    (line 6, character 8):
    Basic (11 entries):
        COMMUNICATION
        END PROGRAM
        ID
        IDENTIFICATION
        LINKAGE
        LOCAL-STORAGE
        PROCEDURE
        PROGRAM-ID
        REPORT
        SCREEN
        WORKING-STORAGE
    Eager (11 entries):
        COMMUNICATION SECTION.\n
        END PROGRAM
        ID DIVISION.\n
        IDENTIFICATION DIVISION.\n
        LINKAGE SECTION.\n
        LOCAL-STORAGE SECTION.\n
        PROCEDURE DIVISION
        PROGRAM-ID
        REPORT SECTION.\n
        SCREEN SECTION.\n
        WORKING-STORAGE SECTION.\n
    __rootdir__/prog.cob:7.18:
       4           DATA DIVISION.
       5           WORKING-STORAGE SECTION.
       6           01 DATA-NAME PIC X.
       7 >         PROCEDURE DIVISION.
    ----                     ^
       8             DISPLAY DATA-NAME
       9             STOP RUN.
    (line 6, character 18):
    Basic (1 entries): DIVISION
    Eager (1 entries): DIVISION |}];;

let%expect_test "datadiv-completion" =
  let end_with_postproc = completion_positions @@ extract_position_markers {cobol|
        IDENTIFICATION DIVISION.
        PROGRAM-ID. prog.
        DATA DIVISION.
        WORKING-STORAGE SECTION.
        01 _|_AA _|_PIC X.
        01 BB PIC X VAL-STATUS AA _|_WHEN _|_ERROR _|_ON RELATION FOR AA.
        _|_01 VAR PICTURE _|_X _|_USAGE _|_DISPLAY.
          88 BB _|_VALUES ARE _|_"x" _|_THRU "Z".
        PROCEDURE DIVISION.
          DISPLAY DATA-NAME.
          STOP RUN.
  |cobol}
 in
  end_with_postproc [%expect.output];
  [%expect {|
    {"params":{"diagnostics":[],"uri":"file://__rootdir__/prog.cob"},"method":"textDocument/publishDiagnostics","jsonrpc":"2.0"}
    __rootdir__/prog.cob:6.11:
       3           PROGRAM-ID. prog.
       4           DATA DIVISION.
       5           WORKING-STORAGE SECTION.
       6 >         01 AA PIC X.
    ----              ^
       7           01 BB PIC X VAL-STATUS AA WHEN ERROR ON RELATION FOR AA.
       8           01 VAR PICTURE X USAGE DISPLAY.
    (line 5, character 11):
    Basic (74 entries):
        ALIGNED
        ANY
        BASED
        BINARY
        BINARY-CHAR
        BINARY-C-LONG
        BINARY-DOUBLE
        BINARY-LONG
        BINARY-SHORT
        BIT
        BLANK
        CLASS
        COMP
        COMP-0
        COMP-1
        COMP-10
        COMP-15
        COMP-2
        COMP-3
        COMP-4
        COMP-5
        COMP-6
        COMP-9
        COMP-N
        COMP-X
        CONSTANT RECORD
        DEFAULT
        DESTINATION
        DISPLAY
        DYNAMIC
        EXTERNAL
        FILLER
        FLOAT-BINARY-128
        FLOAT-BINARY-32
        FLOAT-BINARY-64
        FLOAT-DECIMAL-16
        FLOAT-DECIMAL-34
        FLOAT-EXTENDED
        FLOAT-LONG
        FLOAT-SHORT
        FUNCTION-POINTER
        GLOBAL
        GROUP-USAGE
        INDEX
        INVALID
        IS EXTERNAL
        IS GLOBAL
        IS TYPEDEF
        JUSTIFIED
        LEADING
        NATIONAL
        OBJECT
        OCCURS
        PACKED-DECIMAL
        .\n
        PICTURE
        POINTER
        PRESENT
        PROCEDURE-POINTER
        PROGRAM-POINTER
        PROPERTY
        REDEFINES
        SAME
        SELECT
        SIGN
        SYNCHRONIZED
        TRAILING
        TYPE
        TYPEDEF
        USAGE
        VAL-STATUS
        VALUE
        VALUES
        VARYING
    Eager (74 entries):
        ALIGNED
        ANY LENGTH
        BASED
        BINARY
        BINARY-CHAR
        BINARY-C-LONG
        BINARY-DOUBLE
        BINARY-LONG
        BINARY-SHORT
        BIT
        BLANK
        CLASS
        COMP
        COMP-0
        COMP-1
        COMP-10
        COMP-15
        COMP-2
        COMP-3
        COMP-4
        COMP-5
        COMP-6
        COMP-9
        COMP-N
        COMP-X
        CONSTANT RECORD
        DEFAULT
        DESTINATION
        DISPLAY
        DYNAMIC
        EXTERNAL
        FILLER
        FLOAT-BINARY-128
        FLOAT-BINARY-32
        FLOAT-BINARY-64
        FLOAT-DECIMAL-16
        FLOAT-DECIMAL-34
        FLOAT-EXTENDED
        FLOAT-LONG
        FLOAT-SHORT
        FUNCTION-POINTER
        GLOBAL
        GROUP-USAGE
        INDEX
        INVALID WHEN
        IS EXTERNAL
        IS GLOBAL
        IS TYPEDEF
        JUSTIFIED
        LEADING
        NATIONAL
        OBJECT REFERENCE
        OCCURS
        PACKED-DECIMAL
        .\n
        PICTURE
        POINTER
        PRESENT WHEN
        PROCEDURE-POINTER
        PROGRAM-POINTER
        PROPERTY
        REDEFINES
        SAME AS
        SELECT WHEN
        SIGN
        SYNCHRONIZED
        TRAILING
        TYPE
        TYPEDEF
        USAGE
        VAL-STATUS
        VALUE
        VALUES
        VARYING
    __rootdir__/prog.cob:6.14:
       3           PROGRAM-ID. prog.
       4           DATA DIVISION.
       5           WORKING-STORAGE SECTION.
       6 >         01 AA PIC X.
    ----                 ^
       7           01 BB PIC X VAL-STATUS AA WHEN ERROR ON RELATION FOR AA.
       8           01 VAR PICTURE X USAGE DISPLAY.
    (line 5, character 14):
    Basic (75 entries):
        ALIGNED
        ANY
        BASED
        BINARY
        BINARY-CHAR
        BINARY-C-LONG
        BINARY-DOUBLE
        BINARY-LONG
        BINARY-SHORT
        BIT
        BLANK
        CLASS
        COMP
        COMP-0
        COMP-1
        COMP-10
        COMP-15
        COMP-2
        COMP-3
        COMP-4
        COMP-5
        COMP-6
        COMP-9
        COMP-N
        COMP-X
        CONSTANT
        CONSTANT RECORD
        DEFAULT
        DESTINATION
        DISPLAY
        DYNAMIC
        EXTERNAL
        FLOAT-BINARY-128
        FLOAT-BINARY-32
        FLOAT-BINARY-64
        FLOAT-DECIMAL-16
        FLOAT-DECIMAL-34
        FLOAT-EXTENDED
        FLOAT-LONG
        FLOAT-SHORT
        FUNCTION-POINTER
        GLOBAL
        GROUP-USAGE
        INDEX
        INVALID
        IS EXTERNAL
        IS GLOBAL
        IS TYPEDEF
        JUSTIFIED
        LEADING
        NATIONAL
        OBJECT
        OCCURS
        PACKED-DECIMAL
        .\n
        PICTURE
        POINTER
        PRESENT
        PROCEDURE-POINTER
        PROGRAM-POINTER
        PROPERTY
        REDEFINES
        RENAMES
        SAME
        SELECT
        SIGN
        SYNCHRONIZED
        TRAILING
        TYPE
        TYPEDEF
        USAGE
        VAL-STATUS
        VALUE
        VALUES
        VARYING
    Eager (75 entries):
        ALIGNED
        ANY LENGTH
        BASED
        BINARY
        BINARY-CHAR
        BINARY-C-LONG
        BINARY-DOUBLE
        BINARY-LONG
        BINARY-SHORT
        BIT
        BLANK
        CLASS
        COMP
        COMP-0
        COMP-1
        COMP-10
        COMP-15
        COMP-2
        COMP-3
        COMP-4
        COMP-5
        COMP-6
        COMP-9
        COMP-N
        COMP-X
        CONSTANT
        CONSTANT RECORD
        DEFAULT
        DESTINATION
        DISPLAY
        DYNAMIC
        EXTERNAL
        FLOAT-BINARY-128
        FLOAT-BINARY-32
        FLOAT-BINARY-64
        FLOAT-DECIMAL-16
        FLOAT-DECIMAL-34
        FLOAT-EXTENDED
        FLOAT-LONG
        FLOAT-SHORT
        FUNCTION-POINTER
        GLOBAL
        GROUP-USAGE
        INDEX
        INVALID WHEN
        IS EXTERNAL
        IS GLOBAL
        IS TYPEDEF
        JUSTIFIED
        LEADING
        NATIONAL
        OBJECT REFERENCE
        OCCURS
        PACKED-DECIMAL
        .\n
        PICTURE
        POINTER
        PRESENT WHEN
        PROCEDURE-POINTER
        PROGRAM-POINTER
        PROPERTY
        REDEFINES
        RENAMES
        SAME AS
        SELECT WHEN
        SIGN
        SYNCHRONIZED
        TRAILING
        TYPE
        TYPEDEF
        USAGE
        VAL-STATUS
        VALUE
        VALUES
        VARYING
    __rootdir__/prog.cob:7.34:
       4           DATA DIVISION.
       5           WORKING-STORAGE SECTION.
       6           01 AA PIC X.
       7 >         01 BB PIC X VAL-STATUS AA WHEN ERROR ON RELATION FOR AA.
    ----                                     ^
       8           01 VAR PICTURE X USAGE DISPLAY.
       9             88 BB VALUES ARE "x" THRU "Z".
    (line 6, character 34):
    Basic (9 entries): AS FACTORY OF AS UNIVERSAL AS ERROR IN NO OF SUPER OF WHEN
    Eager (6 entries): AS ERROR IN NO ERROR OF WHEN
    __rootdir__/prog.cob:7.39:
       4           DATA DIVISION.
       5           WORKING-STORAGE SECTION.
       6           01 AA PIC X.
       7 >         01 BB PIC X VAL-STATUS AA WHEN ERROR ON RELATION FOR AA.
    ----                                          ^
       8           01 VAR PICTURE X USAGE DISPLAY.
       9             88 BB VALUES ARE "x" THRU "Z".
    (line 6, character 39):
    Basic (2 entries): ERROR NO
    Eager (2 entries): ERROR NO ERROR
    __rootdir__/prog.cob:7.45:
       4           DATA DIVISION.
       5           WORKING-STORAGE SECTION.
       6           01 AA PIC X.
       7 >         01 BB PIC X VAL-STATUS AA WHEN ERROR ON RELATION FOR AA.
    ----                                                ^
       8           01 VAR PICTURE X USAGE DISPLAY.
       9             88 BB VALUES ARE "x" THRU "Z".
    (line 6, character 45):
    Basic (2 entries): FOR ON
    Eager (2 entries): FOR ON
    __rootdir__/prog.cob:8.8:
       5           WORKING-STORAGE SECTION.
       6           01 AA PIC X.
       7           01 BB PIC X VAL-STATUS AA WHEN ERROR ON RELATION FOR AA.
       8 >         01 VAR PICTURE X USAGE DISPLAY.
    ----           ^
       9             88 BB VALUES ARE "x" THRU "Z".
      10           PROCEDURE DIVISION.
    (line 7, character 8):
    Basic (11 entries):
        COMMUNICATION
        END PROGRAM
        ID
        IDENTIFICATION
        LINKAGE
        LOCAL-STORAGE
        PROCEDURE
        PROGRAM-ID
        REPORT
        SCREEN
        WORKING-STORAGE
    Eager (11 entries):
        COMMUNICATION SECTION.\n
        END PROGRAM
        ID DIVISION.\n
        IDENTIFICATION DIVISION.\n
        LINKAGE SECTION.\n
        LOCAL-STORAGE SECTION.\n
        PROCEDURE DIVISION
        PROGRAM-ID
        REPORT SECTION.\n
        SCREEN SECTION.\n
        WORKING-STORAGE SECTION.\n
    __rootdir__/prog.cob:8.23:
       5           WORKING-STORAGE SECTION.
       6           01 AA PIC X.
       7           01 BB PIC X VAL-STATUS AA WHEN ERROR ON RELATION FOR AA.
       8 >         01 VAR PICTURE X USAGE DISPLAY.
    ----                          ^
       9             88 BB VALUES ARE "x" THRU "Z".
      10           PROCEDURE DIVISION.
    (line 7, character 23):
    Basic (1 entries): IS
    Eager (1 entries): IS
    __rootdir__/prog.cob:8.25:
       5           WORKING-STORAGE SECTION.
       6           01 AA PIC X.
       7           01 BB PIC X VAL-STATUS AA WHEN ERROR ON RELATION FOR AA.
       8 >         01 VAR PICTURE X USAGE DISPLAY.
    ----                            ^
       9             88 BB VALUES ARE "x" THRU "Z".
      10           PROCEDURE DIVISION.
    (line 7, character 25):
    Basic (75 entries):
        ALIGNED
        ANY
        BASED
        BINARY
        BINARY-CHAR
        BINARY-C-LONG
        BINARY-DOUBLE
        BINARY-LONG
        BINARY-SHORT
        BIT
        BLANK
        CLASS
        COMP
        COMP-0
        COMP-1
        COMP-10
        COMP-15
        COMP-2
        COMP-3
        COMP-4
        COMP-5
        COMP-6
        COMP-9
        COMP-N
        COMP-X
        CONSTANT RECORD
        DEFAULT
        DEPENDING
        DESTINATION
        DISPLAY
        DYNAMIC
        EXTERNAL
        FLOAT-BINARY-128
        FLOAT-BINARY-32
        FLOAT-BINARY-64
        FLOAT-DECIMAL-16
        FLOAT-DECIMAL-34
        FLOAT-EXTENDED
        FLOAT-LONG
        FLOAT-SHORT
        FUNCTION-POINTER
        GLOBAL
        GROUP-USAGE
        INDEX
        INVALID
        IS EXTERNAL
        IS GLOBAL
        IS TYPEDEF
        JUSTIFIED
        LEADING
        LOCALE
        NATIONAL
        OBJECT
        OCCURS
        PACKED-DECIMAL
        .\n
        PICTURE
        POINTER
        PRESENT
        PROCEDURE-POINTER
        PROGRAM-POINTER
        PROPERTY
        REDEFINES
        SAME
        SELECT
        SIGN
        SYNCHRONIZED
        TRAILING
        TYPE
        TYPEDEF
        USAGE
        VAL-STATUS
        VALUE
        VALUES
        VARYING
    Eager (75 entries):
        ALIGNED
        ANY LENGTH
        BASED
        BINARY
        BINARY-CHAR
        BINARY-C-LONG
        BINARY-DOUBLE
        BINARY-LONG
        BINARY-SHORT
        BIT
        BLANK
        CLASS
        COMP
        COMP-0
        COMP-1
        COMP-10
        COMP-15
        COMP-2
        COMP-3
        COMP-4
        COMP-5
        COMP-6
        COMP-9
        COMP-N
        COMP-X
        CONSTANT RECORD
        DEFAULT
        DEPENDING
        DESTINATION
        DISPLAY
        DYNAMIC
        EXTERNAL
        FLOAT-BINARY-128
        FLOAT-BINARY-32
        FLOAT-BINARY-64
        FLOAT-DECIMAL-16
        FLOAT-DECIMAL-34
        FLOAT-EXTENDED
        FLOAT-LONG
        FLOAT-SHORT
        FUNCTION-POINTER
        GLOBAL
        GROUP-USAGE
        INDEX
        INVALID WHEN
        IS EXTERNAL
        IS GLOBAL
        IS TYPEDEF
        JUSTIFIED
        LEADING
        LOCALE
        NATIONAL
        OBJECT REFERENCE
        OCCURS
        PACKED-DECIMAL
        .\n
        PICTURE
        POINTER
        PRESENT WHEN
        PROCEDURE-POINTER
        PROGRAM-POINTER
        PROPERTY
        REDEFINES
        SAME AS
        SELECT WHEN
        SIGN
        SYNCHRONIZED
        TRAILING
        TYPE
        TYPEDEF
        USAGE
        VAL-STATUS
        VALUE
        VALUES
        VARYING
    __rootdir__/prog.cob:8.31:
       5           WORKING-STORAGE SECTION.
       6           01 AA PIC X.
       7           01 BB PIC X VAL-STATUS AA WHEN ERROR ON RELATION FOR AA.
       8 >         01 VAR PICTURE X USAGE DISPLAY.
    ----                                  ^
       9             88 BB VALUES ARE "x" THRU "Z".
      10           PROCEDURE DIVISION.
    (line 7, character 31):
    Basic (38 entries):
        BINARY
        BINARY-CHAR
        BINARY-C-LONG
        BINARY-DOUBLE
        BINARY-LONG
        BINARY-SHORT
        BIT
        COMP
        COMP-0
        COMP-1
        COMP-10
        COMP-15
        COMP-2
        COMP-3
        COMP-4
        COMP-5
        COMP-6
        COMP-9
        COMP-N
        COMP-X
        DISPLAY
        FLOAT-BINARY-128
        FLOAT-BINARY-32
        FLOAT-BINARY-64
        FLOAT-DECIMAL-16
        FLOAT-DECIMAL-34
        FLOAT-EXTENDED
        FLOAT-LONG
        FLOAT-SHORT
        FUNCTION-POINTER
        INDEX
        IS
        NATIONAL
        OBJECT
        PACKED-DECIMAL
        POINTER
        PROCEDURE-POINTER
        PROGRAM-POINTER
    Eager (38 entries):
        BINARY
        BINARY-CHAR
        BINARY-C-LONG
        BINARY-DOUBLE
        BINARY-LONG
        BINARY-SHORT
        BIT
        COMP
        COMP-0
        COMP-1
        COMP-10
        COMP-15
        COMP-2
        COMP-3
        COMP-4
        COMP-5
        COMP-6
        COMP-9
        COMP-N
        COMP-X
        DISPLAY
        FLOAT-BINARY-128
        FLOAT-BINARY-32
        FLOAT-BINARY-64
        FLOAT-DECIMAL-16
        FLOAT-DECIMAL-34
        FLOAT-EXTENDED
        FLOAT-LONG
        FLOAT-SHORT
        FUNCTION-POINTER
        INDEX
        IS
        NATIONAL
        OBJECT REFERENCE
        PACKED-DECIMAL
        POINTER
        PROCEDURE-POINTER
        PROGRAM-POINTER
    __rootdir__/prog.cob:9.16:
       6           01 AA PIC X.
       7           01 BB PIC X VAL-STATUS AA WHEN ERROR ON RELATION FOR AA.
       8           01 VAR PICTURE X USAGE DISPLAY.
       9 >           88 BB VALUES ARE "x" THRU "Z".
    ----                   ^
      10           PROCEDURE DIVISION.
      11             DISPLAY DATA-NAME.
    (line 8, character 16):
    Basic (2 entries): VALUE VALUES
    Eager (2 entries): VALUE VALUES
    __rootdir__/prog.cob:9.27:
       6           01 AA PIC X.
       7           01 BB PIC X VAL-STATUS AA WHEN ERROR ON RELATION FOR AA.
       8           01 VAR PICTURE X USAGE DISPLAY.
       9 >           88 BB VALUES ARE "x" THRU "Z".
    ----                              ^
      10           PROCEDURE DIVISION.
      11             DISPLAY DATA-NAME.
    (line 8, character 27):
    Basic (6 entries): ALL HIGH-VALUES LOW-VALUES QUOTES SPACES ZEROS
    Eager (6 entries): ALL HIGH-VALUES LOW-VALUES QUOTES SPACES ZEROS
    __rootdir__/prog.cob:9.31:
       6           01 AA PIC X.
       7           01 BB PIC X VAL-STATUS AA WHEN ERROR ON RELATION FOR AA.
       8           01 VAR PICTURE X USAGE DISPLAY.
       9 >           88 BB VALUES ARE "x" THRU "Z".
    ----                                  ^
      10           PROCEDURE DIVISION.
      11             DISPLAY DATA-NAME.
    (line 8, character 31):
    Basic (13 entries):
        ALL
        FALSE
        HIGH-VALUES
        IN
        LOW-VALUES
        .\n
        QUOTES
        SET
        SPACES
        THRU
        TO
        WHEN
        ZEROS
    Eager (13 entries):
        ALL
        FALSE
        HIGH-VALUES
        IN
        LOW-VALUES
        .\n
        QUOTES
        SET
        SPACES
        THRU
        TO FALSE
        WHEN
        ZEROS |}];;

let%expect_test "procedure-paragraph-completion" =
  let end_with_postproc = completion_positions @@ extract_position_markers {cobol|
        IDENTIFICATION DIVISION.
        PROGRAM-ID. prog.
        DATA DIVISION.
        WORKING-STORAGE SECTION.
        01 DATA-NAME PIC X.
        01 VAR PICTURE X USAGE DISPLAY.
        PROCEDURE DIVISION.
          _|_FIRST-SECTION _|_SECTION.
            _|_DISPLAY DATA-NAME.
          _|_FIRST-PARAGRAPH.
            DISPLAY VAR.
            SECOND-SECTION SECTION.
              PERFORM _|_FIRST-PARAGRAPH.
          STOP RUN.
  |cobol} in
  end_with_postproc [%expect.output];
  [%expect {|
    {"params":{"diagnostics":[],"uri":"file://__rootdir__/prog.cob"},"method":"textDocument/publishDiagnostics","jsonrpc":"2.0"}
    __rootdir__/prog.cob:9.10:
       6           01 DATA-NAME PIC X.
       7           01 VAR PICTURE X USAGE DISPLAY.
       8           PROCEDURE DIVISION.
       9 >           FIRST-SECTION SECTION.
    ----             ^
      10               DISPLAY DATA-NAME.
      11             FIRST-PARAGRAPH.
    (line 8, character 10):
    Basic (62 entries):
        ACCEPT
        ADD
        ALLOCATE
        ALTER
        CALL
        CANCEL
        CLOSE
        COMPUTE
        CONTINUE
        DECLARATIVES
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END PROGRAM
        ENTER
        ENTRY
        EVALUATE
        EXIT
        FREE
        GENERATE
        GO
        GOBACK
        ID
        IDENTIFICATION
        IF
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        MERGE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        OPEN
        PERFORM
        .\n
        PROGRAM-ID
        PURGE
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REWRITE
        SEARCH
        SEND
        SET
        SORT
        START
        STOP
        STRING
        SUBTRACT
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNLOCK
        UNSTRING
        VALIDATE
        WRITE
    Eager (62 entries):
        ACCEPT
        ADD
        ALLOCATE
        ALTER
        CALL
        CANCEL
        CLOSE
        COMPUTE
        CONTINUE
        DECLARATIVES.\n
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END PROGRAM
        ENTER
        ENTRY
        EVALUATE
        EXIT
        FREE
        GENERATE
        GO
        GOBACK
        ID DIVISION.\n
        IDENTIFICATION DIVISION.\n
        IF
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        MERGE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        OPEN
        PERFORM
        .\n
        PROGRAM-ID
        PURGE
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REWRITE
        SEARCH
        SEND
        SET
        SORT
        START
        STOP
        STRING
        SUBTRACT
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNLOCK
        UNSTRING
        VALIDATE
        WRITE
    __rootdir__/prog.cob:9.24:
       6           01 DATA-NAME PIC X.
       7           01 VAR PICTURE X USAGE DISPLAY.
       8           PROCEDURE DIVISION.
       9 >           FIRST-SECTION SECTION.
    ----                           ^
      10               DISPLAY DATA-NAME.
      11             FIRST-PARAGRAPH.
    (line 8, character 24):
    Basic (2 entries): .\n SECTION
    Eager (2 entries): .\n SECTION
    __rootdir__/prog.cob:10.12:
       7           01 VAR PICTURE X USAGE DISPLAY.
       8           PROCEDURE DIVISION.
       9             FIRST-SECTION SECTION.
      10 >             DISPLAY DATA-NAME.
    ----               ^
      11             FIRST-PARAGRAPH.
      12               DISPLAY VAR.
    (line 9, character 12):
    Basic (61 entries):
        ACCEPT
        ADD
        ALLOCATE
        ALTER
        CALL
        CANCEL
        CLOSE
        COMPUTE
        CONTINUE
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END PROGRAM
        ENTER
        ENTRY
        EVALUATE
        EXIT
        FREE
        GENERATE
        GO
        GOBACK
        ID
        IDENTIFICATION
        IF
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        MERGE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        OPEN
        PERFORM
        .\n
        PROGRAM-ID
        PURGE
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REWRITE
        SEARCH
        SEND
        SET
        SORT
        START
        STOP
        STRING
        SUBTRACT
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNLOCK
        UNSTRING
        VALIDATE
        WRITE
    Eager (61 entries):
        ACCEPT
        ADD
        ALLOCATE
        ALTER
        CALL
        CANCEL
        CLOSE
        COMPUTE
        CONTINUE
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END PROGRAM
        ENTER
        ENTRY
        EVALUATE
        EXIT
        FREE
        GENERATE
        GO
        GOBACK
        ID DIVISION.\n
        IDENTIFICATION DIVISION.\n
        IF
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        MERGE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        OPEN
        PERFORM
        .\n
        PROGRAM-ID
        PURGE
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REWRITE
        SEARCH
        SEND
        SET
        SORT
        START
        STOP
        STRING
        SUBTRACT
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNLOCK
        UNSTRING
        VALIDATE
        WRITE
    __rootdir__/prog.cob:11.10:
       8           PROCEDURE DIVISION.
       9             FIRST-SECTION SECTION.
      10               DISPLAY DATA-NAME.
      11 >           FIRST-PARAGRAPH.
    ----             ^
      12               DISPLAY VAR.
      13               SECOND-SECTION SECTION.
    (line 10, character 10):
    Basic (61 entries):
        ACCEPT
        ADD
        ALLOCATE
        ALTER
        CALL
        CANCEL
        CLOSE
        COMPUTE
        CONTINUE
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END PROGRAM
        ENTER
        ENTRY
        EVALUATE
        EXIT
        FREE
        GENERATE
        GO
        GOBACK
        ID
        IDENTIFICATION
        IF
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        MERGE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        OPEN
        PERFORM
        .\n
        PROGRAM-ID
        PURGE
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REWRITE
        SEARCH
        SEND
        SET
        SORT
        START
        STOP
        STRING
        SUBTRACT
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNLOCK
        UNSTRING
        VALIDATE
        WRITE
    Eager (61 entries):
        ACCEPT
        ADD
        ALLOCATE
        ALTER
        CALL
        CANCEL
        CLOSE
        COMPUTE
        CONTINUE
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END PROGRAM
        ENTER
        ENTRY
        EVALUATE
        EXIT
        FREE
        GENERATE
        GO
        GOBACK
        ID DIVISION.\n
        IDENTIFICATION DIVISION.\n
        IF
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        MERGE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        OPEN
        PERFORM
        .\n
        PROGRAM-ID
        PURGE
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REWRITE
        SEARCH
        SEND
        SET
        SORT
        START
        STOP
        STRING
        SUBTRACT
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNLOCK
        UNSTRING
        VALIDATE
        WRITE
    __rootdir__/prog.cob:14.22:
      11             FIRST-PARAGRAPH.
      12               DISPLAY VAR.
      13               SECOND-SECTION SECTION.
      14 >               PERFORM FIRST-PARAGRAPH.
    ----                         ^
      15             STOP RUN.
      16
    (line 13, character 22):
    Basic (78 entries):
        SECOND-SECTION
        FIRST-SECTION
        FIRST-PARAGRAPH IN FIRST-SECTION
        FIRST-PARAGRAPH
        DATA-NAME
        VAR
        ACCEPT
        ADD
        ADDRESS
        ALLOCATE
        ALTER
        CALL
        CANCEL
        CLOSE
        COMPUTE
        CONTINUE
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END-PERFORM
        ENTER
        ENTRY
        EVALUATE
        EXCEPTION-OBJECT
        EXIT
        FOREVER
        FREE
        FUNCTION
        GENERATE
        GO
        GOBACK
        IF
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        LINAGE-COUNTER
        LINE-COUNTER
        MERGE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        NULL
        OPEN
        PAGE-COUNTER
        PERFORM
        PURGE
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REWRITE
        SEARCH
        SELF
        SEND
        SET
        SORT
        START
        STOP
        STRING
        SUBTRACT
        SUPER
        SUPPRESS
        TERMINATE
        TEST
        TRANSFORM
        UNLOCK
        UNSTRING
        UNTIL
        VALIDATE
        VARYING
        WITH
        WRITE
        ZEROS
    Eager (78 entries):
        SECOND-SECTION
        FIRST-SECTION
        FIRST-PARAGRAPH IN FIRST-SECTION
        FIRST-PARAGRAPH
        DATA-NAME
        VAR
        ACCEPT
        ADD
        ADDRESS OF
        ALLOCATE
        ALTER
        CALL
        CANCEL
        CLOSE
        COMPUTE
        CONTINUE
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END-PERFORM
        ENTER
        ENTRY
        EVALUATE
        EXCEPTION-OBJECT
        EXIT
        FOREVER
        FREE
        FUNCTION
        GENERATE
        GO
        GOBACK
        IF
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        LINAGE-COUNTER
        LINE-COUNTER
        MERGE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        NULL
        OPEN
        PAGE-COUNTER
        PERFORM
        PURGE
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REWRITE
        SEARCH
        SELF
        SEND
        SET
        SORT
        START
        STOP
        STRING
        SUBTRACT
        SUPER
        SUPPRESS
        TERMINATE
        TEST
        TRANSFORM
        UNLOCK
        UNSTRING
        UNTIL
        VALIDATE
        VARYING
        WITH TEST
        WRITE
        ZEROS TIMES |}];;

let%expect_test "qualified-data-ref-completion" =
  let end_with_postproc = completion_positions @@ extract_position_markers {cobol|
        IDENTIFICATION DIVISION.
        PROGRAM-ID. prog.
        DATA DIVISION.
        WORKING-STORAGE SECTION.
        01 AA.
          02 CC PICTURE X USAGE DISPLAY.
            03 DD PICTURE X USAGE DISPLAY.
        01 BB.
          02 CC PICTURE X USAGE DISPLAY.
        PROCEDURE DIVISION.
          DISPLAY _|_AA.
          STOP RUN.
  |cobol} in
  end_with_postproc [%expect.output];
  [%expect {|
    {"params":{"diagnostics":[{"message":"Unexpected PICTURE clause for group item 'CC'","range":{"end":{"character":25,"line":6},"start":{"character":16,"line":6}},"severity":1}],"uri":"file://__rootdir__/prog.cob"},"method":"textDocument/publishDiagnostics","jsonrpc":"2.0"}
    __rootdir__/prog.cob:12.18:
       9           01 BB.
      10             02 CC PICTURE X USAGE DISPLAY.
      11           PROCEDURE DIVISION.
      12 >           DISPLAY AA.
    ----                     ^
      13             STOP RUN.
      14
    (line 11, character 18):
    Basic (23 entries):
        AA
        CC IN AA
        CC
        DD IN CC IN AA
        DD
        BB
        CC IN BB
        CC
        ADDRESS
        ALL
        EXCEPTION-OBJECT
        FUNCTION
        HIGH-VALUES
        LINAGE-COUNTER
        LINE-COUNTER
        LOW-VALUES
        NULL
        PAGE-COUNTER
        QUOTES
        SELF
        SPACES
        SUPER
        ZEROS
    Eager (23 entries):
        AA
        CC IN AA
        CC
        DD IN CC IN AA
        DD
        BB
        CC IN BB
        CC
        ADDRESS OF
        ALL
        EXCEPTION-OBJECT
        FUNCTION
        HIGH-VALUES
        LINAGE-COUNTER
        LINE-COUNTER
        LOW-VALUES
        NULL
        PAGE-COUNTER
        QUOTES
        SELF
        SPACES
        SUPER
        ZEROS |}];;

let%expect_test "procedure-completion" =
  let end_with_postproc = completion_positions @@ extract_position_markers {cobol|
        IDENTIFICATION DIVISION.
        PROGRAM-ID. prog.
        DATA DIVISION.
        WORKING-STORAGE SECTION.
        01 AA PIC X.
        01 BB PIC X.
        PROCEDURE DIVISION.
          _|_DISPLAY AA _|_.
          MOVE _|_AA _|_TO _|_BB.
          MULTIPLY 4 _|_BY 2 _|_GIVING BB
            ON SIZE ERROR
            DISPLAY "ERROR"
          END-MULTIPLY.
          MULTIPLY AA _|_BY BB _|_ROUNDED _|_MODE _|_IS _|_TRUNCATION
            _|_ON SIZE _|_ERROR
            _|_DISPLAY "ERROR"
          _|_END-MULTIPLY.
          STOP RUN.
  |cobol} in
  end_with_postproc [%expect.output];
  [%expect {|
    {"params":{"diagnostics":[],"uri":"file://__rootdir__/prog.cob"},"method":"textDocument/publishDiagnostics","jsonrpc":"2.0"}
    __rootdir__/prog.cob:9.10:
       6           01 AA PIC X.
       7           01 BB PIC X.
       8           PROCEDURE DIVISION.
       9 >           DISPLAY AA .
    ----             ^
      10             MOVE AA TO BB.
      11             MULTIPLY 4 BY 2 GIVING BB
    (line 8, character 10):
    Basic (62 entries):
        ACCEPT
        ADD
        ALLOCATE
        ALTER
        CALL
        CANCEL
        CLOSE
        COMPUTE
        CONTINUE
        DECLARATIVES
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END PROGRAM
        ENTER
        ENTRY
        EVALUATE
        EXIT
        FREE
        GENERATE
        GO
        GOBACK
        ID
        IDENTIFICATION
        IF
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        MERGE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        OPEN
        PERFORM
        .\n
        PROGRAM-ID
        PURGE
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REWRITE
        SEARCH
        SEND
        SET
        SORT
        START
        STOP
        STRING
        SUBTRACT
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNLOCK
        UNSTRING
        VALIDATE
        WRITE
    Eager (62 entries):
        ACCEPT
        ADD
        ALLOCATE
        ALTER
        CALL
        CANCEL
        CLOSE
        COMPUTE
        CONTINUE
        DECLARATIVES.\n
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END PROGRAM
        ENTER
        ENTRY
        EVALUATE
        EXIT
        FREE
        GENERATE
        GO
        GOBACK
        ID DIVISION.\n
        IDENTIFICATION DIVISION.\n
        IF
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        MERGE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        OPEN
        PERFORM
        .\n
        PROGRAM-ID
        PURGE
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REWRITE
        SEARCH
        SEND
        SET
        SORT
        START
        STOP
        STRING
        SUBTRACT
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNLOCK
        UNSTRING
        VALIDATE
        WRITE
    __rootdir__/prog.cob:9.21:
       6           01 AA PIC X.
       7           01 BB PIC X.
       8           PROCEDURE DIVISION.
       9 >           DISPLAY AA .
    ----                        ^
      10             MOVE AA TO BB.
      11             MULTIPLY 4 BY 2 GIVING BB
    (line 8, character 21):
    Basic (108 entries):
        AA
        BB
        ACCEPT
        ADD
        ADDRESS
        ALL
        ALLOCATE
        ALTER
        AS FACTORY OF
        AS UNIVERSAL
        AS
        AT
        BACKGROUND-COLOR
        BELL
        BLANK
        BLINK
        CALL
        CANCEL
        CLOSE
        COL
        COLUMN
        COMPUTE
        CONTINUE
        CONTROL
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END-DISPLAY
        ENTER
        ENTRY
        ERASE
        EVALUATE
        EXCEPTION
        EXCEPTION-OBJECT
        EXIT
        FOREGROUND-COLOR
        FREE
        FUNCTION
        GENERATE
        GO
        GOBACK
        GRID
        HIGHLIGHT
        HIGH-VALUES
        IF
        IN
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        LEFTLINE
        LINAGE-COUNTER
        LINE
        LINE-COUNTER
        LOWLIGHT
        LOW-VALUES
        MERGE
        MODE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        NOT ON EXCEPTION
        NULL
        OF SUPER
        OF
        ON EXCEPTION
        OPEN
        OVERLINE
        PAGE-COUNTER
        PERFORM
        .\n
        POSITION
        PURGE
        QUOTES
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REVERSE-VIDEO
        REWRITE
        SEARCH
        SELF
        SEND
        SET
        SIZE
        SORT
        SPACES
        START
        STOP
        STRING
        SUBTRACT
        SUPER
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNDERLINE
        UNLOCK
        UNSTRING
        UPON
        VALIDATE
        WITH
        WITH NO ADVANCING
        WRITE
        ZEROS
    Eager (105 entries):
        AA
        BB
        ACCEPT
        ADD
        ADDRESS OF
        ALL
        ALLOCATE
        ALTER
        AS
        AT
        BACKGROUND-COLOR
        BELL
        BLANK
        BLINK
        CALL
        CANCEL
        CLOSE
        COL
        COLUMN
        COMPUTE
        CONTINUE
        CONTROL
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END-DISPLAY
        ENTER
        ENTRY
        ERASE
        EVALUATE
        EXCEPTION
        EXCEPTION-OBJECT
        EXIT
        FOREGROUND-COLOR
        FREE
        FUNCTION
        GENERATE
        GO
        GOBACK
        GRID
        HIGHLIGHT
        HIGH-VALUES
        IF
        IN
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        LEFTLINE
        LINAGE-COUNTER
        LINE
        LINE-COUNTER
        LOWLIGHT
        LOW-VALUES
        MERGE
        MODE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        NOT ON EXCEPTION
        NULL
        OF
        ON EXCEPTION
        OPEN
        OVERLINE
        PAGE-COUNTER
        PERFORM
        .\n
        POSITION
        PURGE
        QUOTES
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REVERSE-VIDEO
        REWRITE
        SEARCH
        SELF
        SEND
        SET
        SIZE
        SORT
        SPACES
        START
        STOP
        STRING
        SUBTRACT
        SUPER
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNDERLINE
        UNLOCK
        UNSTRING
        UPON
        VALIDATE
        WITH
        WITH NO ADVANCING
        WRITE
        ZEROS
    __rootdir__/prog.cob:10.15:
       7           01 BB PIC X.
       8           PROCEDURE DIVISION.
       9             DISPLAY AA .
      10 >           MOVE AA TO BB.
    ----                  ^
      11             MULTIPLY 4 BY 2 GIVING BB
      12               ON SIZE ERROR
    (line 9, character 15):
    Basic (18 entries):
        AA
        BB
        ADDRESS
        ALL
        CORRESPONDING
        EXCEPTION-OBJECT
        FUNCTION
        HIGH-VALUES
        LINAGE-COUNTER
        LINE-COUNTER
        LOW-VALUES
        NULL
        PAGE-COUNTER
        QUOTES
        SELF
        SPACES
        SUPER
        ZEROS
    Eager (18 entries):
        AA
        BB
        ADDRESS OF
        ALL
        CORRESPONDING
        EXCEPTION-OBJECT
        FUNCTION
        HIGH-VALUES
        LINAGE-COUNTER
        LINE-COUNTER
        LOW-VALUES
        NULL
        PAGE-COUNTER
        QUOTES
        SELF
        SPACES
        SUPER
        ZEROS
    __rootdir__/prog.cob:10.18:
       7           01 BB PIC X.
       8           PROCEDURE DIVISION.
       9             DISPLAY AA .
      10 >           MOVE AA TO BB.
    ----                     ^
      11             MULTIPLY 4 BY 2 GIVING BB
      12               ON SIZE ERROR
    (line 9, character 18):
    Basic (7 entries): AS FACTORY OF AS UNIVERSAL AS IN OF SUPER OF TO
    Eager (4 entries): AS IN OF TO
    __rootdir__/prog.cob:10.21:
       7           01 BB PIC X.
       8           PROCEDURE DIVISION.
       9             DISPLAY AA .
      10 >           MOVE AA TO BB.
    ----                        ^
      11             MULTIPLY 4 BY 2 GIVING BB
      12               ON SIZE ERROR
    (line 9, character 21):
    Basic (11 entries):
        AA
        BB
        ADDRESS
        EXCEPTION-OBJECT
        FUNCTION
        LINAGE-COUNTER
        LINE-COUNTER
        NULL
        PAGE-COUNTER
        SELF
        SUPER
    Eager (11 entries):
        AA
        BB
        ADDRESS OF
        EXCEPTION-OBJECT
        FUNCTION
        LINAGE-COUNTER
        LINE-COUNTER
        NULL
        PAGE-COUNTER
        SELF
        SUPER
    __rootdir__/prog.cob:11.21:
       8           PROCEDURE DIVISION.
       9             DISPLAY AA .
      10             MOVE AA TO BB.
      11 >           MULTIPLY 4 BY 2 GIVING BB
    ----                        ^
      12               ON SIZE ERROR
      13               DISPLAY "ERROR"
    (line 10, character 21):
    Basic (1 entries): BY
    Eager (1 entries): BY
    __rootdir__/prog.cob:11.26:
       8           PROCEDURE DIVISION.
       9             DISPLAY AA .
      10             MOVE AA TO BB.
      11 >           MULTIPLY 4 BY 2 GIVING BB
    ----                             ^
      12               ON SIZE ERROR
      13               DISPLAY "ERROR"
    (line 10, character 26):
    Basic (1 entries): GIVING
    Eager (1 entries): GIVING
    __rootdir__/prog.cob:15.22:
      12               ON SIZE ERROR
      13               DISPLAY "ERROR"
      14             END-MULTIPLY.
      15 >           MULTIPLY AA BY BB ROUNDED MODE IS TRUNCATION
    ----                         ^
      16               ON SIZE ERROR
      17               DISPLAY "ERROR"
    (line 14, character 22):
    Basic (7 entries): AS FACTORY OF AS UNIVERSAL AS BY IN OF SUPER OF
    Eager (4 entries): AS BY IN OF
    __rootdir__/prog.cob:15.28:
      12               ON SIZE ERROR
      13               DISPLAY "ERROR"
      14             END-MULTIPLY.
      15 >           MULTIPLY AA BY BB ROUNDED MODE IS TRUNCATION
    ----                               ^
      16               ON SIZE ERROR
      17               DISPLAY "ERROR"
    (line 14, character 28):
    Basic (79 entries):
        AA
        BB
        ACCEPT
        ADD
        ADDRESS
        ALLOCATE
        ALTER
        AS FACTORY OF
        AS UNIVERSAL
        AS
        CALL
        CANCEL
        CLOSE
        COMPUTE
        CONTINUE
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END-MULTIPLY
        ENTER
        ENTRY
        EVALUATE
        EXCEPTION-OBJECT
        EXIT
        FREE
        FUNCTION
        GENERATE
        GIVING
        GO
        GOBACK
        IF
        IN
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        LINAGE-COUNTER
        LINE-COUNTER
        MERGE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        NOT ON SIZE ERROR
        NULL
        OF SUPER
        OF
        ON SIZE ERROR
        OPEN
        PAGE-COUNTER
        PERFORM
        .\n
        PURGE
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REWRITE
        ROUNDED
        SEARCH
        SELF
        SEND
        SET
        SORT
        START
        STOP
        STRING
        SUBTRACT
        SUPER
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNLOCK
        UNSTRING
        VALIDATE
        WRITE
    Eager (76 entries):
        AA
        BB
        ACCEPT
        ADD
        ADDRESS OF
        ALLOCATE
        ALTER
        AS
        CALL
        CANCEL
        CLOSE
        COMPUTE
        CONTINUE
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END-MULTIPLY
        ENTER
        ENTRY
        EVALUATE
        EXCEPTION-OBJECT
        EXIT
        FREE
        FUNCTION
        GENERATE
        GIVING
        GO
        GOBACK
        IF
        IN
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        LINAGE-COUNTER
        LINE-COUNTER
        MERGE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        NOT ON SIZE ERROR
        NULL
        OF
        ON SIZE ERROR
        OPEN
        PAGE-COUNTER
        PERFORM
        .\n
        PURGE
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REWRITE
        ROUNDED
        SEARCH
        SELF
        SEND
        SET
        SORT
        START
        STOP
        STRING
        SUBTRACT
        SUPER
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNLOCK
        UNSTRING
        VALIDATE
        WRITE
    __rootdir__/prog.cob:15.36:
      12               ON SIZE ERROR
      13               DISPLAY "ERROR"
      14             END-MULTIPLY.
      15 >           MULTIPLY AA BY BB ROUNDED MODE IS TRUNCATION
    ----                                       ^
      16               ON SIZE ERROR
      17               DISPLAY "ERROR"
    (line 14, character 36):
    Basic (72 entries):
        AA
        BB
        ACCEPT
        ADD
        ADDRESS
        ALLOCATE
        ALTER
        CALL
        CANCEL
        CLOSE
        COMPUTE
        CONTINUE
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END-MULTIPLY
        ENTER
        ENTRY
        EVALUATE
        EXCEPTION-OBJECT
        EXIT
        FREE
        FUNCTION
        GENERATE
        GO
        GOBACK
        IF
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        LINAGE-COUNTER
        LINE-COUNTER
        MERGE
        MODE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        NOT ON SIZE ERROR
        NULL
        ON SIZE ERROR
        OPEN
        PAGE-COUNTER
        PERFORM
        .\n
        PURGE
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REWRITE
        SEARCH
        SELF
        SEND
        SET
        SORT
        START
        STOP
        STRING
        SUBTRACT
        SUPER
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNLOCK
        UNSTRING
        VALIDATE
        WRITE
    Eager (72 entries):
        AA
        BB
        ACCEPT
        ADD
        ADDRESS OF
        ALLOCATE
        ALTER
        CALL
        CANCEL
        CLOSE
        COMPUTE
        CONTINUE
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END-MULTIPLY
        ENTER
        ENTRY
        EVALUATE
        EXCEPTION-OBJECT
        EXIT
        FREE
        FUNCTION
        GENERATE
        GO
        GOBACK
        IF
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        LINAGE-COUNTER
        LINE-COUNTER
        MERGE
        MODE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        NOT ON SIZE ERROR
        NULL
        ON SIZE ERROR
        OPEN
        PAGE-COUNTER
        PERFORM
        .\n
        PURGE
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REWRITE
        SEARCH
        SELF
        SEND
        SET
        SORT
        START
        STOP
        STRING
        SUBTRACT
        SUPER
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNLOCK
        UNSTRING
        VALIDATE
        WRITE
    __rootdir__/prog.cob:15.41:
      12               ON SIZE ERROR
      13               DISPLAY "ERROR"
      14             END-MULTIPLY.
      15 >           MULTIPLY AA BY BB ROUNDED MODE IS TRUNCATION
    ----                                            ^
      16               ON SIZE ERROR
      17               DISPLAY "ERROR"
    (line 14, character 41):
    Basic (9 entries):
        AWAY-FROM-ZERO
        IS
        NEAREST-AWAY-FROM-ZERO
        NEAREST-EVEN
        NEAREST-TOWARD-ZERO
        PROHIBITED
        TOWARD-GREATER
        TOWARD-LESSER
        TRUNCATION
    Eager (9 entries):
        AWAY-FROM-ZERO
        IS
        NEAREST-AWAY-FROM-ZERO
        NEAREST-EVEN
        NEAREST-TOWARD-ZERO
        PROHIBITED
        TOWARD-GREATER
        TOWARD-LESSER
        TRUNCATION
    __rootdir__/prog.cob:15.44:
      12               ON SIZE ERROR
      13               DISPLAY "ERROR"
      14             END-MULTIPLY.
      15 >           MULTIPLY AA BY BB ROUNDED MODE IS TRUNCATION
    ----                                               ^
      16               ON SIZE ERROR
      17               DISPLAY "ERROR"
    (line 14, character 44):
    Basic (8 entries):
        AWAY-FROM-ZERO
        NEAREST-AWAY-FROM-ZERO
        NEAREST-EVEN
        NEAREST-TOWARD-ZERO
        PROHIBITED
        TOWARD-GREATER
        TOWARD-LESSER
        TRUNCATION
    Eager (8 entries):
        AWAY-FROM-ZERO
        NEAREST-AWAY-FROM-ZERO
        NEAREST-EVEN
        NEAREST-TOWARD-ZERO
        PROHIBITED
        TOWARD-GREATER
        TOWARD-LESSER
        TRUNCATION
    __rootdir__/prog.cob:16.12:
      13               DISPLAY "ERROR"
      14             END-MULTIPLY.
      15             MULTIPLY AA BY BB ROUNDED MODE IS TRUNCATION
      16 >             ON SIZE ERROR
    ----               ^
      17               DISPLAY "ERROR"
      18             END-MULTIPLY.
    (line 15, character 12):
    Basic (71 entries):
        AA
        BB
        ACCEPT
        ADD
        ADDRESS
        ALLOCATE
        ALTER
        CALL
        CANCEL
        CLOSE
        COMPUTE
        CONTINUE
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END-MULTIPLY
        ENTER
        ENTRY
        EVALUATE
        EXCEPTION-OBJECT
        EXIT
        FREE
        FUNCTION
        GENERATE
        GO
        GOBACK
        IF
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        LINAGE-COUNTER
        LINE-COUNTER
        MERGE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        NOT ON SIZE ERROR
        NULL
        ON SIZE ERROR
        OPEN
        PAGE-COUNTER
        PERFORM
        .\n
        PURGE
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REWRITE
        SEARCH
        SELF
        SEND
        SET
        SORT
        START
        STOP
        STRING
        SUBTRACT
        SUPER
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNLOCK
        UNSTRING
        VALIDATE
        WRITE
    Eager (71 entries):
        AA
        BB
        ACCEPT
        ADD
        ADDRESS OF
        ALLOCATE
        ALTER
        CALL
        CANCEL
        CLOSE
        COMPUTE
        CONTINUE
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END-MULTIPLY
        ENTER
        ENTRY
        EVALUATE
        EXCEPTION-OBJECT
        EXIT
        FREE
        FUNCTION
        GENERATE
        GO
        GOBACK
        IF
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        LINAGE-COUNTER
        LINE-COUNTER
        MERGE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        NOT ON SIZE ERROR
        NULL
        ON SIZE ERROR
        OPEN
        PAGE-COUNTER
        PERFORM
        .\n
        PURGE
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REWRITE
        SEARCH
        SELF
        SEND
        SET
        SORT
        START
        STOP
        STRING
        SUBTRACT
        SUPER
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNLOCK
        UNSTRING
        VALIDATE
        WRITE
    __rootdir__/prog.cob:16.20:
      13               DISPLAY "ERROR"
      14             END-MULTIPLY.
      15             MULTIPLY AA BY BB ROUNDED MODE IS TRUNCATION
      16 >             ON SIZE ERROR
    ----                       ^
      17               DISPLAY "ERROR"
      18             END-MULTIPLY.
    (line 15, character 20):
    Empty completion list
    Empty eager-completion list
    __rootdir__/prog.cob:17.12:
      14             END-MULTIPLY.
      15             MULTIPLY AA BY BB ROUNDED MODE IS TRUNCATION
      16               ON SIZE ERROR
      17 >             DISPLAY "ERROR"
    ----               ^
      18             END-MULTIPLY.
      19             STOP RUN.
    (line 16, character 12):
    Basic (56 entries):
        ACCEPT
        ADD
        ALLOCATE
        ALTER
        CALL
        CANCEL
        CLOSE
        COMPUTE
        CONTINUE
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        ENTER
        ENTRY
        EVALUATE
        EXIT
        FREE
        GENERATE
        GO
        GOBACK
        IF
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        MERGE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        OPEN
        PERFORM
        PURGE
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REWRITE
        SEARCH
        SEND
        SET
        SORT
        START
        STOP
        STRING
        SUBTRACT
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNLOCK
        UNSTRING
        VALIDATE
        WRITE
    Eager (56 entries):
        ACCEPT
        ADD
        ALLOCATE
        ALTER
        CALL
        CANCEL
        CLOSE
        COMPUTE
        CONTINUE
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        ENTER
        ENTRY
        EVALUATE
        EXIT
        FREE
        GENERATE
        GO
        GOBACK
        IF
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        MERGE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        OPEN
        PERFORM
        PURGE
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REWRITE
        SEARCH
        SEND
        SET
        SORT
        START
        STOP
        STRING
        SUBTRACT
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNLOCK
        UNSTRING
        VALIDATE
        WRITE
    __rootdir__/prog.cob:18.10:
      15             MULTIPLY AA BY BB ROUNDED MODE IS TRUNCATION
      16               ON SIZE ERROR
      17               DISPLAY "ERROR"
      18 >           END-MULTIPLY.
    ----             ^
      19             STOP RUN.
      20
    (line 17, character 10):
    Basic (104 entries):
        AA
        BB
        ACCEPT
        ADD
        ADDRESS
        ALL
        ALLOCATE
        ALTER
        AT
        BACKGROUND-COLOR
        BELL
        BLANK
        BLINK
        CALL
        CANCEL
        CLOSE
        COL
        COLUMN
        COMPUTE
        CONTINUE
        CONTROL
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END-DISPLAY
        END-MULTIPLY
        ENTER
        ENTRY
        ERASE
        EVALUATE
        EXCEPTION
        EXCEPTION-OBJECT
        EXIT
        FOREGROUND-COLOR
        FREE
        FUNCTION
        GENERATE
        GO
        GOBACK
        GRID
        HIGHLIGHT
        HIGH-VALUES
        IF
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        LEFTLINE
        LINAGE-COUNTER
        LINE
        LINE-COUNTER
        LOWLIGHT
        LOW-VALUES
        MERGE
        MODE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        NOT ON EXCEPTION
        NOT ON SIZE ERROR
        NULL
        ON EXCEPTION
        OPEN
        OVERLINE
        PAGE-COUNTER
        PERFORM
        .\n
        POSITION
        PURGE
        QUOTES
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REVERSE-VIDEO
        REWRITE
        SEARCH
        SELF
        SEND
        SET
        SIZE
        SORT
        SPACES
        START
        STOP
        STRING
        SUBTRACT
        SUPER
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNDERLINE
        UNLOCK
        UNSTRING
        UPON
        VALIDATE
        WITH
        WITH NO ADVANCING
        WRITE
        ZEROS
    Eager (104 entries):
        AA
        BB
        ACCEPT
        ADD
        ADDRESS OF
        ALL
        ALLOCATE
        ALTER
        AT
        BACKGROUND-COLOR
        BELL
        BLANK
        BLINK
        CALL
        CANCEL
        CLOSE
        COL
        COLUMN
        COMPUTE
        CONTINUE
        CONTROL
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END-DISPLAY
        END-MULTIPLY
        ENTER
        ENTRY
        ERASE
        EVALUATE
        EXCEPTION
        EXCEPTION-OBJECT
        EXIT
        FOREGROUND-COLOR
        FREE
        FUNCTION
        GENERATE
        GO
        GOBACK
        GRID
        HIGHLIGHT
        HIGH-VALUES
        IF
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        LEFTLINE
        LINAGE-COUNTER
        LINE
        LINE-COUNTER
        LOWLIGHT
        LOW-VALUES
        MERGE
        MODE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        NOT ON EXCEPTION
        NOT ON SIZE ERROR
        NULL
        ON EXCEPTION
        OPEN
        OVERLINE
        PAGE-COUNTER
        PERFORM
        .\n
        POSITION
        PURGE
        QUOTES
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REVERSE-VIDEO
        REWRITE
        SEARCH
        SELF
        SEND
        SET
        SIZE
        SORT
        SPACES
        START
        STOP
        STRING
        SUBTRACT
        SUPER
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNDERLINE
        UNLOCK
        UNSTRING
        UPON
        VALIDATE
        WITH
        WITH NO ADVANCING
        WRITE
        ZEROS |}];;

let%expect_test "control-completion" =
  let end_with_postproc = completion_positions @@ extract_position_markers {cobol|
        CONTROL DIVISION.
        _|_DEFAULT _|_SECTION.
          _|_ACCEPT _|_TERMINAL
          _|_DISPLAY IS TERMINAL.
        _|_IDENTIFICATION DIVISION.
        PROGRAM-ID. prog.
        PROCEDURE DIVISION.
          STOP RUN.
  |cobol}  in
  end_with_postproc [%expect.output];
  [%expect {|
    {"params":{"diagnostics":[],"uri":"file://__rootdir__/prog.cob"},"method":"textDocument/publishDiagnostics","jsonrpc":"2.0"}
    __rootdir__/prog.cob:3.8:
       1
       2           CONTROL DIVISION.
       3 >         DEFAULT SECTION.
    ----           ^
       4             ACCEPT TERMINAL
       5             DISPLAY IS TERMINAL.
    (line 2, character 8):
    Basic (7 entries):
        CLASS-ID
        DEFAULT
        FUNCTION-ID
        ID
        IDENTIFICATION
        INTERFACE-ID
        PROGRAM-ID
    Eager (7 entries):
        CLASS-ID.\n
        DEFAULT SECTION.\n
        FUNCTION-ID
        ID DIVISION.\n
        IDENTIFICATION DIVISION.\n
        INTERFACE-ID.\n
        PROGRAM-ID
    __rootdir__/prog.cob:3.16:
       1
       2           CONTROL DIVISION.
       3 >         DEFAULT SECTION.
    ----                   ^
       4             ACCEPT TERMINAL
       5             DISPLAY IS TERMINAL.
    (line 2, character 16):
    Basic (1 entries): SECTION.\n
    Eager (1 entries): SECTION.\n
    __rootdir__/prog.cob:4.10:
       1
       2           CONTROL DIVISION.
       3           DEFAULT SECTION.
       4 >           ACCEPT TERMINAL
    ----             ^
       5             DISPLAY IS TERMINAL.
       6           IDENTIFICATION DIVISION.
    (line 3, character 10):
    Basic (9 entries):
        ACCEPT
        CLASS-ID
        DISPLAY
        FUNCTION-ID
        ID
        IDENTIFICATION
        INTERFACE-ID
        .\n
        PROGRAM-ID
    Eager (9 entries):
        ACCEPT
        CLASS-ID.\n
        DISPLAY
        FUNCTION-ID
        ID DIVISION.\n
        IDENTIFICATION DIVISION.\n
        INTERFACE-ID.\n
        .\n
        PROGRAM-ID
    __rootdir__/prog.cob:4.17:
       1
       2           CONTROL DIVISION.
       3           DEFAULT SECTION.
       4 >           ACCEPT TERMINAL
    ----                    ^
       5             DISPLAY IS TERMINAL.
       6           IDENTIFICATION DIVISION.
    (line 3, character 17):
    Basic (2 entries): IS TERMINAL
    Eager (2 entries): IS TERMINAL
    __rootdir__/prog.cob:5.10:
       2           CONTROL DIVISION.
       3           DEFAULT SECTION.
       4             ACCEPT TERMINAL
       5 >           DISPLAY IS TERMINAL.
    ----             ^
       6           IDENTIFICATION DIVISION.
       7           PROGRAM-ID. prog.
    (line 4, character 10):
    Basic (2 entries): DISPLAY .\n
    Eager (2 entries): DISPLAY .\n
    __rootdir__/prog.cob:6.8:
       3           DEFAULT SECTION.
       4             ACCEPT TERMINAL
       5             DISPLAY IS TERMINAL.
       6 >         IDENTIFICATION DIVISION.
    ----           ^
       7           PROGRAM-ID. prog.
       8           PROCEDURE DIVISION.
    (line 5, character 8):
    Basic (6 entries):
        CLASS-ID
        FUNCTION-ID
        ID
        IDENTIFICATION
        INTERFACE-ID
        PROGRAM-ID
    Eager (6 entries):
        CLASS-ID.\n
        FUNCTION-ID
        ID DIVISION.\n
        IDENTIFICATION DIVISION.\n
        INTERFACE-ID.\n
        PROGRAM-ID |}];;

let%expect_test "intrinsic-completion" =
  let end_with_postproc = completion_positions @@ extract_position_markers {cobol|
        IDENTIFICATION DIVISION.
        PROGRAM-ID. prog.
        ENVIRONMENT DIVISION.
        CONFIGURATION SECTION.
        REPOSITORY.
        FUNCTION _|_ABS _|_INTRINSIC.
        PROCEDURE DIVISION.
          DISPLAY _|_FUNCTION _|_ABS _|_(1)
          STOP RUN.
  |cobol}  in
  end_with_postproc [%expect.output];
  [%expect {|
    {"params":{"diagnostics":[],"uri":"file://__rootdir__/prog.cob"},"method":"textDocument/publishDiagnostics","jsonrpc":"2.0"}
    __rootdir__/prog.cob:7.17:
       4           ENVIRONMENT DIVISION.
       5           CONFIGURATION SECTION.
       6           REPOSITORY.
       7 >         FUNCTION ABS INTRINSIC.
    ----                    ^
       8           PROCEDURE DIVISION.
       9             DISPLAY FUNCTION ABS (1)
    (line 6, character 17):
    Basic (117 entries):
        BYTE-LENGTH
        CHAR
        CONTENT-OF
        CONVERT
        CURRENT-DATE
        FORMATTED-DATETIME
        FORMATTED-TIME
        LENGTH
        LOCALE-DATE
        LOCALE-TIME-FROM-SECONDS
        LOCALE-TIME
        NUMVAL-C
        RANDOM
        RANGE
        REVERSE
        SIGN
        SUM
        TRIM
        WHEN-COMPILED
        YEAR-TO-YYYY
        VARIANCE
        UPPER-CASE
        TEST-NUMVAL-F
        TEST-NUMVAL-C
        TEST-NUMVAL
        TEST-FORMATTED-DATETIME
        TEST-DAY-YYYYDDD
        TEST-DATE-YYYYMMDD
        TAN
        SUBSTITUTE-CASE
        SUBSTITUTE
        STORED-CHAR-LENGTH
        STANDARD-DEVIATION
        STANDARD-COMPARE
        SQRT
        SIN
        SECONDS-PAST-MIDNIGHT
        SECONDS-FROM-FORMATTED-TIME
        REM
        PRESENT-VALUE
        PI
        ORD-MIN
        ORD-MAX
        ORD
        NUMVAL-F
        NUMVAL
        NUMERIC-THOUSANDS-SEPARATOR
        NUMERIC-DECIMAL-POINT
        NATIONAL-OF
        MONETARY-THOUSANDS-SEPARATOR
        MONETARY-DECIMAL-POINT
        MODULE-TIME
        MODULE-SOURCE
        MODULE-PATH
        MODULE-NAME
        MODULE-ID
        MODULE-FORMATTED-DATE
        MODULE-DATE
        MODULE-CALLER-ID
        MOD
        MIN
        MIDRANGE
        MEDIAN
        MEAN
        MAX
        LOWEST-ALGEBRAIC
        LOWER-CASE
        LOG10
        LOG
        LOCALE-COMPARE
        LENGTH-AN
        INTEGER-PART
        INTEGER-OF-FORMATTED-DATE
        INTEGER-OF-DAY
        INTEGER-OF-DATE
        INTEGER-OF-BOOLEAN
        INTEGER
        HIGHEST-ALGEBRAIC
        HEX-TO-CHAR
        HEX-OF
        FRACTION-PART
        FORMATTED-DATE
        FORMATTED-CURRENT-DATE
        FIND-STRING
        FACTORIAL
        EXP10
        EXP
        EXCEPTION-STATUS
        EXCEPTION-STATEMENT
        EXCEPTION-LOCATION-N
        EXCEPTION-LOCATION
        EXCEPTION-FILE-N
        EXCEPTION-FILE
        E
        DISPLAY-OF
        DAY-TO-YYYYDDD
        DAY-OF-INTEGER
        DATE-TO-YYYYMMDD
        DATE-OF-INTEGER
        CURRENCY-SYMBOL
        COS
        CONTENT-LENGTH
        CONCATENATE
        CONCAT
        COMBINED-DATETIME
        CHAR-NATIONAL
        BOOLEAN-OF-INTEGER
        BIT-TO-CHAR
        BIT-OF
        BASECONVERT
        ATAN
        ASIN
        ANNUITY
        ACOS
        ABSOLUTE-VALUE
        ABS
        ALL INTRINSIC
    Eager (117 entries):
        BYTE-LENGTH
        CHAR
        CONTENT-OF
        CONVERT
        CURRENT-DATE
        FORMATTED-DATETIME
        FORMATTED-TIME
        LENGTH
        LOCALE-DATE
        LOCALE-TIME-FROM-SECONDS
        LOCALE-TIME
        NUMVAL-C
        RANDOM
        RANGE
        REVERSE
        SIGN
        SUM
        TRIM
        WHEN-COMPILED
        YEAR-TO-YYYY
        VARIANCE
        UPPER-CASE
        TEST-NUMVAL-F
        TEST-NUMVAL-C
        TEST-NUMVAL
        TEST-FORMATTED-DATETIME
        TEST-DAY-YYYYDDD
        TEST-DATE-YYYYMMDD
        TAN
        SUBSTITUTE-CASE
        SUBSTITUTE
        STORED-CHAR-LENGTH
        STANDARD-DEVIATION
        STANDARD-COMPARE
        SQRT
        SIN
        SECONDS-PAST-MIDNIGHT
        SECONDS-FROM-FORMATTED-TIME
        REM
        PRESENT-VALUE
        PI
        ORD-MIN
        ORD-MAX
        ORD
        NUMVAL-F
        NUMVAL
        NUMERIC-THOUSANDS-SEPARATOR
        NUMERIC-DECIMAL-POINT
        NATIONAL-OF
        MONETARY-THOUSANDS-SEPARATOR
        MONETARY-DECIMAL-POINT
        MODULE-TIME
        MODULE-SOURCE
        MODULE-PATH
        MODULE-NAME
        MODULE-ID
        MODULE-FORMATTED-DATE
        MODULE-DATE
        MODULE-CALLER-ID
        MOD
        MIN
        MIDRANGE
        MEDIAN
        MEAN
        MAX
        LOWEST-ALGEBRAIC
        LOWER-CASE
        LOG10
        LOG
        LOCALE-COMPARE
        LENGTH-AN
        INTEGER-PART
        INTEGER-OF-FORMATTED-DATE
        INTEGER-OF-DAY
        INTEGER-OF-DATE
        INTEGER-OF-BOOLEAN
        INTEGER
        HIGHEST-ALGEBRAIC
        HEX-TO-CHAR
        HEX-OF
        FRACTION-PART
        FORMATTED-DATE
        FORMATTED-CURRENT-DATE
        FIND-STRING
        FACTORIAL
        EXP10
        EXP
        EXCEPTION-STATUS
        EXCEPTION-STATEMENT
        EXCEPTION-LOCATION-N
        EXCEPTION-LOCATION
        EXCEPTION-FILE-N
        EXCEPTION-FILE
        E
        DISPLAY-OF
        DAY-TO-YYYYDDD
        DAY-OF-INTEGER
        DATE-TO-YYYYMMDD
        DATE-OF-INTEGER
        CURRENCY-SYMBOL
        COS
        CONTENT-LENGTH
        CONCATENATE
        CONCAT
        COMBINED-DATETIME
        CHAR-NATIONAL
        BOOLEAN-OF-INTEGER
        BIT-TO-CHAR
        BIT-OF
        BASECONVERT
        ATAN
        ASIN
        ANNUITY
        ACOS
        ABSOLUTE-VALUE
        ABS
        ALL INTRINSIC
    __rootdir__/prog.cob:7.21:
       4           ENVIRONMENT DIVISION.
       5           CONFIGURATION SECTION.
       6           REPOSITORY.
       7 >         FUNCTION ABS INTRINSIC.
    ----                        ^
       8           PROCEDURE DIVISION.
       9             DISPLAY FUNCTION ABS (1)
    (line 6, character 21):
    Basic (124 entries):
        BYTE-LENGTH
        CHAR
        CONTENT-OF
        CONVERT
        CURRENT-DATE
        FORMATTED-DATETIME
        FORMATTED-TIME
        LENGTH
        LOCALE-DATE
        LOCALE-TIME-FROM-SECONDS
        LOCALE-TIME
        NUMVAL-C
        RANDOM
        RANGE
        REVERSE
        SIGN
        SUM
        TRIM
        WHEN-COMPILED
        YEAR-TO-YYYY
        VARIANCE
        UPPER-CASE
        TEST-NUMVAL-F
        TEST-NUMVAL-C
        TEST-NUMVAL
        TEST-FORMATTED-DATETIME
        TEST-DAY-YYYYDDD
        TEST-DATE-YYYYMMDD
        TAN
        SUBSTITUTE-CASE
        SUBSTITUTE
        STORED-CHAR-LENGTH
        STANDARD-DEVIATION
        STANDARD-COMPARE
        SQRT
        SIN
        SECONDS-PAST-MIDNIGHT
        SECONDS-FROM-FORMATTED-TIME
        REM
        PRESENT-VALUE
        PI
        ORD-MIN
        ORD-MAX
        ORD
        NUMVAL-F
        NUMVAL
        NUMERIC-THOUSANDS-SEPARATOR
        NUMERIC-DECIMAL-POINT
        NATIONAL-OF
        MONETARY-THOUSANDS-SEPARATOR
        MONETARY-DECIMAL-POINT
        MODULE-TIME
        MODULE-SOURCE
        MODULE-PATH
        MODULE-NAME
        MODULE-ID
        MODULE-FORMATTED-DATE
        MODULE-DATE
        MODULE-CALLER-ID
        MOD
        MIN
        MIDRANGE
        MEDIAN
        MEAN
        MAX
        LOWEST-ALGEBRAIC
        LOWER-CASE
        LOG10
        LOG
        LOCALE-COMPARE
        LENGTH-AN
        INTEGER-PART
        INTEGER-OF-FORMATTED-DATE
        INTEGER-OF-DAY
        INTEGER-OF-DATE
        INTEGER-OF-BOOLEAN
        INTEGER
        HIGHEST-ALGEBRAIC
        HEX-TO-CHAR
        HEX-OF
        FRACTION-PART
        FORMATTED-DATE
        FORMATTED-CURRENT-DATE
        FIND-STRING
        FACTORIAL
        EXP10
        EXP
        EXCEPTION-STATUS
        EXCEPTION-STATEMENT
        EXCEPTION-LOCATION-N
        EXCEPTION-LOCATION
        EXCEPTION-FILE-N
        EXCEPTION-FILE
        E
        DISPLAY-OF
        DAY-TO-YYYYDDD
        DAY-OF-INTEGER
        DATE-TO-YYYYMMDD
        DATE-OF-INTEGER
        CURRENCY-SYMBOL
        COS
        CONTENT-LENGTH
        CONCATENATE
        CONCAT
        COMBINED-DATETIME
        CHAR-NATIONAL
        BOOLEAN-OF-INTEGER
        BIT-TO-CHAR
        BIT-OF
        BASECONVERT
        ATAN
        ASIN
        ANNUITY
        ACOS
        ABSOLUTE-VALUE
        ABS
        AS
        CLASS
        FUNCTION
        INTERFACE
        INTRINSIC
        .\n
        PROGRAM
        PROPERTY
    Eager (124 entries):
        BYTE-LENGTH
        CHAR
        CONTENT-OF
        CONVERT
        CURRENT-DATE
        FORMATTED-DATETIME
        FORMATTED-TIME
        LENGTH
        LOCALE-DATE
        LOCALE-TIME-FROM-SECONDS
        LOCALE-TIME
        NUMVAL-C
        RANDOM
        RANGE
        REVERSE
        SIGN
        SUM
        TRIM
        WHEN-COMPILED
        YEAR-TO-YYYY
        VARIANCE
        UPPER-CASE
        TEST-NUMVAL-F
        TEST-NUMVAL-C
        TEST-NUMVAL
        TEST-FORMATTED-DATETIME
        TEST-DAY-YYYYDDD
        TEST-DATE-YYYYMMDD
        TAN
        SUBSTITUTE-CASE
        SUBSTITUTE
        STORED-CHAR-LENGTH
        STANDARD-DEVIATION
        STANDARD-COMPARE
        SQRT
        SIN
        SECONDS-PAST-MIDNIGHT
        SECONDS-FROM-FORMATTED-TIME
        REM
        PRESENT-VALUE
        PI
        ORD-MIN
        ORD-MAX
        ORD
        NUMVAL-F
        NUMVAL
        NUMERIC-THOUSANDS-SEPARATOR
        NUMERIC-DECIMAL-POINT
        NATIONAL-OF
        MONETARY-THOUSANDS-SEPARATOR
        MONETARY-DECIMAL-POINT
        MODULE-TIME
        MODULE-SOURCE
        MODULE-PATH
        MODULE-NAME
        MODULE-ID
        MODULE-FORMATTED-DATE
        MODULE-DATE
        MODULE-CALLER-ID
        MOD
        MIN
        MIDRANGE
        MEDIAN
        MEAN
        MAX
        LOWEST-ALGEBRAIC
        LOWER-CASE
        LOG10
        LOG
        LOCALE-COMPARE
        LENGTH-AN
        INTEGER-PART
        INTEGER-OF-FORMATTED-DATE
        INTEGER-OF-DAY
        INTEGER-OF-DATE
        INTEGER-OF-BOOLEAN
        INTEGER
        HIGHEST-ALGEBRAIC
        HEX-TO-CHAR
        HEX-OF
        FRACTION-PART
        FORMATTED-DATE
        FORMATTED-CURRENT-DATE
        FIND-STRING
        FACTORIAL
        EXP10
        EXP
        EXCEPTION-STATUS
        EXCEPTION-STATEMENT
        EXCEPTION-LOCATION-N
        EXCEPTION-LOCATION
        EXCEPTION-FILE-N
        EXCEPTION-FILE
        E
        DISPLAY-OF
        DAY-TO-YYYYDDD
        DAY-OF-INTEGER
        DATE-TO-YYYYMMDD
        DATE-OF-INTEGER
        CURRENCY-SYMBOL
        COS
        CONTENT-LENGTH
        CONCATENATE
        CONCAT
        COMBINED-DATETIME
        CHAR-NATIONAL
        BOOLEAN-OF-INTEGER
        BIT-TO-CHAR
        BIT-OF
        BASECONVERT
        ATAN
        ASIN
        ANNUITY
        ACOS
        ABSOLUTE-VALUE
        ABS
        AS
        CLASS
        FUNCTION
        INTERFACE
        INTRINSIC
        .\n
        PROGRAM
        PROPERTY
    __rootdir__/prog.cob:9.18:
       6           REPOSITORY.
       7           FUNCTION ABS INTRINSIC.
       8           PROCEDURE DIVISION.
       9 >           DISPLAY FUNCTION ABS (1)
    ----                     ^
      10             STOP RUN.
      11
    (line 8, character 18):
    Basic (15 entries):
        ADDRESS
        ALL
        EXCEPTION-OBJECT
        FUNCTION
        HIGH-VALUES
        LINAGE-COUNTER
        LINE-COUNTER
        LOW-VALUES
        NULL
        PAGE-COUNTER
        QUOTES
        SELF
        SPACES
        SUPER
        ZEROS
    Eager (15 entries):
        ADDRESS OF
        ALL
        EXCEPTION-OBJECT
        FUNCTION
        HIGH-VALUES
        LINAGE-COUNTER
        LINE-COUNTER
        LOW-VALUES
        NULL
        PAGE-COUNTER
        QUOTES
        SELF
        SPACES
        SUPER
        ZEROS
    __rootdir__/prog.cob:9.27:
       6           REPOSITORY.
       7           FUNCTION ABS INTRINSIC.
       8           PROCEDURE DIVISION.
       9 >           DISPLAY FUNCTION ABS (1)
    ----                              ^
      10             STOP RUN.
      11
    (line 8, character 27):
    Basic (116 entries):
        BYTE-LENGTH
        CHAR
        CONTENT-OF
        CONVERT
        CURRENT-DATE
        FORMATTED-DATETIME
        FORMATTED-TIME
        LENGTH
        LOCALE-DATE
        LOCALE-TIME-FROM-SECONDS
        LOCALE-TIME
        NUMVAL-C
        RANDOM
        RANGE
        REVERSE
        SIGN
        SUM
        TRIM
        WHEN-COMPILED
        YEAR-TO-YYYY
        VARIANCE
        UPPER-CASE
        TEST-NUMVAL-F
        TEST-NUMVAL-C
        TEST-NUMVAL
        TEST-FORMATTED-DATETIME
        TEST-DAY-YYYYDDD
        TEST-DATE-YYYYMMDD
        TAN
        SUBSTITUTE-CASE
        SUBSTITUTE
        STORED-CHAR-LENGTH
        STANDARD-DEVIATION
        STANDARD-COMPARE
        SQRT
        SIN
        SECONDS-PAST-MIDNIGHT
        SECONDS-FROM-FORMATTED-TIME
        REM
        PRESENT-VALUE
        PI
        ORD-MIN
        ORD-MAX
        ORD
        NUMVAL-F
        NUMVAL
        NUMERIC-THOUSANDS-SEPARATOR
        NUMERIC-DECIMAL-POINT
        NATIONAL-OF
        MONETARY-THOUSANDS-SEPARATOR
        MONETARY-DECIMAL-POINT
        MODULE-TIME
        MODULE-SOURCE
        MODULE-PATH
        MODULE-NAME
        MODULE-ID
        MODULE-FORMATTED-DATE
        MODULE-DATE
        MODULE-CALLER-ID
        MOD
        MIN
        MIDRANGE
        MEDIAN
        MEAN
        MAX
        LOWEST-ALGEBRAIC
        LOWER-CASE
        LOG10
        LOG
        LOCALE-COMPARE
        LENGTH-AN
        INTEGER-PART
        INTEGER-OF-FORMATTED-DATE
        INTEGER-OF-DAY
        INTEGER-OF-DATE
        INTEGER-OF-BOOLEAN
        INTEGER
        HIGHEST-ALGEBRAIC
        HEX-TO-CHAR
        HEX-OF
        FRACTION-PART
        FORMATTED-DATE
        FORMATTED-CURRENT-DATE
        FIND-STRING
        FACTORIAL
        EXP10
        EXP
        EXCEPTION-STATUS
        EXCEPTION-STATEMENT
        EXCEPTION-LOCATION-N
        EXCEPTION-LOCATION
        EXCEPTION-FILE-N
        EXCEPTION-FILE
        E
        DISPLAY-OF
        DAY-TO-YYYYDDD
        DAY-OF-INTEGER
        DATE-TO-YYYYMMDD
        DATE-OF-INTEGER
        CURRENCY-SYMBOL
        COS
        CONTENT-LENGTH
        CONCATENATE
        CONCAT
        COMBINED-DATETIME
        CHAR-NATIONAL
        BOOLEAN-OF-INTEGER
        BIT-TO-CHAR
        BIT-OF
        BASECONVERT
        ATAN
        ASIN
        ANNUITY
        ACOS
        ABSOLUTE-VALUE
        ABS
    Eager (116 entries):
        BYTE-LENGTH
        CHAR
        CONTENT-OF
        CONVERT
        CURRENT-DATE
        FORMATTED-DATETIME
        FORMATTED-TIME
        LENGTH
        LOCALE-DATE
        LOCALE-TIME-FROM-SECONDS
        LOCALE-TIME
        NUMVAL-C
        RANDOM
        RANGE
        REVERSE
        SIGN
        SUM
        TRIM
        WHEN-COMPILED
        YEAR-TO-YYYY
        VARIANCE
        UPPER-CASE
        TEST-NUMVAL-F
        TEST-NUMVAL-C
        TEST-NUMVAL
        TEST-FORMATTED-DATETIME
        TEST-DAY-YYYYDDD
        TEST-DATE-YYYYMMDD
        TAN
        SUBSTITUTE-CASE
        SUBSTITUTE
        STORED-CHAR-LENGTH
        STANDARD-DEVIATION
        STANDARD-COMPARE
        SQRT
        SIN
        SECONDS-PAST-MIDNIGHT
        SECONDS-FROM-FORMATTED-TIME
        REM
        PRESENT-VALUE
        PI
        ORD-MIN
        ORD-MAX
        ORD
        NUMVAL-F
        NUMVAL
        NUMERIC-THOUSANDS-SEPARATOR
        NUMERIC-DECIMAL-POINT
        NATIONAL-OF
        MONETARY-THOUSANDS-SEPARATOR
        MONETARY-DECIMAL-POINT
        MODULE-TIME
        MODULE-SOURCE
        MODULE-PATH
        MODULE-NAME
        MODULE-ID
        MODULE-FORMATTED-DATE
        MODULE-DATE
        MODULE-CALLER-ID
        MOD
        MIN
        MIDRANGE
        MEDIAN
        MEAN
        MAX
        LOWEST-ALGEBRAIC
        LOWER-CASE
        LOG10
        LOG
        LOCALE-COMPARE
        LENGTH-AN
        INTEGER-PART
        INTEGER-OF-FORMATTED-DATE
        INTEGER-OF-DAY
        INTEGER-OF-DATE
        INTEGER-OF-BOOLEAN
        INTEGER
        HIGHEST-ALGEBRAIC
        HEX-TO-CHAR
        HEX-OF
        FRACTION-PART
        FORMATTED-DATE
        FORMATTED-CURRENT-DATE
        FIND-STRING
        FACTORIAL
        EXP10
        EXP
        EXCEPTION-STATUS
        EXCEPTION-STATEMENT
        EXCEPTION-LOCATION-N
        EXCEPTION-LOCATION
        EXCEPTION-FILE-N
        EXCEPTION-FILE
        E
        DISPLAY-OF
        DAY-TO-YYYYDDD
        DAY-OF-INTEGER
        DATE-TO-YYYYMMDD
        DATE-OF-INTEGER
        CURRENCY-SYMBOL
        COS
        CONTENT-LENGTH
        CONCATENATE
        CONCAT
        COMBINED-DATETIME
        CHAR-NATIONAL
        BOOLEAN-OF-INTEGER
        BIT-TO-CHAR
        BIT-OF
        BASECONVERT
        ATAN
        ASIN
        ANNUITY
        ACOS
        ABSOLUTE-VALUE
        ABS
    __rootdir__/prog.cob:9.31:
       6           REPOSITORY.
       7           FUNCTION ABS INTRINSIC.
       8           PROCEDURE DIVISION.
       9 >           DISPLAY FUNCTION ABS (1)
    ----                                  ^
      10             STOP RUN.
      11
    (line 8, character 31):
    Basic (103 entries):
        ACCEPT
        ADD
        ADDRESS
        ALL
        ALLOCATE
        ALTER
        AS FACTORY OF
        AS UNIVERSAL
        AS
        AT
        BACKGROUND-COLOR
        BELL
        BLANK
        BLINK
        CALL
        CANCEL
        CLOSE
        COL
        COLUMN
        COMPUTE
        CONTINUE
        CONTROL
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END-DISPLAY
        ENTER
        ENTRY
        ERASE
        EVALUATE
        EXCEPTION
        EXCEPTION-OBJECT
        EXIT
        FOREGROUND-COLOR
        FREE
        FUNCTION
        GENERATE
        GO
        GOBACK
        GRID
        HIGHLIGHT
        HIGH-VALUES
        IF
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        LEFTLINE
        LINAGE-COUNTER
        LINE
        LINE-COUNTER
        LOWLIGHT
        LOW-VALUES
        MERGE
        MODE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        NOT ON EXCEPTION
        NULL
        ON EXCEPTION
        OPEN
        OVERLINE
        PAGE-COUNTER
        PERFORM
        .\n
        POSITION
        PURGE
        QUOTES
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REVERSE-VIDEO
        REWRITE
        SEARCH
        SELF
        SEND
        SET
        SIZE
        SORT
        SPACES
        START
        STOP
        STRING
        SUBTRACT
        SUPER
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNDERLINE
        UNLOCK
        UNSTRING
        UPON
        VALIDATE
        WITH
        WITH NO ADVANCING
        WRITE
        ZEROS
    Eager (101 entries):
        ACCEPT
        ADD
        ADDRESS OF
        ALL
        ALLOCATE
        ALTER
        AS
        AT
        BACKGROUND-COLOR
        BELL
        BLANK
        BLINK
        CALL
        CANCEL
        CLOSE
        COL
        COLUMN
        COMPUTE
        CONTINUE
        CONTROL
        DELETE
        DISABLE
        DISPLAY
        DIVIDE
        ENABLE
        END-DISPLAY
        ENTER
        ENTRY
        ERASE
        EVALUATE
        EXCEPTION
        EXCEPTION-OBJECT
        EXIT
        FOREGROUND-COLOR
        FREE
        FUNCTION
        GENERATE
        GO
        GOBACK
        GRID
        HIGHLIGHT
        HIGH-VALUES
        IF
        INITIALIZE
        INITIATE
        INSPECT
        INVOKE
        LEFTLINE
        LINAGE-COUNTER
        LINE
        LINE-COUNTER
        LOWLIGHT
        LOW-VALUES
        MERGE
        MODE
        MOVE
        MULTIPLY
        NEXT SENTENCE
        NOT ON EXCEPTION
        NULL
        ON EXCEPTION
        OPEN
        OVERLINE
        PAGE-COUNTER
        PERFORM
        .\n
        POSITION
        PURGE
        QUOTES
        RAISE
        READ
        RECEIVE
        RELEASE
        RESUME
        RETURN
        REVERSE-VIDEO
        REWRITE
        SEARCH
        SELF
        SEND
        SET
        SIZE
        SORT
        SPACES
        START
        STOP
        STRING
        SUBTRACT
        SUPER
        SUPPRESS
        TERMINATE
        TRANSFORM
        UNDERLINE
        UNLOCK
        UNSTRING
        UPON
        VALIDATE
        WITH
        WITH NO ADVANCING
        WRITE
        ZEROS |}];;
