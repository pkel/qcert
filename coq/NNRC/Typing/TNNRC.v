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

Section TNNRC.
  Require Import String.
  Require Import List.
  Require Import Arith.
  Require Import Program.
  Require Import EquivDec.
  Require Import Morphisms.
  Require Import Utils.
  Require Import CommonSystem.
  Require Import cNNRC.
  Require Import NNRC.
  Require Import TcNNRC.

  (** Typing rules for NNRC *)
  Section typ.
    Context {m:basic_model}.
    Context (τconstants:tbindings).

    Definition nnrc_type (env:tbindings) (n:nnrc) (t:rtype) : Prop :=
      nnrc_core_type τconstants env (nnrc_to_nnrc_base n) t.

    Section groupby.
    
      (* An explicit typing rule for groupby *)
      Lemma type_NNRCGroupBy {τl k pf} Γ g sl e :
        sublist sl (domain τl) ->
        nnrc_type Γ e (Coll (Rec k τl pf)) ->
        nnrc_type Γ (NNRCGroupBy g sl e) (GroupBy_type g sl k τl pf).
      Proof.
        unfold GroupBy_type, nnrc_type.
        simpl; intros subl typ.
        unfold nnrc_group_by.
        econstructor; try eassumption.
        repeat econstructor; trivial.
        Unshelve.
        - apply (is_list_sorted_sublist pf).
          apply sublist_domain.
          apply sublist_rproject.
        - simpl; trivial.
      Qed.

      (* And an explicit typing rule inversion principle for groupby *)
      (* note that additional constraint, since otherwise the grouped elements will
          be ignored, which allows more freedom in the typing 
       *)
      Lemma type_NNRCGroupBy_inv {τl k pf} Γ g sl e :
        nnrc_type Γ (NNRCGroupBy g sl e) (GroupBy_type g sl k τl pf) ->
        ~ In g sl ->
        sublist sl (domain τl) /\ nnrc_type Γ e (Coll (Rec k τl pf)).
      Proof.
        Opaque rec_sort.
        unfold GroupBy_type, nnrc_type; simpl.
        unfold nnrc_group_by; intros typ nin.
        invcs typ.
        invcs H5.
        invcs H2.
        invcs H8.
        invcs H9.
        invcs H3; rtype_equalizer; subst.
        simpl in H1; invcs H1.
        invcs H10.
        invcs H2.
        invcs H5.
        simpl in H2; invcs H2.
        invcs H7.
        invcs H5.
        invcs H10.
        simpl in H2.
        invcs H2.
        rtype_equalizer; subst.
        invcs H9.
        invcs H3.
        destruct τ₁0; simpl in H; try discriminate.
        destruct τ₁0; simpl in H; try discriminate.
        invcs H.
        rtype_equalizer; subst.
        invcs H7.
        invcs H3.
        destruct p; simpl in *; subst.
        invcs H8.
        apply Coll_right_inv in H7; subst.
        invcs H3; simpl in H2; invcs H2.
        invcs H9.
        invcs H11.
        clear H3.
        invcs H10.
        invcs H5; rtype_equalizer; subst.
        invcs H9.
        simpl in H3; invcs H3.
        invcs H7.
        invcs H11.
        simpl in H3; invcs H3.
        invcs H8.
        invcs H10.
        invcs H5.
        rtype_equalizer.
        invcs H8.
        simpl in H5; invcs H5.
        simpl in *.
        invcs H1.
        invcs H6.
        rtype_equalizer; subst.
        unfold rec_concat_sort in H1; simpl in H1.
        apply rec_sort_cons_nin_inv in H1.
        - destruct H1 as [eqq1 eqq2].
          invcs eqq1.
          rtype_equalizer; subst.
          split; trivial.
          erewrite Rec_pr_irrel; try eassumption.
        - rewrite <- rproject_domain_in; tauto.
        - rewrite <- rproject_domain_in; tauto.
        Transparent rec_sort.
      Qed.
      
    End groupby.

  End typ.

  (** Main lemma for the type correctness of NNNRC *)

  Theorem typed_nnrc_yields_typed_data {m:basic_model} {τcenv} {τ} (cenv env:bindings) (tenv:tbindings) (e:nnrc) :
    bindings_type cenv τcenv ->
    bindings_type env tenv ->
    nnrc_type τcenv tenv e τ ->
    (exists x, (@nnrc_eval _ brand_relation_brands cenv env e) = Some x /\ (data_type x τ)).
  Proof.
    intros.
    unfold nnrc_eval.
    unfold nnrc_type in H1.
    apply (@typed_nnrc_core_yields_typed_data _ τcenv _ cenv env tenv).
    assumption.
    assumption.
    assumption.
  Qed.

  (* we are only sensitive to the environment up to lookup *)
  Global Instance nnrc_type_lookup_equiv_prop {m:basic_model} :
    Proper (eq ==> lookup_equiv ==> eq ==> eq ==> iff) nnrc_type.
  Proof.
    generalize nnrc_core_type_lookup_equiv_prop; intro Hnnrc_prop.
    unfold Proper, respectful, lookup_equiv, iff, impl in *; intros; subst.
    apply Hnnrc_prop; try reflexivity;
      try assumption.
  Qed.

End TNNRC.

Ltac nnrc_inverter :=
  unfold nnrc_type, nnrc_to_nnrc_base in *; simpl in *; try nnrc_core_inverter.

Ltac nnrc_input_well_typed :=
  repeat progress
         match goal with
         | [HO:nnrc_type ?Γc ?Γ ?op ?τout,
               HE:bindings_type ?env ?Γ
            |- context [(nnrc_eval brand_relation_brands ?cenv ?env ?op)]] =>
           let xout := fresh "dout" in
           let xtype := fresh "τout" in
           let xeval := fresh "eout" in
           destruct (typed_nnrc_yields_typed_data env Γ op HE HO)
             as [xout [xeval xtype]]; rewrite xeval in *; simpl
         end.

