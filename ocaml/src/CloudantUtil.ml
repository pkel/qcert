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

(* Some Cloudant Utils *)

open Util
open Compiler.EnhancedCompiler

(* Javascript harness (for inlining in Cloudant) *)

let print_hierarchy d =
  Util.string_of_char_list (QData.dataToJS (Util.char_list_of_string "\"") (QData.json_to_data [] d))

let fix_harness harness h =
  let harness = "var inheritance = %INHERITANCE%;\n" ^ harness in
  let hs =
    try print_hierarchy h with
    | _ -> "[]"
  in
  let harness_with_inh = Util.global_replace "%INHERITANCE%" hs harness in
  let s1 = Util.global_replace "\t" " " harness_with_inh in
  let s2 = Util.global_replace "\"" "\\\"" s1 in
  let s3 = Util.global_replace Util.os_newline "\\n" s2 in
  s3

(* Cloudant stuff *)

let add_harness harness h s =
  Util.global_replace "%HARNESS%" (fix_harness harness h) s
    
let add_harness_to_designdoc harness h design_doc =
  let designdoc = string_of_char_list design_doc.Compiler.cloudant_design_doc in
  let harnessed_designdoc = add_harness harness h designdoc in
  { Compiler.cloudant_design_inputdb = design_doc.Compiler.cloudant_design_inputdb;
    Compiler.cloudant_design_name = design_doc.Compiler.cloudant_design_name;
    Compiler.cloudant_design_doc = char_list_of_string harnessed_designdoc; }
    
let stringify_designdoc design_doc =
  let dbname = string_of_char_list design_doc.Compiler.cloudant_design_inputdb in
  let designdoc = string_of_char_list design_doc.Compiler.cloudant_design_doc in
  (dbname, designdoc)

(* Java equivalent: CloudantBackend.makeOneDesign *)
let makeOneDesign (db,dd) : string =
  "{ \"dbname\": \"" ^ db ^ "\",\n  \"design\":\ " ^ dd ^ " }"

(* Java equivalent: CloudantBackend.makeOneInput *)
let makeOneInput (input:char list) =
  "\"" ^ (Util.string_of_char_list input) ^ "\""

(* Java equivalent: CloudantBackend.makeLastInputs *)
let makeLastInputs (last_inputs:char list list) =
  "[ " ^ (String.concat ", " (List.map makeOneInput last_inputs)) ^ " ]"

(* Java equivalent: CloudantBackend.makeTopCld *)
let makeTopCld dbs last last_inputs : string =
  "{ \"designs\": " ^ dbs ^ ",\n  \"post\":\ \"" ^ last ^ "\",\n \"post_input\":\ " ^ (makeLastInputs last_inputs) ^ " }"

(* Java equivalent: CloudantBackend.fold_design *)
let fold_design (dds:(string * string) list) (last_expr:string) (last_inputs: char list list) : string =
  makeTopCld
    ("[ " ^ (String.concat ",\n" (List.map makeOneDesign dds)) ^ " ]")
    last_expr
    last_inputs

(* Important functions *)

let add_harness_top harness h (cloudant: QLang.cloudant) : QLang.cloudant =
  let design_docs = cloudant.Compiler.cloudant_designs in
  let last_expr = cloudant.Compiler.cloudant_final_expr in
  let last_inputs = cloudant.Compiler.cloudant_effective_parameters in
  let harnessed_design_docs =
    List.map (fun doc -> (add_harness_to_designdoc harness h) doc) design_docs
  in
  let harnessed_last_expr =
    add_harness harness h (Util.string_of_char_list last_expr)
  in
  { Compiler.cloudant_designs = harnessed_design_docs;
    Compiler.cloudant_final_expr = Util.char_list_of_string harnessed_last_expr;
    Compiler.cloudant_effective_parameters = last_inputs }

let string_of_cloudant cloudant =
  let design_docs = cloudant.Compiler.cloudant_designs in
  let last_expr = cloudant.Compiler.cloudant_final_expr in
  let last_inputs = cloudant.Compiler.cloudant_effective_parameters in
  fold_design (List.map stringify_designdoc design_docs) (Util.string_of_char_list last_expr) last_inputs

