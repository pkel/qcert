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

Section CompLang.

  Require Import String.
  Require Import NRARuntime.
  Require Import NRAEnvRuntime.
  Require Import NNRCRuntime.
  Require Import NNRCMRRuntime.
  Require Import CloudantMR.
  Require Import DNNRC Dataset.
  Require Import CAMPRuntime.
  Require Import ODMGRuntime.

  Require Import BasicSystem.

  Require Import NNRCMRtoDNNRC.
  Require Import TDNRCInfer.
  Require Import LambdaAlg.
  
  Require Rule.

  Definition vdbindings := vdbindings.

  (* Languages *)
  Context {ft:foreign_type}.
  Context {bm:brand_model}.

  Context {fr:foreign_runtime}.
  Context {fredop:foreign_reduce_op}.

  Definition rule := rule.
  Definition camp := pat.
  Definition oql := oql_expr.
  Definition lambda_nra := lalg.
  Definition nra := alg.
  Definition nraenv := algenv.
  Definition nnrc := nrc.
  Definition nnrcmr := nrcmr.
  Definition cldmr := cld_mrl.
  Definition dnnrc_dataset := dnrc _ unit dataset.
  Definition dnnrc_typed_dataset {bm:brand_model} := dnrc _ (type_annotation unit) dataset.
  Definition javascript := string.
  Definition java := string.
  Definition spark := string.
  Definition spark2 := string.
  Definition cloudant := (list (string * string) * (string * list string))%type.

  Inductive language : Set :=
    | L_rule : language
    | L_camp : language
    | L_oql : language
    | L_lambda_nra : language
    | L_nra : language
    | L_nraenv : language
    | L_nnrc : language
    | L_nnrcmr : language
    | L_cldmr : language
    | L_dnnrc_dataset : language
    | L_dnnrc_typed_dataset : language
    | L_javascript : language
    | L_java : language
    | L_spark : language
    | L_spark2 : language
    | L_cloudant : language
    | L_error : string -> language.

  Tactic Notation "language_cases" tactic(first) ident(c) :=
    first;
    [ Case_aux c "L_rule"%string
    | Case_aux c "L_camp"%string
    | Case_aux c "L_oql"%string
    | Case_aux c "L_lambda_nra"%string
    | Case_aux c "L_nra"%string
    | Case_aux c "L_nraenv"%string
    | Case_aux c "L_nnrc"%string
    | Case_aux c "L_nnrcmr"%string
    | Case_aux c "L_cldmr"%string
    | Case_aux c "L_dnnrc_dataset"%string
    | Case_aux c "L_dnnrc_typed_dataset"%string
    | Case_aux c "L_javascript"%string
    | Case_aux c "L_java"%string
    | Case_aux c "L_spark"%string
    | Case_aux c "L_spark2"%string
    | Case_aux c "L_cloudant"%string
    | Case_aux c "L_error"%string].


  Inductive query : Set :=
    | Q_rule : rule -> query
    | Q_camp : camp -> query
    | Q_oql : oql -> query
    | Q_lambda_nra : lambda_nra -> query
    | Q_nra : nra -> query
    | Q_nraenv : nraenv -> query
    | Q_nnrc : nnrc -> query
    | Q_nnrcmr : nnrcmr -> query
    | Q_cldmr : cldmr -> query
    | Q_dnnrc_dataset : dnnrc_dataset -> query
    | Q_dnnrc_typed_dataset : dnnrc_typed_dataset -> query
    | Q_javascript : javascript -> query
    | Q_java : java -> query
    | Q_spark : spark -> query
    | Q_spark2 : spark2 -> query
    | Q_cloudant : cloudant -> query
    | Q_error : string -> query.

  Tactic Notation "query_cases" tactic(first) ident(c) :=
    first;
    [ Case_aux c "Q_rule"%string
    | Case_aux c "Q_camp"%string
    | Case_aux c "Q_oql"%string
    | Case_aux c "Q_lambda_nra"%string
    | Case_aux c "Q_nra"%string
    | Case_aux c "Q_nraenv"%string
    | Case_aux c "Q_nnrc"%string
    | Case_aux c "Q_nnrcmr"%string
    | Case_aux c "Q_cldmr"%string
    | Case_aux c "Q_dnnrc_dataset"%string
    | Case_aux c "Q_dnnrc_typed_dataset"%string
    | Case_aux c "Q_javascript"%string
    | Case_aux c "Q_java"%string
    | Case_aux c "Q_spark"%string
    | Case_aux c "Q_spark2"%string
    | Case_aux c "Q_cloudant"%string
    | Case_aux c "Q_error"%string].

End CompLang.


(*
*** Local Variables: ***
*** coq-load-path: (("../../../coq" "QCert")) ***
*** End: ***
*)