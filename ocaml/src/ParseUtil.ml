(*
 * Copyright 2015-2016 IBM Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *)

(* This module contains parsing utilities *)

open Util
open LexUtil
open Compiler.EnhancedCompiler


(*****************)
(* Generic Parse *)
(*****************)

let parse parser lexer buf =
    try
      parser lexer buf
    with
    | LexError msg ->
	begin
	  let pos = buf.Lexing.lex_start_p in
	  let msg = Printf.sprintf "At line %d column %d: %s%!" pos.Lexing.pos_lnum (pos.Lexing.pos_cnum - pos.Lexing.pos_bol) msg in
	  raise (LexError msg)
	end
    | _ ->
	begin
	  let pos = buf.Lexing.lex_start_p in
	  let msg = Printf.sprintf "At line %d column %d: syntax error%!" pos.Lexing.pos_lnum (pos.Lexing.pos_cnum - pos.Lexing.pos_bol) in
	  raise (LexError msg)
	end



(******************)
(* Specific Parse *)
(******************)


let parse_io f : Data.json = parse DataParser.main (DataLexer.token (string_buff ())) f
let parse_json f : Data.json = parse DataParser.main (DataLexer.token (string_buff ())) f

let parse_rule f : string * CompDriver.query = parse RuleParser.rulemain (RuleLexer.token (string_buff ())) f
let parse_camp f : CompDriver.camp = parse RuleParser.patmain (RuleLexer.token (string_buff ())) f
  
let parse_oql f : CompDriver.oql = OQL.tableify (parse OQLParser.main (OQLLexer.token (string_buff ())) f)

let parse_lambda_nra f : CompDriver.lambda_nra = LambdaNRA.latableify (parse LambdaNRAParser.main (LambdaNRALexer.token (string_buff ())) f)

(****************)
(* S-Expr Parse *)
(****************)

let parse_sexp f : SExp.sexp = parse SExpParser.main (SExpLexer.token (string_buff ())) f
let parse_io_sexp f : Data.data = AstsToSExp.sexp_to_data (parse_sexp f)
let parse_camp_sexp f : CompDriver.camp = AstsToSExp.sexp_to_camp (parse_sexp f)
let parse_nraenv_sexp f : CompDriver.nraenv = AstsToSExp.sexp_to_nraenv (parse_sexp f)
let parse_nnrc_sexp f : CompDriver.nnrc = AstsToSExp.sexp_to_nnrc (parse_sexp f)
let parse_nnrcmr_sexp f : CompDriver.nnrcmr = AstsToSExp.sexp_to_nnrcmr (parse_sexp f)
let parse_cldmr_sexp f : CompDriver.cldmr = AstsToSExp.sexp_to_cldmr (parse_sexp f)

(*******************
 * Languages Parse *
 *******************)

let parse_query l f : (string * CompDriver.query) =
  begin match l with
  | Compiler.Coq__23.L_rule -> parse_rule f
  | Compiler.Coq__23.L_camp -> ("CAMP", Compiler.Coq__24.Q_camp (parse_camp f))
  | Compiler.Coq__23.L_oql -> ("OQL", Compiler.Coq__24.Q_oql (parse_oql f))
  | Compiler.Coq__23.L_lambda_nra -> ("LambdaNRA", Compiler.Coq__24.Q_lambda_nra (parse_lambda_nra f))
  | Compiler.Coq__23.L_nra -> raise (CACo_Error "No parser for NRA available")
  | Compiler.Coq__23.L_nraenv -> ("NRAEnv", Compiler.Coq__24.Q_nraenv (parse_nraenv_sexp f))
  | Compiler.Coq__23.L_nnrc -> ("NNRC", Compiler.Coq__24.Q_nnrc (parse_nnrc_sexp f))
  | Compiler.Coq__23.L_nnrcmr -> ("NNRCMR", Compiler.Coq__24.Q_nnrcmr (parse_nnrcmr_sexp f))
  | Compiler.Coq__23.L_cldmr -> ("CldMR", Compiler.Coq__24.Q_cldmr (parse_cldmr_sexp f))
  | Compiler.Coq__23.L_dnnrc_dataset -> raise (CACo_Error "No parser for DNNRC available")
  | Compiler.Coq__23.L_dnnrc_typed_dataset -> raise (CACo_Error "No parser for typed DNNRC available")
  | Compiler.Coq__23.L_javascript -> raise (CACo_Error "No parser for Javascript available")
  | Compiler.Coq__23.L_java -> raise (CACo_Error "No parser for Java available")
  | Compiler.Coq__23.L_spark -> raise (CACo_Error "No parser for Spark available")
  | Compiler.Coq__23.L_spark2 -> raise (CACo_Error "No parser for Spark 2.0 available")
  | Compiler.Coq__23.L_cloudant -> raise (CACo_Error "No parser for Cloudant available")
  | Compiler.Coq__23.L_error err ->
      let err = string_of_char_list err in
      raise (CACo_Error ("No parser for Error language available: "^err))
  end
