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

(** NNRSimp is a variant of the named nested relational calculus
     (NNRC) that is meant to be more imperative in feel.  It is used
     as an intermediate language between NNRC and more imperative /
     statement oriented backends *)

Require Import String.
Require Import List.
Require Import Arith.
Require Import EquivDec.
Require Import Morphisms.
Require Import Arith.
Require Import ZArith.
Require Import Max.
Require Import Bool.
Require Import Peano_dec.
Require Import EquivDec.
Require Import Decidable.
Require Import Utils.
Require Import BrandRelation.
Require Import EJsonRuntime.
Require Import Imp.
Require Import ImpEval.
Require Import ImpEJson.

Section ImpEJsonEval.
  Context {fejson:foreign_ejson}.
  (* XXX We should try and compile the hierarchy in. Currenty it is still used in cast for sub-branding check *)
  Context (h:brand_relation_t).

  Local Open Scope string.

  Section EvalInstantiation.
    (* Instantiate Imp for Qcert data *)
    Definition imp_ejson_data_normalize (d:imp_ejson_data) : imp_ejson_data := d.

    Definition imp_ejson_data_to_bool (d:imp_ejson_data) : option bool :=
      match d with
      | ejbool b => Some b
      | _ => None
      end.

    Definition imp_ejson_data_to_list (d:imp_ejson_data) : option (list imp_ejson_data) :=
      match d with
      | ejarray c => Some (c)
      | _ => None
      end.

    Definition imp_ejson_data_to_Z (d:imp_ejson_data) : option Z :=
      match d with
      | ejbigint n => Some n
      | _ => None
      end.

    Definition imp_ejson_Z_to_data (n: Z) : imp_ejson_data := ejbigint n.

    Definition imp_ejson_runtime_eval (rt:imp_ejson_runtime_op) (dl:list imp_ejson_data) : option imp_ejson_data :=
      match rt with
      (* Generic *)
      | EJsonRuntimeEqual =>
        apply_binary (fun d1 d2 => if ejson_eq_dec d1 d2 then Some (ejbool true) else Some (ejbool false)) dl
      | EJsonRuntimeCompare =>
        apply_binary
          (fun d1 d2 =>
             match d1, d2 with
             | ejnumber n1, ejnumber n2 =>
               if float_lt n1 n2
               then
                 Some (ejnumber float_one)
               else if float_gt n1 n2
                    then
                      Some (ejnumber float_neg_one)
                    else
                      Some (ejnumber float_zero)
             | ejbigint n1, ejbigint n2 =>
               if Z_lt_dec n1 n2
               then
                 Some (ejnumber float_one)
               else if Z_gt_dec n1 n2
                    then
                      Some (ejnumber float_neg_one)
                    else
                      Some (ejnumber float_zero)
             | _, _ => None
             end) dl
      | EJsonRuntimeToString => None
      | EJsonRuntimeToText => None
      (* Record *)
      | EJsonRuntimeRecConcat =>
        apply_binary
          (fun d1 d2 =>
             match d1, d2 with
             | (ejobject r1), (ejobject r2) => Some (ejobject (rec_sort (r1++r2)))
             | _, _ => None
             end) dl
      | EJsonRuntimeRecMerge =>
        apply_binary
          (fun d1 d2 =>
             match d1, d2 with
             | (ejobject r1), (ejobject r2) =>
               match @merge_bindings ejson _ ejson_eq_dec r1 r2 with
               | Some x => Some (ejarray ((ejobject x) :: nil))
               | None => Some (ejarray nil)
               end
             | _, _ => None
             end) dl
      | EJsonRuntimeRecRemove =>
        apply_binary
          (fun d1 d2 =>
             match ejson_is_record d1 with
             | Some r =>
               match d2 with
               | ejstring s =>
                 Some (ejobject (rremove r s))
               | _ => None
               end
             | _ => None
             end) dl
      | EJsonRuntimeRecProject =>
        apply_binary
          (fun d1 d2 =>
             match ejson_is_record d1 with
             | Some r =>
               match d2 with
               | ejarray sl =>
                 lift ejobject
                      (lift (rproject r)
                            (of_string_list sl))
               | _ => None
               end
             | _ => None
             end) dl
      | EJsonRuntimeRecDot =>
        apply_binary
          (fun d1 d2 =>
             match ejson_is_record d1 with
             | Some r =>
               match d2 with
               | ejstring s =>
                 edot r s
               | _ => None
               end
             | _ => None
             end) dl
      (* Sums *)
      | EJsonRuntimeEither =>
        apply_unary
          (fun d =>
             match d with
             | ejobject (("$left", _)::nil) => Some (ejbool true)
             | ejobject (("$right",_)::nil) => Some (ejbool false)
             | _ => None
             end) dl
      | EJsonRuntimeToLeft =>
        apply_unary
          (fun d =>
             match d with
             | ejobject (("$left", d)::nil) => Some d
             | _ => None
             end) dl
      | EJsonRuntimeToRight =>
        apply_unary
          (fun d =>
             match d with
             | ejobject (("$right", d)::nil) => Some d
             | _ => None
             end) dl
      (* Brand *)
      | EJsonRuntimeBrand =>
        apply_binary
          (fun d1 d2 =>
             match d1 with
             | ejarray bls =>
               let ob := of_string_list bls in
               lift (fun b =>
                       ejobject
                         (("$class"%string, ejarray (map ejstring b))
                            ::("$data"%string, d2)
                            ::nil)) ob
             | _ => None
             end
          ) dl
      | EJsonRuntimeUnbrand =>
        apply_unary
          (fun d =>
             match d with
             | ejobject ((s,ejarray jl)::(s',j')::nil) =>
               if (string_dec s "$class") then
                 if (string_dec s' "$data") then
                   match ejson_brands jl with
                   | Some _ => Some j'
                   | None => None
                   end
                 else None
               else None
             | _ => None
             end) dl
      | EJsonRuntimeCast =>
        apply_binary
          (fun d1 d2 : ejson =>
             match d1 with
             | ejarray jl1 =>
               match ejson_brands jl1 with
               | Some b1 =>
                 match d2 with
                 | ejobject ((s,ejarray jl2)::(s',_)::nil) =>
                   if (string_dec s "$class") then
                     if (string_dec s' "$data") then
                       match ejson_brands jl2 with
                       | Some b2 =>
                         if (sub_brands_dec h b2 b1)
                         then
                           Some (ejobject (("$left"%string,d2)::nil))
                         else
                           Some (ejobject (("$right"%string,ejnull)::nil))
                       | None => None
                       end
                     else None
                   else None
                 | _ => None
                 end
               | None => None
               end
             | _ => None
             end) dl

      (* Collections *)
      | EJsonRuntimeDistinct =>
        apply_unary
          (fun d =>
             match d with
             | ejarray l =>
               Some (ejarray (@bdistinct ejson ejson_eq_dec l))
             | _ => None
             end)
          dl
      | EJsonRuntimeSingleton =>
        apply_unary
          (fun d =>
             match d with
             | ejarray (d::nil) => Some (ejobject (("$left",d)::nil))
             | ejarray _ => Some (ejobject (("$right",ejnull)::nil))
             | _ => None
             end) dl
      | EJsonRuntimeFlatten =>
        apply_unary
          (fun d =>
             match d with
             | ejarray l =>
               lift ejarray (jflatten l)
             | _ => None
             end) dl
      | EJsonRuntimeUnion =>
        apply_binary
          (fun d1 d2 =>
             match d1, d2 with
             | ejarray l1, ejarray l2 =>
               Some (ejarray (bunion l1 l2))
             | _, _ => None
             end
          ) dl
      | EJsonRuntimeMinus =>
        apply_binary
          (fun d1 d2 =>
             match d1, d2 with
             | ejarray l1, ejarray l2 =>
               Some (ejarray (bminus l1 l2))
             | _, _ => None
             end
          ) dl
      | EJsonRuntimeMin =>
        apply_binary
          (fun d1 d2 =>
             match d1, d2 with
             | ejarray l1, ejarray l2 =>
               Some (ejarray (bmin l1 l2))
             | _, _ => None
             end
          ) dl
      | EJsonRuntimeMax =>
        apply_binary
          (fun d1 d2 =>
             match d1, d2 with
             | ejarray l1, ejarray l2 =>
               Some (ejarray (bmax l1 l2))
             | _, _ => None
             end
          ) dl
      | EJsonRuntimeNth => None (* XXX TODO *)
      | EJsonRuntimeCount =>
        apply_unary
          (fun d =>
             match d with
             | ejarray l => Some (ejbigint (Z_of_nat (bcount l)))
             | _ => None
             end) dl
      | EJsonRuntimeContains => None (* XXX TODO *)
      | EJsonRuntimeSort => None (* XXX TODO *)
      | EJsonRuntimeGroupBy => None (* XXX TODO *)
      (* String *)
      | EJsonRuntimeLength =>
        apply_unary
          (fun d =>
             match d with
             | ejstring s => Some (ejbigint (Z_of_nat (String.length s)))
             | _ => None
             end) dl
      | EJsonRuntimeSubstring =>
        apply_ternary
          (fun d1 d2 d3 =>
             match d1, d2, d3 with
             | ejstring s, ejbigint start, ejbigint len =>              
               let real_start :=
                   (match start with
                    | 0%Z => 0
                    | Z.pos p => Pos.to_nat p
                    | Z.neg n => (String.length s) - (Pos.to_nat n)
                    end) in
               let real_len :=
                   match len with
                   | 0%Z => 0
                   | Z.pos p => Pos.to_nat p
                   | Z.neg n => 0
                   end
               in
               Some (ejstring (substring real_start real_len s))
             | _, _, _ => None
             end) dl
      | EJsonRuntimeSubstringEnd =>
        apply_binary
          (fun d1 d2 =>
             match d1, d2 with
             | ejstring s, ejbigint start =>              
               let real_start :=
                   (match start with
                    | 0%Z => 0
                    | Z.pos p => Pos.to_nat p
                    | Z.neg n => (String.length s) - (Pos.to_nat n)
                    end) in
               let real_len := (String.length s) - real_start in
               Some (ejstring (substring real_start real_len s))
             | _, _ => None
             end) dl
      | EJsonRuntimeStringJoin =>
        apply_binary
          (fun d1 d2 =>
             match d1, d2 with
             | ejstring sep, ejarray l =>
               match ejson_strings l with
               | Some sl => Some (ejstring (String.concat sep sl))
               | None => None
               end
             | _, _ => None
             end
          ) dl
      | EJsonRuntimeLike =>
        apply_binary
          (fun d1 d2 =>
             match d1, d2 with
             | ejstring sreg, ejstring starget =>
               Some (ejbool (string_like starget sreg None))
             | _, _ => None
             end
          ) dl
      (* Integer *)
      | EJsonRuntimeNatPlus =>
        apply_binary
          (fun d1 d2 =>
             match d1, d2 with
             | ejbigint n1, ejbigint n2 =>
               Some (ejbigint (Z.add n1 n2))
             | _, _ => None
             end
          ) dl
      | EJsonRuntimeNatMinus =>
        apply_binary
          (fun d1 d2 =>
             match d1, d2 with
             | ejbigint n1, ejbigint n2 =>
               Some (ejbigint (Z.sub n1 n2))
             | _, _ => None
             end
          ) dl
      | EJsonRuntimeNatMult =>
        apply_binary
          (fun d1 d2 =>
             match d1, d2 with
             | ejbigint n1, ejbigint n2 =>
               Some (ejbigint (Z.mul n1 n2))
             | _, _ => None
             end
          ) dl
      | EJsonRuntimeNatDiv =>
        apply_binary
          (fun d1 d2 =>
             match d1, d2 with
             | ejbigint n1, ejbigint n2 =>
               Some (ejbigint (Z.quot n1 n2))
             | _, _ => None
             end
          ) dl
      | EJsonRuntimeNatRem =>
        apply_binary
          (fun d1 d2 =>
             match d1, d2 with
             | ejbigint n1, ejbigint n2 =>
               Some (ejbigint (Z.rem n1 n2))
             | _, _ => None
             end
          ) dl
      | EJsonRuntimeNatAbs =>
        apply_unary
          (fun d =>
             match d with
             | ejbigint z => Some (ejbigint (Z.abs z))
             | _ => None
             end) dl
      | EJsonRuntimeNatLog2 =>
        apply_unary
          (fun d =>
             match d with
             | ejbigint z => Some (ejbigint (Z.log2 z))
             | _ => None
             end) dl
      | EJsonRuntimeNatSqrt =>
        apply_unary
          (fun d =>
             match d with
             | ejbigint z => Some (ejbigint (Z.sqrt z))
             | _ => None
             end) dl
      | EJsonRuntimeNatMinPair =>
        apply_binary
          (fun d1 d2 =>
             match d1, d2 with
             | ejbigint n1, ejbigint n2 =>
               Some (ejbigint (Z.min n1 n2))
             | _, _ => None
             end
          ) dl
      | EJsonRuntimeNatMaxPair =>
        apply_binary
          (fun d1 d2 =>
             match d1, d2 with
             | ejbigint n1, ejbigint n2 =>
               Some (ejbigint (Z.max n1 n2))
             | _, _ => None
             end
          ) dl
      | EJsonRuntimeNatSum =>
        apply_unary
          (fun d =>
             match d with
             | ejarray l =>
               match ejson_bigints l with
               | Some zl =>
                 Some (ejbigint (fold_right Zplus 0%Z zl))
               | None => None
               end
             | _ => None
             end) dl
      | EJsonRuntimeNatMin =>
        apply_unary
          (fun d =>
             match d with
             | ejarray l =>
               match ejson_bigints l with
               | Some zl =>
                 Some (ejbigint (bnummin zl))
               | None => None
               end
             | _ => None
             end) dl
      | EJsonRuntimeNatMax =>
        apply_unary
          (fun d =>
             match d with
             | ejarray l =>
               match ejson_bigints l with
               | Some zl =>
                 Some (ejbigint (bnummax zl))
               | None => None
               end
             | _ => None
             end) dl
      | EJsonRuntimeNatArithMean =>
        apply_unary
          (fun d =>
             match d with
             | ejarray l =>
               let length := List.length l in
               match ejson_bigints l with
               | Some zl =>
                 Some (ejbigint (Z.quot (fold_right Zplus 0%Z zl) (Z_of_nat length)))
               | None => None
               end
             | _ => None
             end) dl
      | EJsonRuntimeFloatOfNat =>
        apply_unary
          (fun d =>
             match d with
             | ejbigint n => Some (ejnumber (float_of_int n))
             | _ => None
             end) dl
      | EJsonRuntimeFloatSum =>
        apply_unary
          (fun d =>
             match d with
             | ejarray l =>
               match ejson_numbers l with
               | Some nl =>
                 Some (ejnumber (float_list_sum nl))
               | None => None
               end
             | _ => None
             end) dl
      | EJsonRuntimeFloatArithMean =>
        apply_unary
          (fun d =>
             match d with
             | ejarray l =>
               match ejson_numbers l with
               | Some nl =>
                 Some (ejnumber (float_list_arithmean nl))
               | None => None
               end
             | _ => None
             end) dl
      end.
    
    Definition imp_ejson_op_eval (op:imp_ejson_op) (dl:list imp_ejson_data) : option imp_ejson_data :=
      ejson_op_eval op dl. (* XXX In Common.EJson.EJsonOperators *)

  End EvalInstantiation.

  (** ** Evaluation Semantics *)
  Section Evaluation.

    (** Evaluation takes a ImpQcert expression and an environment. It
          returns an optional value. When [None] is returned, it
          denotes an error. An error is always propagated. *)

    Definition jbindings := list (string * imp_ejson_data).
    Definition pd_jbindings := list (string * option imp_ejson_data).

    Definition imp_ejson_expr_eval
               (σ:pd_jbindings) (e:imp_ejson_expr)
      : option imp_ejson_data
      := @imp_expr_eval
           imp_ejson_data
           imp_ejson_op
           imp_ejson_runtime_op
           imp_ejson_data_normalize
           imp_ejson_runtime_eval
           imp_ejson_op_eval
           σ e.

    Definition imp_ejson_decls_eval
               (σ:pd_jbindings) (el:list (string * option imp_ejson_expr))
      : option pd_jbindings
      := @imp_decls_eval
           imp_ejson_data
           imp_ejson_op
           imp_ejson_runtime_op
           imp_ejson_data_normalize
           imp_ejson_runtime_eval
           imp_ejson_op_eval
           σ el.

    Definition imp_ejson_decls_erase
               (σ:option pd_jbindings) (el:list (string * option imp_ejson_expr))
      : option pd_jbindings
      := imp_decls_erase σ el.

    Definition imp_ejson_stmt_eval
             (s:imp_ejson_stmt) (σ:pd_jbindings) : option (pd_jbindings)
      := @imp_stmt_eval
           imp_ejson_data
           imp_ejson_op
           imp_ejson_runtime_op
           imp_ejson_data_normalize
           imp_ejson_data_to_bool
           imp_ejson_data_to_Z
           imp_ejson_data_to_list
           imp_ejson_Z_to_data
           imp_ejson_runtime_eval
           imp_ejson_op_eval
           s σ.

    Definition imp_ejson_function_eval
             (f:imp_ejson_function) args : option imp_ejson_data
      := @imp_function_eval
           imp_ejson_data
           imp_ejson_op
           imp_ejson_runtime_op
           imp_ejson_data_normalize
           imp_ejson_data_to_bool
           imp_ejson_data_to_Z
           imp_ejson_data_to_list
           imp_ejson_Z_to_data
           imp_ejson_runtime_eval
           imp_ejson_op_eval
           f args.

    Import ListNotations.
    Definition imp_ejson_eval (q:imp_ejson) (d:imp_ejson_data) : option (option imp_ejson_data)
      := @imp_eval
           imp_ejson_data
           imp_ejson_op
           imp_ejson_runtime_op
           imp_ejson_data_normalize
           imp_ejson_data_to_bool
           imp_ejson_data_to_Z
           imp_ejson_data_to_list
           imp_ejson_Z_to_data
           imp_ejson_runtime_eval
           imp_ejson_op_eval
           q d.

    Definition imp_ejson_eval_top_on_ejson σc (q:imp_ejson) : option imp_ejson_data :=
      let σc' := List.map (fun xy => (json_key_encode (fst xy), snd xy)) (rec_sort σc) in
      olift id (imp_ejson_eval q (ejobject σc')).

  End Evaluation.

End ImpEJsonEval.

Require Import DataRuntime.
Require Import ForeignDataToEJson.
Require Import DatatoEJson.
Section Top.
  Context {fruntime:foreign_runtime}.
  Context {fdatatoejson:foreign_to_ejson}.
  (* XXX We should try and compile the hierarchy in. Currenty it is still used in cast for sub-branding check *)
  Context (h:brand_relation_t).
  Definition imp_ejson_eval_top (cenv: bindings) (q:imp_ejson) : option data :=
    let jenv := List.map (fun xy => (fst xy, data_to_ejson(snd xy))) cenv in
    lift ejson_to_data (imp_ejson_eval_top_on_ejson h jenv q).
End Top.
(* Arguments imp_stmt_eval_domain_stack {fruntime h s σc σ₁ σ₂}. *)