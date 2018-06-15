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

(* Cross Shadowing is when a variable in one namespace "shadows" 
   a variable in another namespace.  This is not a problem for nnrc_impish, since 
   the namespaces are all distinct.  However, it poses a problem when compiling to
   a language like nnrc_imp that has a single namespace.
 *)

Require Import String.
Require Import List.
Require Import Permutation.
Require Import ListSet.
Require Import Arith.
Require Import EquivDec.
Require Import Morphisms.
Require Import Arith.
Require Import Max.
Require Import Bool.
Require Import Peano_dec.
Require Import EquivDec.
Require Import Decidable.
Require Import Utils.
Require Import CommonRuntime.
Require Import NNRCimpish.
Require Import NNRCimpishEval.
Require Import NNRCimpishVars.
Require Import NNRCimpishRename.

Section NNRCimpishCrossShadow.
  
  Context {fruntime:foreign_runtime}.

  Local Open Scope nnrc_impish.

  (** The definition of the cross shadow free predicate.  This definition is used by
       the impish->imp translation.  If it holds, then collapsing namespaces is safe.
   *)
  Section def.
    
    Fixpoint nnrc_impish_stmt_cross_shadow_free_under
             (s:nnrc_impish_stmt)
             (σ ψc ψd:list var)
    : Prop
      := match s with
         | NNRCimpishSeq s₁ s₂ =>
           nnrc_impish_stmt_cross_shadow_free_under s₁ σ ψc ψd
           /\ nnrc_impish_stmt_cross_shadow_free_under s₂ σ ψc ψd
         | NNRCimpishLet v e s₀ =>
           disjoint (nnrc_impish_expr_free_vars e) ψc
           /\ disjoint (nnrc_impish_expr_free_vars e) ψd
           (* not the same: incl (nnrc_impish_expr_free_vars e) σ *)
           /\ ~ In v ψc
           /\ ~ In v ψd
           /\ nnrc_impish_stmt_cross_shadow_free_under s₀ (v::σ) ψc ψd
         | NNRCimpishLetMut v s₁ s₂ =>
           ~ In v σ
           /\ ~ In v ψc
           /\ ~ In v ψd      
           /\ nnrc_impish_stmt_cross_shadow_free_under s₁ σ ψc (v::ψd)
           /\ nnrc_impish_stmt_cross_shadow_free_under s₂ (v::σ) ψc ψd
         | NNRCimpishLetMutColl v s₁ s₂ =>
           ~ In v σ
           /\ ~ In v ψc
           /\ ~ In v ψd      
           /\ nnrc_impish_stmt_cross_shadow_free_under s₁ σ (v::ψc) ψd
           /\ nnrc_impish_stmt_cross_shadow_free_under s₂ (v::σ) ψc ψd
         | NNRCimpishAssign v e =>
           disjoint (nnrc_impish_expr_free_vars e) ψc
           /\ disjoint (nnrc_impish_expr_free_vars e) ψd
           /\ ~ In v σ
           /\ ~ In v ψc
         (* not the same: In v ψd *)
         | NNRCimpishPush v e =>
           disjoint (nnrc_impish_expr_free_vars e) ψc
           /\ disjoint (nnrc_impish_expr_free_vars e) ψd
           /\ ~ In v σ
           /\ ~ In v ψd
         (* not the same: In v ψc *)
         | NNRCimpishFor v e s₀ =>
           disjoint (nnrc_impish_expr_free_vars e) ψc
           /\ disjoint (nnrc_impish_expr_free_vars e) ψd
           (* not the same: incl (nnrc_impish_expr_free_vars e) σ *)          
           /\ ~ In v ψc
           /\ ~ In v ψd
           /\ nnrc_impish_stmt_cross_shadow_free_under s₀ (v::σ) ψc ψd
         | NNRCimpishIf e s₁ s₂ =>
           disjoint (nnrc_impish_expr_free_vars e) ψc
           /\ disjoint (nnrc_impish_expr_free_vars e) ψd
           (* not the same: incl (nnrc_impish_expr_free_vars e) σ *)
           /\ nnrc_impish_stmt_cross_shadow_free_under s₁ σ ψc ψd
           /\ nnrc_impish_stmt_cross_shadow_free_under s₂ σ ψc ψd
         | NNRCimpishEither e x₁ s₁ x₂ s₂ =>
           disjoint (nnrc_impish_expr_free_vars e) ψc
           /\ disjoint (nnrc_impish_expr_free_vars e) ψd
           (* not the same: incl (nnrc_impish_expr_free_vars e) σ *)
           /\ ~ In x₁ ψc
           /\ ~ In x₁ ψd
           /\ ~ In x₂ ψc
           /\ ~ In x₂ ψd
           /\ nnrc_impish_stmt_cross_shadow_free_under s₁ (x₁::σ) ψc ψd
           /\ nnrc_impish_stmt_cross_shadow_free_under s₂ (x₂::σ) ψc ψd
         end.

    Definition nnrc_impish_cross_shadow_free (s:nnrc_impish)
      := nnrc_impish_stmt_cross_shadow_free_under (fst s) nil nil (snd s::nil).

  End def.

  (** If the cross shadow predicate holds, then the environments in question 
      must obey certain disjointness conditions *)
  Section cross_shadow_free_disjointness.

    Lemma nnrc_impish_stmt_cross_shadow_free_under_free_mcenv_env
          (s:nnrc_impish_stmt) (σ ψc ψd:list var) :
      nnrc_impish_stmt_cross_shadow_free_under s σ ψc ψd ->
      disjoint (nnrc_impish_stmt_free_mcenv_vars s) σ.
    Proof.
      unfold disjoint.
      revert σ ψc ψd
      ; nnrc_impish_stmt_cases (induction s) Case
      ; simpl; intros σ ψc ψd sf x inn.
      - Case "NNRCimpishSeq"%string.
        rewrite in_app_iff in inn.
        intuition eauto.
      - Case "NNRCimpishLet"%string.
        intuition.
        eapply IHs; eauto; simpl; eauto.
      - Case "NNRCimpishLetMut"%string.
        rewrite in_app_iff in inn.
        intuition eauto.
        eapply IHs2; eauto; simpl; eauto.
      - Case "NNRCimpishLetMutColl"%string.
        rewrite in_app_iff in inn.
        intuition eauto.
        + apply remove_inv in H4.
          eapply IHs1; eauto; tauto.
        + eapply IHs2; eauto; simpl; eauto.
      - Case "NNRCimpishAssign"%string.
        contradiction.
      - Case "NNRCimpishPush"%string.
        intuition congruence.
      - Case "NNRCimpishFor"%string.
        intuition.
        eapply IHs; eauto; simpl; eauto.
      - Case "NNRCimpishIf"%string.
        repeat rewrite in_app_iff in inn.
        intuition eauto. 
      - Case "NNRCimpishEither"%string.
        repeat rewrite in_app_iff in inn.
        intuition.
        + eapply IHs1; eauto; simpl; eauto.
        + eapply IHs2; eauto; simpl; eauto.
    Qed.

    Lemma nnrc_impish_stmt_cross_shadow_free_under_free_mdenv_env
          (s:nnrc_impish_stmt) (σ ψc ψd:list var) :
      nnrc_impish_stmt_cross_shadow_free_under s σ ψc ψd ->
      disjoint (nnrc_impish_stmt_free_mdenv_vars s) σ.
    Proof.
      unfold disjoint.
      revert σ ψc ψd
      ; nnrc_impish_stmt_cases (induction s) Case
      ; simpl; intros σ ψc ψd sf x inn.
      - Case "NNRCimpishSeq"%string.
        rewrite in_app_iff in inn.
        intuition eauto.
      - Case "NNRCimpishLet"%string.
        intuition.
        eapply IHs; eauto; simpl; eauto.
      - Case "NNRCimpishLetMut"%string.
        rewrite in_app_iff in inn.
        intuition eauto.
        + apply remove_inv in H4.
          eapply IHs1; eauto; tauto.
        + eapply IHs2; eauto; simpl; eauto.
      - Case "NNRCimpishLetMutColl"%string.
        rewrite in_app_iff in inn.
        intuition eauto.
        eapply IHs2; eauto; simpl; eauto.
      - Case "NNRCimpishAssign"%string.
        intuition congruence.
      - Case "NNRCimpishPush"%string.
        contradiction.
      - Case "NNRCimpishFor"%string.
        intuition.
        eapply IHs; eauto; simpl; eauto.
      - Case "NNRCimpishIf"%string.
        repeat rewrite in_app_iff in inn.
        intuition eauto. 
      - Case "NNRCimpishEither"%string.
        repeat rewrite in_app_iff in inn.
        intuition.
        + eapply IHs1; eauto; simpl; eauto.
        + eapply IHs2; eauto; simpl; eauto.
    Qed.

    Lemma nnrc_impish_stmt_cross_shadow_free_under_free_env_mcenv
          (s:nnrc_impish_stmt) (σ ψc ψd:list var) :
      nnrc_impish_stmt_cross_shadow_free_under s σ ψc ψd ->
      disjoint (nnrc_impish_stmt_free_env_vars s) ψc.
    Proof.
      unfold disjoint.
      revert σ ψc ψd
      ; nnrc_impish_stmt_cases (induction s) Case
      ; simpl; intros σ ψc ψd sf x inn.
      - Case "NNRCimpishSeq"%string.
        rewrite in_app_iff in inn.
        intuition eauto.
      - Case "NNRCimpishLet"%string.
        rewrite in_app_iff in inn.
        intuition eauto.
        apply remove_inv in H4.
        eapply IHs; eauto; simpl; tauto.
      - Case "NNRCimpishLetMut"%string.
        rewrite in_app_iff in inn.
        intuition eauto.
        apply remove_inv in H4.
        eapply IHs2; eauto; simpl; tauto.
      - Case "NNRCimpishLetMutColl"%string.
        rewrite in_app_iff in inn.
        intuition eauto.
        + eapply IHs1; eauto; simpl; eauto. 
        + apply remove_inv in H4.
          eapply IHs2; eauto; tauto.
      - Case "NNRCimpishAssign"%string.
        intuition eauto.
      - Case "NNRCimpishPush"%string.
        intuition eauto.
      - Case "NNRCimpishFor"%string.
        rewrite in_app_iff in inn.
        intuition eauto.
        apply remove_inv in H4.
        eapply IHs; eauto; simpl; tauto.
      - Case "NNRCimpishIf"%string.
        repeat rewrite in_app_iff in inn.
        intuition eauto. 
      - Case "NNRCimpishEither"%string.
        repeat rewrite in_app_iff in inn.
        intuition.
        + eapply H0; eauto.
        + apply remove_inv in H9.
          eapply IHs1; eauto; tauto.
        + apply remove_inv in H9.
          eapply IHs2; eauto; tauto.
    Qed.

    Lemma nnrc_impish_stmt_cross_shadow_free_under_free_mdenv_mcenv
          (s:nnrc_impish_stmt) (σ ψc ψd:list var) :
      nnrc_impish_stmt_cross_shadow_free_under s σ ψc ψd ->
      disjoint (nnrc_impish_stmt_free_mdenv_vars s) ψc.
    Proof.
      unfold disjoint.
      revert σ ψc ψd
      ; nnrc_impish_stmt_cases (induction s) Case
      ; simpl; intros σ ψc ψd sf x inn.
      - Case "NNRCimpishSeq"%string.
        rewrite in_app_iff in inn.
        intuition eauto.
      - Case "NNRCimpishLet"%string.
        intuition.
        eapply IHs; eauto; simpl; eauto.
      - Case "NNRCimpishLetMut"%string.
        rewrite in_app_iff in inn.
        intuition eauto.
        apply remove_inv in H4.
        eapply IHs1; eauto; tauto.
      - Case "NNRCimpishLetMutColl"%string.
        rewrite in_app_iff in inn.
        intuition eauto.
        eapply IHs1; eauto; simpl; eauto.
      - Case "NNRCimpishAssign"%string.
        intuition congruence.
      - Case "NNRCimpishPush"%string.
        contradiction.
      - Case "NNRCimpishFor"%string.
        intuition.
        eapply IHs; eauto; simpl; eauto.
      - Case "NNRCimpishIf"%string.
        repeat rewrite in_app_iff in inn.
        intuition eauto. 
      - Case "NNRCimpishEither"%string.
        repeat rewrite in_app_iff in inn.
        intuition.
        + eapply IHs1; eauto; simpl; eauto.
        + eapply IHs2; eauto; simpl; eauto.
    Qed.

    Lemma nnrc_impish_stmt_cross_shadow_free_under_free_env_mdenv
          (s:nnrc_impish_stmt) (σ ψc ψd:list var) :
      nnrc_impish_stmt_cross_shadow_free_under s σ ψc ψd ->
      disjoint (nnrc_impish_stmt_free_env_vars s) ψd.
    Proof.
      unfold disjoint.
      revert σ ψc ψd
      ; nnrc_impish_stmt_cases (induction s) Case
      ; simpl; intros σ ψc ψd sf x inn.
      - Case "NNRCimpishSeq"%string.
        rewrite in_app_iff in inn.
        intuition eauto.
      - Case "NNRCimpishLet"%string.
        rewrite in_app_iff in inn.
        intuition eauto.
        apply remove_inv in H4.
        eapply IHs; eauto; simpl; tauto.
      - Case "NNRCimpishLetMut"%string.
        rewrite in_app_iff in inn.
        intuition eauto.
        + eapply IHs1; eauto; simpl; tauto.
        + apply remove_inv in H4.
          eapply IHs2; eauto; simpl; tauto.
      - Case "NNRCimpishLetMutColl"%string.
        rewrite in_app_iff in inn.
        intuition eauto.
        apply remove_inv in H4.
        eapply IHs2; eauto; tauto.
      - Case "NNRCimpishAssign"%string.
        intuition eauto.
      - Case "NNRCimpishPush"%string.
        intuition eauto.
      - Case "NNRCimpishFor"%string.
        rewrite in_app_iff in inn.
        intuition eauto.
        apply remove_inv in H4.
        eapply IHs; eauto; simpl; tauto.
      - Case "NNRCimpishIf"%string.
        repeat rewrite in_app_iff in inn.
        intuition eauto. 
      - Case "NNRCimpishEither"%string.
        repeat rewrite in_app_iff in inn.
        intuition.
        + eapply H2; eauto.
        + apply remove_inv in H9.
          eapply IHs1; eauto; tauto.
        + apply remove_inv in H9.
          eapply IHs2; eauto; tauto.
    Qed.

    Lemma nnrc_impish_stmt_cross_shadow_free_under_free_mcenv_mdenv
          (s:nnrc_impish_stmt) (σ ψc ψd:list var) :
      nnrc_impish_stmt_cross_shadow_free_under s σ ψc ψd ->
      disjoint (nnrc_impish_stmt_free_mcenv_vars s) ψd.
    Proof.
      unfold disjoint.
      revert σ ψc ψd
      ; nnrc_impish_stmt_cases (induction s) Case
      ; simpl; intros σ ψc ψd sf x inn.
      - Case "NNRCimpishSeq"%string.
        rewrite in_app_iff in inn.
        intuition eauto.
      - Case "NNRCimpishLet"%string.
        intuition.
        eapply IHs; eauto; simpl; eauto.
      - Case "NNRCimpishLetMut"%string.
        rewrite in_app_iff in inn.
        intuition eauto.
        eapply IHs1; eauto; simpl; tauto.
      - Case "NNRCimpishLetMutColl"%string.
        rewrite in_app_iff in inn.
        intuition eauto.
        apply remove_inv in H4.
        eapply IHs1; eauto; tauto.
      - Case "NNRCimpishAssign"%string.
        contradiction.
      - Case "NNRCimpishPush"%string.
        intuition congruence.
      - Case "NNRCimpishFor"%string.
        intuition.
        eapply IHs; eauto; simpl; eauto.
      - Case "NNRCimpishIf"%string.
        repeat rewrite in_app_iff in inn.
        intuition eauto. 
      - Case "NNRCimpishEither"%string.
        repeat rewrite in_app_iff in inn.
        intuition.
        + eapply IHs1; eauto; simpl; eauto.
        + eapply IHs2; eauto; simpl; eauto.
    Qed.
    
    Lemma nnrc_impish_stmt_cross_shadow_free_under_free_env_cons
          {s:nnrc_impish_stmt} {σ ψc ψd:list var} {v} :
      nnrc_impish_stmt_cross_shadow_free_under s (v::σ) ψc ψd ->
      ~ In v (nnrc_impish_stmt_free_mcenv_vars s) /\ ~ In v (nnrc_impish_stmt_free_mdenv_vars s).
    Proof.
      intros sf; split; intros inn.
      - eapply nnrc_impish_stmt_cross_shadow_free_under_free_mcenv_env; eauto
        ;  simpl; eauto.
      - eapply nnrc_impish_stmt_cross_shadow_free_under_free_mdenv_env; eauto
        ;  simpl; eauto.
    Qed.

    Lemma nnrc_impish_stmt_cross_shadow_free_under_free_mcenv_cons
          {s:nnrc_impish_stmt} {σ ψc ψd:list var} {v} :
      nnrc_impish_stmt_cross_shadow_free_under s σ (v::ψc) ψd ->
      ~ In v (nnrc_impish_stmt_free_env_vars s) /\ ~ In v (nnrc_impish_stmt_free_mdenv_vars s).
    Proof.
      intros sf; split; intros inn.
      - eapply nnrc_impish_stmt_cross_shadow_free_under_free_env_mcenv; eauto
        ;  simpl; eauto.
      - eapply nnrc_impish_stmt_cross_shadow_free_under_free_mdenv_mcenv; eauto
        ;  simpl; eauto.
    Qed.

    Lemma nnrc_impish_stmt_cross_shadow_free_under_free_mdenv_cons
          {s:nnrc_impish_stmt} {σ ψc ψd:list var} {v} :
      nnrc_impish_stmt_cross_shadow_free_under s σ ψc (v::ψd) ->
      ~ In v (nnrc_impish_stmt_free_env_vars s) /\ ~ In v (nnrc_impish_stmt_free_mcenv_vars s).
    Proof.
      intros sf; split; intros inn.
      - eapply nnrc_impish_stmt_cross_shadow_free_under_free_env_mdenv; eauto
        ;  simpl; eauto.
      - eapply nnrc_impish_stmt_cross_shadow_free_under_free_mcenv_mdenv; eauto
        ;  simpl; eauto.
    Qed.

    Lemma nnrc_impish_stmt_cross_shadow_free_under_free_cons
          (s:nnrc_impish_stmt) (σ ψc ψd:list var) v :
      (nnrc_impish_stmt_cross_shadow_free_under s (v::σ) ψc ψd ->
       ~ In v (nnrc_impish_stmt_free_mcenv_vars s) /\ ~ In v (nnrc_impish_stmt_free_mdenv_vars s))
      /\ (nnrc_impish_stmt_cross_shadow_free_under s σ (v::ψc) ψd ->
          ~ In v (nnrc_impish_stmt_free_env_vars s) /\ ~ In v (nnrc_impish_stmt_free_mdenv_vars s))
      /\ (nnrc_impish_stmt_cross_shadow_free_under s σ ψc (v::ψd) ->
          ~ In v (nnrc_impish_stmt_free_env_vars s) /\ ~ In v (nnrc_impish_stmt_free_mcenv_vars s))

    .
    Proof.
      split; [ | split ].
      -  apply nnrc_impish_stmt_cross_shadow_free_under_free_env_cons.
      -  apply nnrc_impish_stmt_cross_shadow_free_under_free_mcenv_cons.
      -  apply nnrc_impish_stmt_cross_shadow_free_under_free_mdenv_cons.
    Qed.

  End cross_shadow_free_disjointness.

  (** The cross shadow predicate is preserved by equivalence an inclusion of the variable lists *)
  Section cross_shadow_free_equivs.
    
    Global Instance nnrc_impish_stmt_cross_shadow_free_under_equivs :
      Proper (eq ==> equivlist ==> equivlist ==> equivlist ==> iff) nnrc_impish_stmt_cross_shadow_free_under.
    Proof.
      cut (Proper (eq ==> equivlist ==> equivlist ==> equivlist ==> Basics.impl) nnrc_impish_stmt_cross_shadow_free_under).
      {
        unfold Proper, respectful, equivlist; unfold Basics.impl; split; [eauto | ].
        symmetry in H1, H2, H3; eauto.
      }
      Ltac re_equivs_tac
        := match goal with
           | [H1: equivlist ?x ?y, H2: In ?v ?x, H3: In ?v ?y -> False |- _ ] =>
             rewrite H1 in H2; contradiction
           | [H1: equivlist ?y ?x, H2: In ?v ?x, H3: In ?v ?y -> False |- _ ] =>
             rewrite <- H1 in H2; contradiction
           | [ H1: equivlist ?x ?y, H2: disjoint _ ?x |- _ ] => rewrite H1 in H2
           | [ H1: equivlist ?x ?y |- disjoint _ ?x] => rewrite H1
           | [ |- equivlist (?x :: _ ) (?x :: _ ) ] => apply equivlist_cons_proper; [reflexivity | ]
           end.

      unfold Proper, respectful, Basics.impl; intros ? s ?; subst.
      nnrc_impish_stmt_cases (induction s) Case
      ; simpl; intros.
      -  Case "NNRCimpishSeq"%string.
         intuition eauto.
      -  Case "NNRCimpishLet"%string.
         intuition; repeat re_equivs_tac; eauto 2.
         + eapply (IHs (v::x)); eauto.
           re_equivs_tac; trivial.
      - Case "NNRCimpishLetMut"%string.
        intuition; repeat re_equivs_tac; eauto 2.
        + eapply IHs1; (try (eapply equivlist_cons; trivial; eapply H1)); eauto.
        + eapply IHs2; eauto. 
          re_equivs_tac; trivial.
      - Case "NNRCimpishLetMutColl"%string.
        intuition; repeat re_equivs_tac; eauto 2.
        + eapply IHs1; (try (eapply equivlist_cons; trivial; eapply H0)); eauto.
        + eapply IHs2; eauto. 
          re_equivs_tac; trivial.
      - Case "NNRCimpishAssign"%string.
        intuition; repeat re_equivs_tac; eauto 2.
      - Case "NNRCimpishPush"%string.
        intuition; repeat re_equivs_tac; eauto 2.
      - Case "NNRCimpishFor"%string.
        intuition; repeat re_equivs_tac; eauto 2.
        + eapply (IHs (v::x)); eauto.
          re_equivs_tac; trivial.
      - Case "NNRCimpishIf"%string.
        intuition; repeat re_equivs_tac; eauto 2.
      - Case "NNRCimpishEither"%string.
        intuition; repeat re_equivs_tac; eauto 2.
        + eapply IHs1; eauto; re_equivs_tac; trivial.
        + eapply IHs2; eauto; re_equivs_tac; trivial.
    Qed.

    Global Instance nnrc_impish_stmt_cross_shadow_free_under_incls :
      Proper (eq ==> (@incl string) --> (@incl string) --> (@incl string) --> Basics.impl) nnrc_impish_stmt_cross_shadow_free_under.
    Proof.
      Ltac re_incl_tac
        := match goal with
           | [H1: incl ?x ?y, H2: In ?v ?x, H3: In ?v ?y -> False |- _ ] =>
             rewrite H1 in H2; contradiction
           | [H1: incl ?y ?x, H2: In ?v ?x, H3: In ?v ?y -> False |- _ ] =>
             rewrite <- H1 in H2; contradiction
           | [ H1: incl ?x ?y, H2: disjoint _ ?x |- _ ] => rewrite H1 in H2
           | [ H1: incl ?x ?y |- disjoint _ ?x] => rewrite H1
           | [ |- incl (?x :: _ ) (?x :: _ ) ] => apply incl_cons_proper; [reflexivity | ]
           end.

      Ltac re_incl_tact := intuition; try solve [repeat re_incl_tac; intuition].


      unfold Proper, respectful, Basics.impl, Basics.flip; intros ? s ?; subst.
      nnrc_impish_stmt_cases (induction s) Case
      ; simpl; intros.
      -  Case "NNRCimpishSeq"%string.
         intuition eauto.
      -  Case "NNRCimpishLet"%string.
         re_incl_tact.
         + eapply (IHs (v::x)); eauto.
           re_incl_tact.
      - Case "NNRCimpishLetMut"%string.
        re_incl_tact.
        + eapply IHs1; (try (eapply incl_cons_proper; trivial; eapply H1)); eauto.
        + eapply IHs2; eauto. 
          re_incl_tact.
      - Case "NNRCimpishLetMutColl"%string.
        re_incl_tact.
        + eapply IHs1; (try (eapply incl_cons_proper; trivial; eapply H0)); eauto.
        + eapply IHs2; eauto. 
          re_incl_tact.
      - Case "NNRCimpishAssign"%string.
        re_incl_tact.
      - Case "NNRCimpishPush"%string.
        re_incl_tact.
      - Case "NNRCimpishFor"%string.
        re_incl_tact.
        + eapply (IHs (v::x)); eauto.
          re_incl_tact.
      - Case "NNRCimpishIf"%string.
        re_incl_tact; eauto.
      - Case "NNRCimpishEither"%string.
        re_incl_tact.
        + eapply IHs1; eauto; re_incl_tact.
        + eapply IHs2; eauto; re_incl_tact.
    Qed.

  End cross_shadow_free_equivs.

  (** The cross shadow under predicate is "top down".  This version is more bottom up.
        The former is easier for the translation to work with, the latter for the uncross_shadow transformation introduced later.
        The latter implies the former for suitably disjoint variable lists.
   *)

  Section cross_shadow_free_alt.

    Fixpoint nnrc_impish_stmt_cross_shadow_free_alt
             (s:nnrc_impish_stmt)
    : Prop
      := match s with
         | NNRCimpishSeq s₁ s₂ =>
           nnrc_impish_stmt_cross_shadow_free_alt s₁
           /\ nnrc_impish_stmt_cross_shadow_free_alt s₂
         | NNRCimpishLet v e s₀ =>
           ~ In v (nnrc_impish_stmt_free_mcenv_vars s₀)
           /\ ~ In v (nnrc_impish_stmt_bound_mcenv_vars s₀)
           /\ ~ In v (nnrc_impish_stmt_free_mdenv_vars s₀)
           /\ ~ In v (nnrc_impish_stmt_bound_mdenv_vars s₀)
           /\ nnrc_impish_stmt_cross_shadow_free_alt s₀
         | NNRCimpishLetMut v s₁ s₂ =>
           ~ In v (nnrc_impish_stmt_free_env_vars s₁)
           /\ ~ In v (nnrc_impish_stmt_bound_env_vars s₁)
           /\ ~ In v (nnrc_impish_stmt_free_mcenv_vars s₁)
           /\ ~ In v (nnrc_impish_stmt_bound_mcenv_vars s₁)
           /\ ~ In v (nnrc_impish_stmt_free_mcenv_vars s₂)
           /\ ~ In v (nnrc_impish_stmt_bound_mcenv_vars s₂)
           /\ ~ In v (nnrc_impish_stmt_bound_mdenv_vars s₂)
           /\ ~ In v (nnrc_impish_stmt_free_mdenv_vars s₂)
           /\ nnrc_impish_stmt_cross_shadow_free_alt s₁
           /\ nnrc_impish_stmt_cross_shadow_free_alt s₂
         | NNRCimpishLetMutColl v s₁ s₂ =>
           ~ In v (nnrc_impish_stmt_free_env_vars s₁)
           /\ ~ In v (nnrc_impish_stmt_bound_env_vars s₁)
           /\ ~ In v (nnrc_impish_stmt_free_mdenv_vars s₁)
           /\ ~ In v (nnrc_impish_stmt_bound_mdenv_vars s₁)
           /\ ~ In v (nnrc_impish_stmt_free_mcenv_vars s₂)
           /\ ~ In v (nnrc_impish_stmt_bound_mcenv_vars s₂)
           /\ ~ In v (nnrc_impish_stmt_bound_mdenv_vars s₂)
           /\ ~ In v (nnrc_impish_stmt_free_mdenv_vars s₂)
           /\ nnrc_impish_stmt_cross_shadow_free_alt s₁
           /\ nnrc_impish_stmt_cross_shadow_free_alt s₂ 
         | NNRCimpishAssign v e => True
         | NNRCimpishPush v e => True
         | NNRCimpishFor v e s₀ =>
           ~ In v (nnrc_impish_stmt_free_mcenv_vars s₀)
           /\ ~ In v (nnrc_impish_stmt_bound_mcenv_vars s₀)
           /\ ~ In v (nnrc_impish_stmt_free_mdenv_vars s₀)
           /\ ~ In v (nnrc_impish_stmt_bound_mdenv_vars s₀)
           /\ nnrc_impish_stmt_cross_shadow_free_alt s₀
         | NNRCimpishIf e s₁ s₂ =>
           nnrc_impish_stmt_cross_shadow_free_alt s₁
           /\ nnrc_impish_stmt_cross_shadow_free_alt s₂
         | NNRCimpishEither e x₁ s₁ x₂ s₂ =>
           ~ In x₁ (nnrc_impish_stmt_free_mcenv_vars s₁)
           /\ ~ In x₁ (nnrc_impish_stmt_bound_mcenv_vars s₁)
           /\ ~ In x₁ (nnrc_impish_stmt_free_mdenv_vars s₁)
           /\ ~ In x₁ (nnrc_impish_stmt_bound_mdenv_vars s₁)
           /\ ~ In x₂ (nnrc_impish_stmt_free_mcenv_vars s₂)
           /\ ~ In x₂ (nnrc_impish_stmt_bound_mcenv_vars s₂)
           /\ ~ In x₂ (nnrc_impish_stmt_free_mdenv_vars s₂)
           /\ ~ In x₂ (nnrc_impish_stmt_bound_mdenv_vars s₂)
           /\ nnrc_impish_stmt_cross_shadow_free_alt s₁ 
           /\ nnrc_impish_stmt_cross_shadow_free_alt s₂ 
         end.

    Ltac disj_tac :=
      repeat
        (match goal with
         | [ H : disjoint (_ ++ _) _ |- _ ] => apply disjoint_app_l in H; destruct H
         | [ H : disjoint (_ :: _) _ |- _ ] => apply disjoint_cons_inv1 in H; destruct H
         | [ H : disjoint _ (_ :: _) |- _ ] => apply disjoint_cons_inv2 in H; destruct H
         | [H1:disjoint (remove _ ?v ?l1) ?l2,
               H2:In ?v ?l1 -> False |- _ ] => rewrite nin_remove in H1 by apply H2
         | [H1:disjoint (remove _ ?v ?l1) ?l2,
               H2:~ In ?v ?l1 |- _ ] => rewrite nin_remove in H1 by apply H2
         | [H1:disjoint (remove _ ?v ?l1) ?l2,
               H2:In ?v ?l2 -> False |- _ ] => rewrite disjoint_remove_swap in H1; rewrite nin_remove in H1 by apply H2
         | [H1:disjoint (remove _ ?v ?l1) ?l2,
               H2:~ In ?v ?l2 |- _ ] => rewrite disjoint_remove_swap in H1; rewrite nin_remove in H1 by apply H2
         | [H : In _ (replace_all _ _ _ ) |- _ ] => apply in_replace_all in H; try solve [destruct H as [?|[??]]; subst; eauto]
         | [H: ~ In _ (remove _ _ _) |- _ ] => try rewrite <- remove_in_neq in H by congruence
         | [H: In _ (remove _ _ _) -> False |- _ ] => try rewrite <- remove_in_neq in H by congruence
         | [ |- disjoint (_ :: _) _ ] => apply disjoint_cons1
         | [ |- disjoint _ (_ :: _) ] => apply disjoint_cons2
         | [ |- disjoint _ (replace_all _ _ _ )] => try solve [apply disjoint_replace_all; intuition]
                                                        
         end; repeat rewrite in_app_iff in *
        ).

    Theorem  nnrc_impish_stmt_cross_shadow_free_under_alt
             (s:nnrc_impish_stmt) :
      nnrc_impish_stmt_cross_shadow_free_alt s ->
      forall (σ ψc ψd:list var),
        disjoint (nnrc_impish_stmt_free_mcenv_vars s) σ ->
        disjoint (nnrc_impish_stmt_bound_mcenv_vars s) σ ->
        disjoint (nnrc_impish_stmt_free_mdenv_vars s) σ ->
        disjoint (nnrc_impish_stmt_bound_mdenv_vars s) σ ->
        disjoint (nnrc_impish_stmt_free_env_vars s) ψc ->
        disjoint (nnrc_impish_stmt_bound_env_vars s) ψc ->
        disjoint (nnrc_impish_stmt_free_mdenv_vars s) ψc ->
        disjoint (nnrc_impish_stmt_bound_mdenv_vars s) ψc ->
        disjoint (nnrc_impish_stmt_free_env_vars s) ψd ->
        disjoint (nnrc_impish_stmt_bound_env_vars s) ψd ->
        disjoint (nnrc_impish_stmt_free_mcenv_vars s) ψd ->
        disjoint (nnrc_impish_stmt_bound_mcenv_vars s) ψd ->
        nnrc_impish_stmt_cross_shadow_free_under s σ ψc ψd.
    Proof.
      nnrc_impish_stmt_cases (induction s) Case
      ; simpl; intros 
      ; disj_tac
      ; repeat split
      ; try solve [
              tauto
            | eapply IHs; disj_tac; intuition
            | eapply IHs1; disj_tac; intuition
            | eapply IHs2; disj_tac; intuition].
    Qed.

    Ltac fresh_simpl_rewriter
      := repeat autorewrite with nnrc_impish_rename in *
         ; repeat rewrite in_app_iff in *
         ; repeat match goal with
                  | [H: In _ (nnrc_impish_stmt_free_env_vars (nnrc_impish_stmt_rename_env _ _ _)) |- _] => apply nnrc_impish_stmt_free_env_vars_rename_env_in in H
                  | [H: In _ (nnrc_impish_stmt_free_mcenv_vars (nnrc_impish_stmt_rename_mc _ _ _)) |- _] => apply nnrc_impish_stmt_free_mcenv_vars_rename_mcenv_in in H
                  | [H: In _ (nnrc_impish_stmt_free_mdenv_vars (nnrc_impish_stmt_rename_md _ _ _)) |- _] => apply nnrc_impish_stmt_free_mdenv_vars_rename_mdenv_in in H
                  | [H: In _ (remove _ _ _) -> False |- _ ] =>
                    try rewrite <- remove_in_neq in H by congruence
                  end
         ; intuition.
    
    Lemma nnrc_impish_stmt_cross_shadow_free_alt_rename_env s v v' :
      ~ In v' (nnrc_impish_stmt_free_mcenv_vars s) ->
      ~ In v' (nnrc_impish_stmt_bound_mcenv_vars s )->
      ~ In v' (nnrc_impish_stmt_free_mdenv_vars s) ->
      ~ In v' (nnrc_impish_stmt_bound_mdenv_vars s) ->
      nnrc_impish_stmt_cross_shadow_free_alt s ->
      nnrc_impish_stmt_cross_shadow_free_alt
        (nnrc_impish_stmt_rename_env s v v').
    Proof.
      nnrc_impish_stmt_cases (induction s) Case
      ; simpl.
      - Case "NNRCimpishSeq"%string.
        fresh_simpl_rewriter.
      - Case "NNRCimpishLet"%string.
        match_destr.
        fresh_simpl_rewriter.
      - Case "NNRCimpishLetMut"%string.
        repeat split
        ; do 2 fresh_simpl_rewriter
        ; try (match_destr_in H4
               ; fresh_simpl_rewriter).
        match_destr; fresh_simpl_rewriter.
      - Case "NNRCimpishLetMutColl"%string.
        repeat split
        ; do 2 fresh_simpl_rewriter
        ; try (match_destr_in H4
               ; fresh_simpl_rewriter).
        match_destr; fresh_simpl_rewriter.
      - Case "NNRCimpishAssign"%string.
        trivial.
      - Case "NNRCimpishPush"%string.
        trivial.
      - Case "NNRCimpishFor"%string.
        match_destr.
        fresh_simpl_rewriter.
      - Case "NNRCimpishIf"%string.
        fresh_simpl_rewriter.
      - Case "NNRCimpishEither"%string.
        fresh_simpl_rewriter
        ; try (match_destr_in H2; fresh_simpl_rewriter)
        ; match_destr; fresh_simpl_rewriter.
    Qed.

    Lemma nnrc_impish_stmt_cross_shadow_free_alt_rename_mcenv s v v' :
      ~ In v' (nnrc_impish_stmt_free_env_vars s) ->
      ~ In v' (nnrc_impish_stmt_bound_env_vars s )->
      ~ In v' (nnrc_impish_stmt_free_mdenv_vars s) ->
      ~ In v' (nnrc_impish_stmt_bound_mdenv_vars s) ->
      nnrc_impish_stmt_cross_shadow_free_alt s ->
      nnrc_impish_stmt_cross_shadow_free_alt
        (nnrc_impish_stmt_rename_mc s v v').
    Proof.
      nnrc_impish_stmt_cases (induction s) Case
      ; simpl.
      - Case "NNRCimpishSeq"%string.
        fresh_simpl_rewriter.
      - Case "NNRCimpishLet"%string.
        do 2 fresh_simpl_rewriter.
      - Case "NNRCimpishLetMut"%string.
        repeat split
        ; do 2 fresh_simpl_rewriter.
      - Case "NNRCimpishLetMutColl"%string.
        repeat split
        ; do 2 fresh_simpl_rewriter
        ; try (match_destr_in H4
               ; fresh_simpl_rewriter).
        match_destr; fresh_simpl_rewriter.
      - Case "NNRCimpishAssign"%string.
        trivial.
      - Case "NNRCimpishPush"%string.
        trivial.
      - Case "NNRCimpishFor"%string.
        do 2 fresh_simpl_rewriter.
      - Case "NNRCimpishIf"%string.
        fresh_simpl_rewriter.
      - Case "NNRCimpishEither"%string.
        do 2 fresh_simpl_rewriter.
    Qed.

    Lemma nnrc_impish_stmt_cross_shadow_free_alt_rename_mdenv s v v' :
      ~ In v' (nnrc_impish_stmt_free_env_vars s) ->
      ~ In v' (nnrc_impish_stmt_bound_env_vars s )->
      ~ In v' (nnrc_impish_stmt_free_mcenv_vars s) ->
      ~ In v' (nnrc_impish_stmt_bound_mcenv_vars s) ->
      nnrc_impish_stmt_cross_shadow_free_alt s ->
      nnrc_impish_stmt_cross_shadow_free_alt
        (nnrc_impish_stmt_rename_md s v v').
    Proof.
      nnrc_impish_stmt_cases (induction s) Case
      ; simpl.
      - Case "NNRCimpishSeq"%string.
        fresh_simpl_rewriter.
      - Case "NNRCimpishLet"%string.
        do 2 fresh_simpl_rewriter.
      - Case "NNRCimpishLetMut"%string.
        repeat split
        ; do 2 fresh_simpl_rewriter
        ; try (match_destr_in H4
               ; fresh_simpl_rewriter).
        match_destr; fresh_simpl_rewriter.
      - Case "NNRCimpishLetMutColl"%string.
        repeat split
        ; do 2 fresh_simpl_rewriter
        ; try (match_destr_in H4
               ; fresh_simpl_rewriter).
      - Case "NNRCimpishAssign"%string.
        trivial.
      - Case "NNRCimpishPush"%string.
        trivial.
      - Case "NNRCimpishFor"%string.
        do 2 fresh_simpl_rewriter.
      - Case "NNRCimpishIf"%string.
        fresh_simpl_rewriter.
      - Case "NNRCimpishEither"%string.
        do 2 fresh_simpl_rewriter.
    Qed.

  End cross_shadow_free_alt.


  Section uncross.

    Context (sep:string).
    Fixpoint nnrc_impish_stmt_uncross_shadow_under
             (s:nnrc_impish_stmt)
             (σ ψc ψd:list var)
      : nnrc_impish_stmt
      := match s with
         | NNRCimpishSeq s₁ s₂ =>
           NNRCimpishSeq
             (nnrc_impish_stmt_uncross_shadow_under s₁ σ ψc ψd)
             (nnrc_impish_stmt_uncross_shadow_under s₂ σ ψc ψd)
         | NNRCimpishLet v e s₀ =>
           let s₀' := nnrc_impish_stmt_uncross_shadow_under s₀ (v::σ) ψc ψd in
           let problems :=
               remove equiv_dec v (nnrc_impish_stmt_free_env_vars s₀')
                      ++ remove equiv_dec v (nnrc_impish_stmt_bound_env_vars s₀')
                      ++ (nnrc_impish_stmt_free_mcenv_vars s₀')
                      ++ (nnrc_impish_stmt_bound_mcenv_vars s₀')
                      ++ (nnrc_impish_stmt_free_mdenv_vars s₀')
                      ++ (nnrc_impish_stmt_bound_mdenv_vars s₀')
           in
           let v' := fresh_var_from sep v problems in
           NNRCimpishLet v' e (mk_lazy_lift nnrc_impish_stmt_rename_env s₀' v v')
         | NNRCimpishLetMut v s₁ s₂ =>
           let s₁' := nnrc_impish_stmt_uncross_shadow_under s₁ σ ψc (v::ψd) in
           let s₂' := nnrc_impish_stmt_uncross_shadow_under s₂ (v::σ) ψc ψd in
           let problems := remove equiv_dec v (nnrc_impish_stmt_free_mdenv_vars s₁')
                                  ++ remove equiv_dec v (nnrc_impish_stmt_bound_mdenv_vars s₁')
                                  ++ remove equiv_dec v (nnrc_impish_stmt_free_env_vars s₂')
                                  ++ remove equiv_dec v (nnrc_impish_stmt_bound_env_vars s₂')
                                  ++ σ
                                  ++ ψd
                                  ++ nnrc_impish_stmt_free_env_vars s₁'
                                  ++ nnrc_impish_stmt_bound_env_vars s₁'
                                  ++ nnrc_impish_stmt_free_mcenv_vars s₁'
                                  ++ nnrc_impish_stmt_bound_mcenv_vars s₁'
                                  ++ nnrc_impish_stmt_free_mcenv_vars s₂'
                                  ++ nnrc_impish_stmt_bound_mcenv_vars s₂'
                                  ++ nnrc_impish_stmt_free_mdenv_vars s₂'
                                  ++ nnrc_impish_stmt_bound_mdenv_vars s₂' in
           let v' := fresh_var_from sep v problems in
           NNRCimpishLetMut v'
                            (mk_lazy_lift nnrc_impish_stmt_rename_md s₁' v v')
                            (mk_lazy_lift nnrc_impish_stmt_rename_env s₂' v v')
         | NNRCimpishLetMutColl v s₁ s₂ =>
           let s₁' := nnrc_impish_stmt_uncross_shadow_under s₁ σ (v::ψc) ψd in
           let s₂' := nnrc_impish_stmt_uncross_shadow_under s₂ (v::σ) ψc ψd in
           let problems :=  remove equiv_dec v (nnrc_impish_stmt_free_mcenv_vars s₁')
                                   ++ remove equiv_dec v (nnrc_impish_stmt_bound_mcenv_vars s₁')
                                   ++ remove equiv_dec v (nnrc_impish_stmt_free_env_vars s₂')
                                   ++ remove equiv_dec v (nnrc_impish_stmt_bound_env_vars s₂')
                                   ++ σ
                                   ++ ψd
                                   ++ ψc
                                   ++ nnrc_impish_stmt_free_env_vars s₁'
                                   ++ nnrc_impish_stmt_bound_env_vars s₁'
                                   ++ nnrc_impish_stmt_free_mdenv_vars s₁'
                                   ++ nnrc_impish_stmt_bound_mdenv_vars s₁'
                                   ++ nnrc_impish_stmt_free_mcenv_vars s₂'
                                   ++ nnrc_impish_stmt_bound_mcenv_vars s₂'
                                   ++ nnrc_impish_stmt_free_mdenv_vars s₂'
                                   ++ nnrc_impish_stmt_bound_mdenv_vars s₂' in
           let v' := fresh_var_from sep v problems in
           NNRCimpishLetMutColl v' 
                                (mk_lazy_lift nnrc_impish_stmt_rename_mc s₁' v v')
                                (mk_lazy_lift nnrc_impish_stmt_rename_env s₂' v v')
         | NNRCimpishAssign v e =>
           NNRCimpishAssign v e
         | NNRCimpishPush v e =>
           NNRCimpishPush v e
         | NNRCimpishFor v e s₀ =>
           let s₀' := nnrc_impish_stmt_uncross_shadow_under s₀ (v::σ) ψc ψd in
           let problems := remove equiv_dec v (nnrc_impish_stmt_free_env_vars s₀')
                                  ++ remove equiv_dec v (nnrc_impish_stmt_bound_env_vars s₀')
                                  ++ (nnrc_impish_stmt_free_mcenv_vars s₀')
                                  ++ (nnrc_impish_stmt_bound_mcenv_vars s₀')
                                  ++ (nnrc_impish_stmt_free_mdenv_vars s₀')
                                  ++ (nnrc_impish_stmt_bound_mdenv_vars s₀') in
           let v' := fresh_var_from sep v problems in
           NNRCimpishFor v' e (mk_lazy_lift nnrc_impish_stmt_rename_env s₀' v v')
         | NNRCimpishIf e s₁ s₂ =>
           NNRCimpishIf
             e
             (nnrc_impish_stmt_uncross_shadow_under s₁ σ ψc ψd)
             (nnrc_impish_stmt_uncross_shadow_under s₂ σ ψc ψd)
         | NNRCimpishEither e x₁ s₁ x₂ s₂ =>
           let s₁' := nnrc_impish_stmt_uncross_shadow_under s₁ (x₁::σ) ψc ψd in
           let problems₁ :=  remove equiv_dec x₁ (nnrc_impish_stmt_free_env_vars s₁')
                                    ++ remove equiv_dec x₁ (nnrc_impish_stmt_bound_env_vars s₁')
                                    ++ (nnrc_impish_stmt_free_mcenv_vars s₁')
                                    ++ (nnrc_impish_stmt_bound_mcenv_vars s₁')
                                    ++ (nnrc_impish_stmt_free_mdenv_vars s₁')
                                    ++ (nnrc_impish_stmt_bound_mdenv_vars s₁') in
           let x₁' := fresh_var_from sep x₁ problems₁ in
           let s₂' := nnrc_impish_stmt_uncross_shadow_under s₂ (x₂::σ) ψc ψd in
           let problems₂ := remove equiv_dec x₂ (nnrc_impish_stmt_free_env_vars s₂')
                                   ++ remove equiv_dec x₂ (nnrc_impish_stmt_bound_env_vars s₂')
                                   ++ (nnrc_impish_stmt_free_mcenv_vars s₂')
                                   ++ (nnrc_impish_stmt_bound_mcenv_vars s₂')
                                   ++ (nnrc_impish_stmt_free_mdenv_vars s₂')
                                   ++ (nnrc_impish_stmt_bound_mdenv_vars s₂') in
           let x₂' := fresh_var_from sep x₂ problems₂ in
           NNRCimpishEither e
                            x₁'
                            (mk_lazy_lift nnrc_impish_stmt_rename_env s₁' x₁ x₁')
                            x₂'
                            (mk_lazy_lift nnrc_impish_stmt_rename_env s₂' x₂ x₂')
         end.

    Definition nnrc_impish_uncross_shadow
               (s:nnrc_impish)
      : nnrc_impish
      :=
        let s' := nnrc_impish_stmt_uncross_shadow_under (fst s) nil nil (snd s::nil) in
        let problems := nnrc_impish_stmt_free_env_vars s'
                                                       ++ nnrc_impish_stmt_bound_env_vars s'
                                                       ++ nnrc_impish_stmt_free_mcenv_vars s'
                                                       ++ nnrc_impish_stmt_bound_mcenv_vars s' 
                                                       ++ remove equiv_dec (snd s) (nnrc_impish_stmt_free_mdenv_vars s')
                                                       ++ remove equiv_dec (snd s) (nnrc_impish_stmt_bound_mdenv_vars s') in
        let v' := fresh_var_from sep (snd s) problems in
        (mk_lazy_lift nnrc_impish_stmt_rename_md s' (snd s) v', v').

  End uncross.

  Section correctness.

    Ltac fresh_prover
      :=
        repeat rewrite (mk_lazy_lift_under nnrc_impish_stmt_bound_env_vars_rename_env)          
        ; repeat rewrite (mk_lazy_lift_under nnrc_impish_stmt_free_mcenv_vars_rename_env)
        ; repeat rewrite (mk_lazy_lift_under nnrc_impish_stmt_bound_mcenv_vars_rename_env)
        ; repeat rewrite (mk_lazy_lift_under nnrc_impish_stmt_free_mdenv_vars_rename_env)
        ; repeat rewrite (mk_lazy_lift_under nnrc_impish_stmt_bound_mdenv_vars_rename_env)
                 
        ; repeat rewrite (mk_lazy_lift_under nnrc_impish_stmt_free_env_vars_rename_mcenv)
        ; repeat rewrite (mk_lazy_lift_under nnrc_impish_stmt_bound_env_vars_rename_mcenv)
        ; repeat rewrite (mk_lazy_lift_under nnrc_impish_stmt_bound_mcenv_vars_rename_mcenv)
        ; repeat rewrite (mk_lazy_lift_under nnrc_impish_stmt_free_mdenv_vars_rename_mcenv)
        ; repeat rewrite (mk_lazy_lift_under nnrc_impish_stmt_bound_mdenv_vars_rename_mcenv)

        ; repeat rewrite (mk_lazy_lift_under nnrc_impish_stmt_free_env_vars_rename_mdenv)
        ; repeat rewrite (mk_lazy_lift_under nnrc_impish_stmt_bound_env_vars_rename_mdenv)
        ; repeat rewrite (mk_lazy_lift_under nnrc_impish_stmt_free_mcenv_vars_rename_mdenv)
        ; repeat rewrite (mk_lazy_lift_under nnrc_impish_stmt_bound_mcenv_vars_rename_mdenv)
        ; repeat rewrite (mk_lazy_lift_under nnrc_impish_stmt_bound_mdenv_vars_rename_mdenv)

        ; try solve [apply fresh_var_from_incl_nin
                     ; unfold incl; intros; repeat rewrite in_app_iff; intuition].
    
    Lemma nnrc_impish_stmt_uncross_shadow_free_alt sep (s:nnrc_impish_stmt)
          (σ ψc ψd:list var) :
      nnrc_impish_stmt_cross_shadow_free_alt 
        (nnrc_impish_stmt_uncross_shadow_under sep s σ ψc ψd).
    Proof.
      revert σ ψc ψd
      ; nnrc_impish_stmt_cases (induction s) Case
      ; simpl; intros σ ψc ψd; intros.
      - Case "NNRCimpishSeq"%string.
        intuition.
      - Case "NNRCimpishLet"%string.
        specialize (IHs (v::σ) ψc ψd).
        fresh_prover.
        repeat split; try fresh_prover.
        apply mk_lazy_lift_prop; trivial; intros neq.
        apply nnrc_impish_stmt_cross_shadow_free_alt_rename_env; trivial
        ; apply fresh_var_from_incl_nin
        ; unfold incl; intros; repeat rewrite in_app_iff; tauto.
      - Case "NNRCimpishLetMut"%string.
        specialize (IHs1 σ ψc (v::ψd)).
        specialize (IHs2 (v::σ) ψc ψd).
        fresh_prover.
        repeat split; try fresh_prover.
        + apply mk_lazy_lift_prop; trivial; intros neq.
          apply nnrc_impish_stmt_cross_shadow_free_alt_rename_mdenv; trivial
          ; apply fresh_var_from_incl_nin
          ; unfold incl; intros; repeat rewrite in_app_iff; tauto.
        + apply mk_lazy_lift_prop; trivial; intros neq.
          apply nnrc_impish_stmt_cross_shadow_free_alt_rename_env; trivial
          ; apply fresh_var_from_incl_nin
          ; unfold incl; intros; repeat rewrite in_app_iff; tauto.
      - Case "NNRCimpishLetMutColl"%string.
        specialize (IHs1 σ (v::ψc) ψd).
        specialize (IHs2 (v::σ) ψc ψd).
        fresh_prover.
        repeat split; try fresh_prover.
        + apply mk_lazy_lift_prop; trivial; intros neq.
          apply nnrc_impish_stmt_cross_shadow_free_alt_rename_mcenv; trivial
          ; apply fresh_var_from_incl_nin
          ; unfold incl; intros; repeat rewrite in_app_iff; tauto.
        + apply mk_lazy_lift_prop; trivial; intros neq.
          apply nnrc_impish_stmt_cross_shadow_free_alt_rename_env; trivial
          ; apply fresh_var_from_incl_nin
          ; unfold incl; intros; repeat rewrite in_app_iff; tauto.
      - Case "NNRCimpishAssign"%string.
        trivial.
      - Case "NNRCimpishPush"%string.
        trivial.
      - Case "NNRCimpishFor"%string.
        specialize (IHs (v::σ) ψc ψd).
        fresh_prover.
        repeat split; try fresh_prover.
        apply mk_lazy_lift_prop; trivial; intros neq.
        apply nnrc_impish_stmt_cross_shadow_free_alt_rename_env; trivial
        ; apply fresh_var_from_incl_nin
        ; unfold incl; intros; repeat rewrite in_app_iff; tauto.
      - Case "NNRCimpishIf"%string.
        intuition.
      - Case "NNRCimpishEither"%string.
        specialize (IHs1 (v::σ) ψc ψd).
        specialize (IHs2 (v0::σ) ψc ψd).
        fresh_prover.
        repeat split; try fresh_prover
        ; apply mk_lazy_lift_prop; trivial; intros neq
        ; apply nnrc_impish_stmt_cross_shadow_free_alt_rename_env; trivial
        ; apply fresh_var_from_incl_nin
        ; unfold incl; intros; repeat rewrite in_app_iff; tauto.
    Qed.

    Theorem nnrc_impish_uncross_shadow_free sep (s:nnrc_impish) :
      nnrc_impish_cross_shadow_free (nnrc_impish_uncross_shadow sep s).
    Proof.
      destruct s as [s ret]
      ; unfold nnrc_impish_cross_shadow_free, nnrc_impish_uncross_shadow; simpl.
      apply nnrc_impish_stmt_cross_shadow_free_under_alt; simpl
      ; try apply disjoint_nil_r
      ; try
          (fresh_prover
           ; unfold disjoint; simpl; intros ? inn1 inn2; intuition; subst
           ; apply (fresh_var_from_nincl inn1)
           ; intros ? inn3
           ; repeat rewrite in_app_iff in *; tauto).
      apply mk_lazy_lift_prop; intros.
      - apply nnrc_impish_stmt_uncross_shadow_free_alt.
      - apply nnrc_impish_stmt_cross_shadow_free_alt_rename_mdenv; trivial
        ; try (apply fresh_var_from_incl_nin
               ; unfold incl; intros; repeat rewrite in_app_iff; tauto).
        apply nnrc_impish_stmt_uncross_shadow_free_alt.
    Qed.

    Lemma nnrc_impish_stmt_uncross_shadow_under_eval h c sep (s:nnrc_impish_stmt) σ ψc ψd domσ domψc domψd :
      nnrc_impish_stmt_eval h c σ ψc ψd (nnrc_impish_stmt_uncross_shadow_under sep s domσ domψc domψd) = nnrc_impish_stmt_eval h c σ ψc ψd s.
    Proof.

      Ltac prove_freshness 
        := match goal with
             [ H: ?v = fresh_var_from _ ?v _ -> False |- _ ] =>

             unfold fresh_var_from in H
             ; match_destr_in H; try congruence
             ; apply fresh_var_from_incl_nin
             ; let a := (fresh "a") in
               intros a inn; repeat rewrite in_app_iff in *
               ; destruct (a == v); unfold equiv, complement in *
               ; [subst; trivial
                 | eapply remove_in_neq in inn; eauto; try congruence
                 ]
           end.
      
      revert σ ψc ψd domσ domψc domψd
      ; nnrc_impish_stmt_cases (induction s) Case
      ; simpl; intros σ ψc ψd domσ domψc domψd.
      - Case "NNRCimpishSeq"%string.
        rewrite IHs1.
        repeat match_destr.
      - Case "NNRCimpishLet"%string.
        match_destr.
        unfold mk_lazy_lift.
        dest_eqdec.
        + rewrite <- e.
          rewrite IHs; trivial.
        + rewrite nnrc_impish_stmt_eval_rename_env; try prove_freshness.
          rewrite IHs; trivial.
          case_eq (nnrc_impish_stmt_eval h c ((v, Some d) :: σ) ψc ψd s )
          ; simpl; trivial; intros [[??]?] eqq.
          destruct p; trivial.
          destruct p; trivial.            
      - Case "NNRCimpishLetMut"%string.
        unfold mk_lazy_lift.
        dest_eqdec.
        + rewrite <- e.
          rewrite IHs1.
          match_destr.
          destruct p as [[??]?]
          ; destruct m0; trivial
          ; destruct p0; trivial.
          rewrite IHs2; trivial.
        + rewrite nnrc_impish_stmt_eval_rename_mdenv; try prove_freshness.
          rewrite IHs1.
          unfold var in *.
          case_eq (nnrc_impish_stmt_eval h c σ ψc ((v, None) :: ψd) s1)
          ; simpl; trivial; intros [[??]?] eqq.
          destruct m0; trivial.
          destruct p0; simpl.
          rewrite nnrc_impish_stmt_eval_rename_env; try prove_freshness.
          rewrite IHs2; trivial.
          unfold var in *.
          case_eq (nnrc_impish_stmt_eval h c ((v, o) :: p) m m0 s2)
          ; simpl; trivial; intros [[??]?] eqq2.
          destruct p0; trivial.
          destruct p0; trivial.
      - Case "NNRCimpishLetMutColl"%string.
        unfold mk_lazy_lift.
        dest_eqdec.
        + rewrite <- e.
          rewrite IHs1.
          match_destr.
          destruct p as [[??]?]
          ; destruct m; trivial
          ; destruct p0; trivial.
          rewrite IHs2; trivial.
        + rewrite nnrc_impish_stmt_eval_rename_mcenv; try prove_freshness.
          rewrite IHs1.
          unfold var in *.
          case_eq (nnrc_impish_stmt_eval h c σ ((v, nil) :: ψc) ψd s1)
          ; simpl; trivial; intros [[??]?] eqq.
          destruct m; trivial.
          destruct p0; simpl.
          rewrite nnrc_impish_stmt_eval_rename_env; try prove_freshness.
          rewrite IHs2; trivial.
          unfold var in *.
          case_eq (nnrc_impish_stmt_eval h c ((v, Some (dcoll l)) :: p) m m0 s2)
          ; simpl; trivial; intros [[??]?] eqq2.
          destruct p0; trivial.
          destruct p0; trivial.
      - Case "NNRCimpishAssign"%string.
        trivial.
      - Case "NNRCimpishPush"%string.
        trivial.
      - Case "NNRCimpishFor"%string.
        match_destr.
        unfold mk_lazy_lift.
        dest_eqdec.
        + rewrite <- e.
          clear e.
          destruct d; trivial.
          revert σ ψc ψd domσ domψc domψd.
          induction l
          ; simpl; intros σ ψc ψd domσ domψc domψd; trivial.
          rewrite IHs; trivial.
          match_destr.
          destruct p as [[??]?].
          destruct p; trivial.
          unfold var in *.
          apply (IHl p0 m m0 domσ domψc domψd).
        + destruct d; trivial.
          revert σ ψc ψd domσ domψc domψd c0.
          induction l
          ; simpl; intros σ ψc ψd domσ domψc domψd c0; trivial.
          rewrite nnrc_impish_stmt_eval_rename_env; try prove_freshness.
          rewrite IHs.
          case_eq ( nnrc_impish_stmt_eval h c ((v, Some a) :: σ) ψc ψd s); trivial
          ; intros [[??]?] eqq2.
          destruct p; trivial.
          destruct p; trivial.
          unfold var in *.
          apply (IHl p0 m m0 domσ domψc domψd); trivial.
      - Case "NNRCimpishIf"%string.
        match_destr.
        destruct d; trivial.
        destruct b; eauto.
      - Case "NNRCimpishEither"%string.
        match_destr.
        destruct d; trivial.
        + unfold mk_lazy_lift.
          dest_eqdec.
          *  rewrite <- e.
             rewrite IHs1; trivial.
          * rewrite nnrc_impish_stmt_eval_rename_env; try prove_freshness.
            rewrite IHs1; trivial.
            case_eq (nnrc_impish_stmt_eval h c ((v, Some d) :: σ) ψc ψd s1 )
            ; simpl; trivial; intros [[??]?] eqq.
            destruct p; trivial.
            destruct p; trivial.            
        + unfold mk_lazy_lift.
          dest_eqdec.
          *  rewrite <- e.
             rewrite IHs2; trivial.
          * rewrite nnrc_impish_stmt_eval_rename_env; try prove_freshness.
            rewrite IHs2; trivial.
            case_eq (nnrc_impish_stmt_eval h c ((v0, Some d) :: σ) ψc ψd s2 )
            ; simpl; trivial; intros [[??]?] eqq.
            destruct p; trivial.
            destruct p; trivial.            
    Qed.

    Theorem nnrc_impish_uncross_shadow_eval h c sep (s:nnrc_impish) :
      nnrc_impish_eval h c (nnrc_impish_uncross_shadow sep s) = nnrc_impish_eval h c s.
    Proof.
      destruct s as [s ret]
      ; unfold nnrc_impish_cross_shadow_free, nnrc_impish_uncross_shadow; simpl.
      unfold mk_lazy_lift.
      dest_eqdec.
      + rewrite <- e.
        rewrite nnrc_impish_stmt_uncross_shadow_under_eval; trivial.
      + rewrite nnrc_impish_stmt_eval_rename_mdenv
        ; [| try prove_freshness ; intuition..].

        rewrite nnrc_impish_stmt_uncross_shadow_under_eval; trivial.
        destruct (nnrc_impish_stmt_eval h c nil nil ((ret, None) :: nil) s); trivial.
        destruct p as [[??]?].
        destruct m0; simpl; trivial.
        destruct p0; trivial.
    Qed. 

  End correctness.
  
  Section core.
    
    Lemma nnrc_impish_stmt_uncross_shadow_under_preserves_core_f sep (s:nnrc_impish_stmt) (σ ψc ψd:list var) :
      nnrc_impish_stmtIsCore s ->
      nnrc_impish_stmtIsCore (nnrc_impish_stmt_uncross_shadow_under sep s σ ψc ψd).
    Proof.
      revert σ ψc ψd
      ; nnrc_impish_stmt_cases (induction s) Case
      ; simpl; intros σ ψc ψd sf.
      - Case "NNRCimpishSeq"%string.
        intuition.
      - Case "NNRCimpishLet"%string.
        destruct sf as [sf1 sf2]; split; trivial.
        apply mk_lazy_lift_prop; [eauto | intros].
        apply nnrc_impish_stmt_rename_env_core_f.
        eauto.
      - Case "NNRCimpishLetMut"%string.
        destruct sf as [sf1 sf2]; split; trivial.
        apply mk_lazy_lift_prop; [eauto | intros].
        + apply nnrc_impish_stmt_rename_md_core; eauto.
        + apply mk_lazy_lift_prop; [eauto | intros].
          apply nnrc_impish_stmt_rename_env_core; eauto.
      - Case "NNRCimpishLetMutColl"%string.
        destruct sf as [sf1 sf2]; split; trivial.
        apply mk_lazy_lift_prop; [eauto | intros].
        + apply nnrc_impish_stmt_rename_mc_core; eauto.
        + apply mk_lazy_lift_prop; [eauto | intros].
          apply nnrc_impish_stmt_rename_env_core; eauto.
      - Case "NNRCimpishAssign"%string.
        trivial.
      - Case "NNRCimpishPush"%string.
        trivial.
      - Case "NNRCimpishFor"%string.
        destruct sf as [sf1 sf2]; split; trivial.
        apply mk_lazy_lift_prop; [eauto | intros].
        apply nnrc_impish_stmt_rename_env_core.
        eauto.
      - Case "NNRCimpishIf"%string.
        intuition.
      - Case "NNRCimpishEither"%string.
        destruct sf as [sf1 sf2]; split; trivial.
        split
        ; (apply mk_lazy_lift_prop; [intuition | intros]
           ; apply nnrc_impish_stmt_rename_env_core
           ; intuition).
    Qed.

    Lemma nnrc_impish_stmt_uncross_shadow_under_preserves_core_b sep (s:nnrc_impish_stmt) (σ ψc ψd:list var) :
      nnrc_impish_stmtIsCore (nnrc_impish_stmt_uncross_shadow_under sep s σ ψc ψd) ->
      nnrc_impish_stmtIsCore s.
    Proof.
      revert σ ψc ψd
      ; nnrc_impish_stmt_cases (induction s) Case
      ; simpl; intros σ ψc ψd sf.
      - Case "NNRCimpishSeq"%string.
        intuition eauto.
      - Case "NNRCimpishLet"%string.
        destruct sf as [sf1 sf2]; split; trivial.
        apply mk_lazy_lift_prop_inv in sf2.
        destruct sf2 as [[??]|[sf2 a]]; [eauto|].
        apply nnrc_impish_stmt_rename_env_core in a; eauto.
      - Case "NNRCimpishLetMut"%string.
        destruct sf as [sf1 sf2].
        split.
        + apply mk_lazy_lift_prop_inv in sf1.
          destruct sf1 as [[??]|[sf1 a]]; [eauto|].
          apply nnrc_impish_stmt_rename_md_core in a; eauto.
        + apply mk_lazy_lift_prop_inv in sf2.
          destruct sf2 as [[??]|[sf2 a]]; [eauto|].
          apply nnrc_impish_stmt_rename_env_core in a; eauto.
      - Case "NNRCimpishLetMutColl"%string.
        destruct sf as [sf1 sf2].
        split.
        + apply mk_lazy_lift_prop_inv in sf1.
          destruct sf1 as [[??]|[sf1 a]]; [eauto|].
          apply nnrc_impish_stmt_rename_mc_core in a; eauto.
        + apply mk_lazy_lift_prop_inv in sf2.
          destruct sf2 as [[??]|[sf2 a]]; [eauto|].
          apply nnrc_impish_stmt_rename_env_core in a; eauto.
      - Case "NNRCimpishAssign"%string.
        trivial.
      - Case "NNRCimpishPush"%string.
        trivial.
      - Case "NNRCimpishFor"%string.
        destruct sf as [sf1 sf2]; split; trivial.
        apply mk_lazy_lift_prop_inv in sf2.
        destruct sf2 as [[??]|[sf2 a]]; [eauto|].
        apply nnrc_impish_stmt_rename_env_core in a.
        eauto.
      - Case "NNRCimpishIf"%string.
        intuition eauto.
      - Case "NNRCimpishEither"%string.
        destruct sf as [sf1 [sf2 sf3]]; split; trivial.
        split.
        + apply mk_lazy_lift_prop_inv in sf2.
          destruct sf2 as [[??]|[sf2 a]]; [eauto|].
          apply nnrc_impish_stmt_rename_env_core in a.
          eauto.
        + apply mk_lazy_lift_prop_inv in sf3.
          destruct sf3 as [[??]|[sf3 a]]; [eauto|].
          apply nnrc_impish_stmt_rename_env_core in a.
          eauto.
    Qed.

    Lemma nnrc_impish_stmt_uncross_shadow_under_preserves_core
          sep (s:nnrc_impish_stmt) (σ ψc ψd:list var) :
      nnrc_impish_stmtIsCore (nnrc_impish_stmt_uncross_shadow_under sep s σ ψc ψd) <->
      nnrc_impish_stmtIsCore s.
    Proof.
      split.
      - apply  nnrc_impish_stmt_uncross_shadow_under_preserves_core_b.
      - apply  nnrc_impish_stmt_uncross_shadow_under_preserves_core_f.
    Qed.
    
    Theorem nnrc_impish_uncross_shadow_preserves_core sep (s:nnrc_impish) :
      nnrc_impishIsCore (nnrc_impish_uncross_shadow sep s) <->
      nnrc_impishIsCore s.
    Proof.
      destruct s as [s ret]
      ; unfold nnrc_impishIsCore, nnrc_impish_cross_shadow_free, nnrc_impish_uncross_shadow; simpl.
      apply mk_lazy_lift_prop; intros.
      - apply nnrc_impish_stmt_uncross_shadow_under_preserves_core.
      - split; intros HH.
        + apply nnrc_impish_stmt_rename_md_core in HH; eauto.
          eapply nnrc_impish_stmt_uncross_shadow_under_preserves_core; eauto.
        + apply nnrc_impish_stmt_rename_md_core; eauto.
          apply nnrc_impish_stmt_uncross_shadow_under_preserves_core; trivial.
    Qed.

  End core.
  Section examples.

    Local Open Scope nnrc_impish.
    Local Open Scope string.

    Example expr1 : nnrc_impish_stmt
      := NNRCimpishLet "x"
                       (NNRCimpishConst (dnat 3))
                       (NNRCimpishLetMutColl
                          "x"
                          (NNRCimpishLetMutColl
                             "y"
                             (NNRCimpishLetMutColl
                                "x"
                                (NNRCimpishLetMut
                                   "x"
                                   (NNRCimpishAssign "x" (NNRCimpishConst (dnat 5)))
                                   (NNRCimpishPush "x" (NNRCimpishConst (dnat 4))))
                                (NNRCimpishPush "x" (NNRCimpishConst (dnat 6))))
                             (NNRCimpishPush "x" (NNRCimpishConst (dnat 7))))
                          (NNRCimpishAssign "ret" (NNRCimpishConst (dnat 8)))).
    Eval vm_compute in (nnrc_impish_stmt_uncross_shadow_under "$" expr1 nil nil nil).
    
    Example expr2 : nnrc_impish_stmt
      := NNRCimpishLet "x"
                       (NNRCimpishConst (dnat 3))
                       (NNRCimpishLetMutColl
                          "x"
                          (NNRCimpishPush "x" (NNRCimpishConst (dnat 8)))
                          (NNRCimpishAssign "ret" (NNRCimpishConst (dnat 8)))).

    Eval vm_compute in (nnrc_impish_stmt_uncross_shadow_under "$" expr2 nil nil nil).

    Example expr3 : nnrc_impish_stmt
      := (NNRCimpishLetMut
            "x"
            (NNRCimpishPush "x" (NNRCimpishConst (dnat 8)))
            (NNRCimpishAssign "ret" (NNRCimpishConst (dnat 8)))).

    Eval vm_compute in (nnrc_impish_stmt_uncross_shadow_under "$" expr3 nil nil nil).
    
  End examples.

End NNRCimpishCrossShadow.