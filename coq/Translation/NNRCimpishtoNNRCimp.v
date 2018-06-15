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

Require Import String.
Require Import List.
Require Import Bool.
Require Import Arith.
Require Import EquivDec.
Require Import Morphisms.
Require Import Permutation.
Require Import Eqdep_dec.
Require Import Program.    

Require Import Utils.
Require Import CommonRuntime.
Require Import NNRCimpishRuntime.
Require Import NNRCimpRuntime.
Require Import NNRCimpishCrossShadow.
Require Import Fresh.

Section NNRCimpishtoNNRCimp.

  Context {fruntime:foreign_runtime}.

  Fixpoint nnrc_impish_expr_to_nnrc_imp_expr (e: nnrc_impish_expr) : nnrc_imp_expr
    := match e with
       | NNRCimpishGetConstant v =>
         NNRCimpGetConstant v
       | NNRCimpishVar v =>
         NNRCimpVar v
       | NNRCimpishConst d =>
         NNRCimpConst d
       | NNRCimpishBinop bop e₁ e₂ =>
         NNRCimpBinop bop
                      (nnrc_impish_expr_to_nnrc_imp_expr e₁)
                      (nnrc_impish_expr_to_nnrc_imp_expr e₂)
       | NNRCimpishUnop uop e =>
         NNRCimpUnop uop
                     (nnrc_impish_expr_to_nnrc_imp_expr e)
       | NNRCimpishGroupBy g sl e =>
         NNRCimpGroupBy g sl
                        (nnrc_impish_expr_to_nnrc_imp_expr e)
       end.

  Lemma nnrc_impish_expr_to_nnrc_imp_expr_correct (e:nnrc_impish_expr) :
    forall h σc σ,
      nnrc_impish_expr_eval h σc σ e =
      nnrc_imp_expr_eval h σc
                         σ
                         (nnrc_impish_expr_to_nnrc_imp_expr e) .
  Proof.
    induction e; intros h σc σ; simpl; trivial
    ; try rewrite IHe
    ; try rewrite IHe1
    ; try rewrite IHe2
    ; trivial.
  Qed.

  Fixpoint nnrc_impish_stmt_to_nnrc_imp_stmt (s: nnrc_impish_stmt)
    : nnrc_imp_stmt
    := match s with
       | NNRCimpishSeq s₁ s₂ =>
         NNRCimpSeq
           (nnrc_impish_stmt_to_nnrc_imp_stmt s₁)
           (nnrc_impish_stmt_to_nnrc_imp_stmt s₂)
       | NNRCimpishLet v e s₀ =>
         NNRCimpLet v
                    (Some (nnrc_impish_expr_to_nnrc_imp_expr e))
                    (nnrc_impish_stmt_to_nnrc_imp_stmt s₀)
       | NNRCimpishLetMut v s₁ s₂ =>
         NNRCimpLet v
                    None
                    (NNRCimpSeq
                       (nnrc_impish_stmt_to_nnrc_imp_stmt s₁)
                       (nnrc_impish_stmt_to_nnrc_imp_stmt s₂))
       | NNRCimpishLetMutColl v s₁ s₂ =>
         NNRCimpLet v
                    (Some (NNRCimpConst (dcoll nil)))
                    (NNRCimpSeq
                       (nnrc_impish_stmt_to_nnrc_imp_stmt s₁)
                       (nnrc_impish_stmt_to_nnrc_imp_stmt s₂))
       | NNRCimpishAssign v e =>
         NNRCimpAssign v
                       (nnrc_impish_expr_to_nnrc_imp_expr e)
       | NNRCimpishPush v e =>
         NNRCimpAssign v
                       (NNRCimpBinop OpBagUnion
                                     (NNRCimpVar v)
                                     (NNRCimpUnop OpBag (nnrc_impish_expr_to_nnrc_imp_expr e)))
       | NNRCimpishFor v e s₀ =>
         NNRCimpFor v
                    (nnrc_impish_expr_to_nnrc_imp_expr e)
                    (nnrc_impish_stmt_to_nnrc_imp_stmt s₀)
       | NNRCimpishIf e s₁ s₂ =>
         NNRCimpIf
           (nnrc_impish_expr_to_nnrc_imp_expr e)
           (nnrc_impish_stmt_to_nnrc_imp_stmt s₁)
           (nnrc_impish_stmt_to_nnrc_imp_stmt s₂)           
       | NNRCimpishEither e x₁ s₁ x₂ s₂ =>
         NNRCimpEither
           (nnrc_impish_expr_to_nnrc_imp_expr e)
           x₁ (nnrc_impish_stmt_to_nnrc_imp_stmt s₁)
           x₂ (nnrc_impish_stmt_to_nnrc_imp_stmt s₂)
       end.

  Definition nnrc_impish_to_nnrc_imp (s: nnrc_impish)
    : nnrc_imp
    := (nnrc_impish_stmt_to_nnrc_imp_stmt (fst s), snd s).

    Definition nnrc_impish_to_nnrc_imp_top (sep:string) (s: nnrc_impish)
    : nnrc_imp
      := nnrc_impish_to_nnrc_imp (nnrc_impish_uncross_shadow sep s).

  Definition pd_bindings := list (string*option data).
  Definition mc_bindings := list (string*list data).
  Definition md_bindings := list (string*option data).
  
  Lemma nnrc_imp_stmt_eval_grouped_equiv {σ₁ σ₂} :
    grouped_equiv σ₁ σ₂ ->
    forall h σc s,
      lift2P grouped_equiv
             (nnrc_imp_stmt_eval h σc s σ₁) (nnrc_imp_stmt_eval h σc s σ₂).
  Proof.
    intros ceq h σc s.
    revert σ₁ σ₂ ceq.
    nnrc_imp_stmt_cases (induction s) Case
    ; simpl; intros σ₁ σ₂ ceq.
    - Case "NNRCimpSeq"%string.
      generalize (IHs1 _ _ ceq)
      ; intros ceq1.
      unfold lift2P in ceq1; repeat match_option_in ceq1; simpl; try contradiction.
      eauto.
    - Case "NNRCimpAssign"%string.
      repeat rewrite (grouped_equiv_lookup_equiv _ _ ceq).
      unfold var, string_eqdec.
      repeat match_destr; simpl; trivial.
      apply grouped_equiv_update_first; trivial.
    - Case "NNRCimpLet"%string.
      destruct o.
      + rewrite (grouped_equiv_lookup_equiv _ _ ceq).
        destruct (nnrc_imp_expr_eval h σc σ₂ n); simpl; trivial.
        assert (ceq1cons: grouped_equiv ((v,Some d)::σ₁) ((v,Some d)::σ₂)).
        { apply grouped_equiv_cons; trivial. }
        specialize (IHs _ _ ceq1cons).
        unfold lift2P in IHs; repeat match_option_in IHs; simpl; try contradiction.
        generalize (nnrc_imp_stmt_eval_env_domain_stack eqq); simpl; intros domeqq.
        destruct p; simpl in domeqq; invcs domeqq.
        generalize (nnrc_imp_stmt_eval_env_domain_stack eqq0); simpl; intros domeqq'.
        destruct p0; simpl in domeqq'; invcs domeqq'.
        destruct p; destruct p0; simpl in *; subst.
        apply grouped_equiv_cons_invs in IHs; tauto.
      + assert (ceq1cons: grouped_equiv ((v,None)::σ₁) ((v,None)::σ₂)).
        { apply grouped_equiv_cons; trivial. }
        specialize (IHs _ _ ceq1cons).
        unfold lift2P in IHs; repeat match_option_in IHs; simpl; try contradiction.
        generalize (nnrc_imp_stmt_eval_env_domain_stack eqq); simpl; intros domeqq.
        destruct p; simpl in domeqq; invcs domeqq.
        generalize (nnrc_imp_stmt_eval_env_domain_stack eqq0); simpl; intros domeqq'.
        destruct p0; simpl in domeqq'; invcs domeqq'.
        destruct p; destruct p0; simpl in *; subst.
        apply grouped_equiv_cons_invs in IHs; tauto.
    - Case "NNRCimpFor"%string.
      rewrite (grouped_equiv_lookup_equiv _ _ ceq).
      match_option; simpl; trivial.
      destruct d; simpl; trivial.
      clear n eqq.
      revert σ₁ σ₂ ceq.
      induction l; intros σ₁ σ₂ ceq.
      + simpl; trivial.
      + assert (ceq1cons: grouped_equiv ((v,Some a)::σ₁) ((v,Some a)::σ₂)).
        { apply grouped_equiv_cons; trivial. }
        specialize (IHs _ _ ceq1cons).
        unfold lift2P in IHs; repeat match_option_in IHs; simpl; try contradiction.
        generalize (nnrc_imp_stmt_eval_env_domain_stack eqq); simpl; intros domeqq.
        destruct p; simpl in domeqq; invcs domeqq.
        generalize (nnrc_imp_stmt_eval_env_domain_stack eqq0); simpl; intros domeqq'.
        destruct p0; simpl in domeqq'; invcs domeqq'.
        destruct p; destruct p0; simpl in *; subst.
        apply grouped_equiv_cons_invs in IHs.
        destruct IHs as [? IHs]; subst.
        eauto.
    - Case "NNRCimpIf"%string.
      rewrite (grouped_equiv_lookup_equiv _ _ ceq).
      match_destr; simpl; trivial.
      destruct d; simpl; trivial.
      destruct b; simpl; eauto.
    - rewrite (grouped_equiv_lookup_equiv _ _ ceq).
      match_destr; simpl; trivial.
      destruct d; simpl; trivial.
      + assert (ceq1cons: grouped_equiv ((v,Some d)::σ₁) ((v,Some d)::σ₂)).
        { apply grouped_equiv_cons; trivial. }
        specialize (IHs1 _ _ ceq1cons).
        unfold lift2P in IHs1; repeat match_option_in IHs1; simpl; try contradiction.
        generalize (nnrc_imp_stmt_eval_env_domain_stack eqq); simpl; intros domeqq.
        destruct p; simpl in domeqq; invcs domeqq.
        generalize (nnrc_imp_stmt_eval_env_domain_stack eqq0); simpl; intros domeqq'.
        destruct p0; simpl in domeqq'; invcs domeqq'.
        destruct p; destruct p0; simpl in *; subst.
        apply grouped_equiv_cons_invs in IHs1.
        tauto.
      + assert (ceq1cons: grouped_equiv ((v0,Some d)::σ₁) ((v0,Some d)::σ₂)).
        { apply grouped_equiv_cons; trivial. }
        specialize (IHs2 _ _ ceq1cons).
        unfold lift2P in IHs2; repeat match_option_in IHs2; simpl; try contradiction.
        generalize (nnrc_imp_stmt_eval_env_domain_stack eqq); simpl; intros domeqq.
        destruct p; simpl in domeqq; invcs domeqq.
        generalize (nnrc_imp_stmt_eval_env_domain_stack eqq0); simpl; intros domeqq'.
        destruct p0; simpl in domeqq'; invcs domeqq'.
        destruct p; destruct p0; simpl in *; subst.
        apply grouped_equiv_cons_invs in IHs2.
        tauto.
  Qed.
  

  Ltac preserve_doms :=
    unfold var in *
    ; repeat progress
             match goal with
             | [H : nnrc_impish_stmt_eval ?h ?σc ?σ₁ ?ψc₁ ?ψd₁ ?s = Some (?σ₂, _, _) |- _ ] =>
               generalize (nnrc_impish_stmt_eval_env_stack H); intros ?; subst σ₂
               ; repeat rewrite (nnrc_impish_stmt_eval_mcenv_domain_stack H) in *
               ; repeat rewrite (nnrc_impish_stmt_eval_mdenv_domain_stack H) in *
             | [H : nnrc_impish_stmt_eval ?h ?σc ?σ₁ ?ψc₁ ?ψd₁ ?s = Some _ |- _ ] =>
               repeat rewrite (nnrc_impish_stmt_eval_env_domain_stack H) in *
               ; repeat rewrite (nnrc_impish_stmt_eval_mcenv_domain_stack H) in *
               ; repeat rewrite (nnrc_impish_stmt_eval_mdenv_domain_stack H) in *
             end.

  (* The hard part is that the environments produced are not actually equal,
       rather, o     ne is an interleaved version of the other.
       This is capt  ured via the is_interleaved predicate.
   *)
  
  Definition concat_envs (envs:pd_bindings*mc_bindings*md_bindings)
    : pd_bindings
    := let '(σ, ψc, ψd) := envs in
       σ++(map_codomain (fun x => Some (dcoll x)) ψc)++ψd.

  (* hm. Maybe we should use lookup_equiv instead of Permutation in the definition 
     of grouped_equiv, since they are equivalent in this case *)
  Lemma grouped_equiv_move_to_front {A B} {dec:EqDec A eq} (l1 : list (list (A*B))) a l2 l3:
    ~ In (fst a) (domain (concat l1)) ->
    (grouped_equiv
       (concat (l1++(a::l2)::l3))
       (a::concat (l1++l2::l3))).
  Proof.
    destruct a; simpl.
    intros nin.
    unfold grouped_equiv.
    apply NoDup_lookup_equiv_Permutation
    ; try apply groupby_domain_NoDup.
    simpl.
    repeat rewrite concat_app; simpl.
    unfold lookup_equiv; intros x.
    destruct (a == x); unfold equiv, complement in *.
    - subst.
      generalize (groupby_domain_lookup_app_nin nil (concat l1)); simpl; intros re.
      repeat rewrite re by trivial; simpl.
      match_destr.
      + replace dec with (@equiv_dec _ _ _ dec) in * by trivial.
        destruct (in_dec dec x (domain ((groupby_domain (l2 ++ concat l3))))).
        * repeat rewrite lookup_update_eq_in; trivial.
          rewrite groupby_domain_equivlist in *.
          repeat rewrite domain_app, in_app_iff in *; tauto.
        * repeat rewrite lookup_nin_none; trivial
          ; rewrite domain_update_first; trivial.
          rewrite groupby_domain_equivlist in *.
          repeat rewrite domain_app, in_app_iff in *; tauto.
      + simpl; match_destr; congruence.
    - generalize (groupby_domain_lookup_app_nin (concat l1) ((a,b)::nil)); simpl; intros re.
      rewrite re by tauto.
      match_option.
      + replace dec with (@equiv_dec _ _ _ dec) in * by trivial.
        rewrite lookup_update_neq by congruence.
        trivial.
      + simpl.
        match_destr; congruence.
  Qed.


  Lemma grouped_equiv_mcenv_env a l1 l2 l3:
    ~ In (fst a) (domain l1) ->
    (grouped_equiv
       (concat_envs (l1,a::l2,l3))
       (concat_envs ((fst a, Some (dcoll (snd a)))::l1,l2,l3))).
  Proof.
    unfold concat_envs; simpl.
    intros nin.
    generalize (grouped_equiv_move_to_front (l1::nil) (fst a, Some (dcoll (snd a)))
                                            (map_codomain (fun x : list data => Some (dcoll x)) l2) (l3::nil)); simpl.
    repeat rewrite app_nil_r.
    auto.
  Qed.
  
  Lemma grouped_equiv_mdenv_env a l1 l2 l3:
    ~ In (fst a) (domain l1) ->
    ~ In (fst a) (domain l2) ->
    (grouped_equiv
       (concat_envs (l1,l2,a::l3))
       (concat_envs (a::l1,l2,l3))).
  Proof.
    unfold concat_envs; simpl.
    intros nin1 nin2.
    generalize (grouped_equiv_move_to_front (l1::(map_codomain (fun x : list data => Some (dcoll x)) l2)::nil) a l3 nil); simpl.
    repeat rewrite app_nil_r.
    intros re; apply re.
    rewrite domain_app, domain_map_codomain, in_app_iff.
    tauto.
  Qed.

  Lemma nnrc_impish_stmt_to_nnrc_imp_stmt_correct (s:nnrc_impish_stmt) :
    forall h σc σ ψc ψd,
      nnrc_impish_stmt_cross_shadow_free_under s (domain σ) (domain ψc) (domain ψd)->
      all_disjoint ((domain σ)::(domain ψc)::(domain ψd)::nil) ->
      lift2P grouped_equiv
             (lift concat_envs
                   (nnrc_impish_stmt_eval h σc σ ψc ψd s))
             (nnrc_imp_stmt_eval h σc
                                 (nnrc_impish_stmt_to_nnrc_imp_stmt s) 
                                 (concat_envs (σ, ψc, ψd))).
  Proof.
    unfold concat_envs.
    intros h σc.
    nnrc_impish_stmt_cases (induction s) Case
    ; simpl; intros σ ψc ψd sf disj.
    - Case "NNRCimpishSeq"%string.
      destruct sf as [sf1 sf2].
      specialize (IHs1 _ _ _ sf1 disj).
      unfold lift2P in IHs1; repeat match_option_in IHs1; try contradiction; simpl in *.
      + apply some_lift in eqq.
        destruct eqq as [[[??]?] eqq ?]; subst.
        rewrite eqq.
        preserve_doms.
        rewrite (IHs2 _ _ _ sf2 disj).
        rewrite (nnrc_imp_stmt_eval_grouped_equiv IHs1).
        reflexivity.
      + apply none_lift in eqq.
        rewrite eqq; simpl; trivial.
    - Case "NNRCimpishLet"%string.
      destruct sf as [disj1 [disj2 [nin1 [nin2 sf]]]].
      rewrite <- (nnrc_impish_expr_to_nnrc_imp_expr_correct n).
      rewrite nnrc_impish_expr_eval_free_env, nnrc_impish_expr_eval_free_env_tail
        by (try rewrite domain_map_codomain; tauto).
      match_option; simpl; trivial.
      specialize (IHs ((v, Some d)::σ) ψc ψd); simpl in IHs.
      cut_to IHs; trivial.
      + match_option
        ; rewrite eqq0 in IHs; simpl in *.
        * destruct p as [[??]?].
          match_option
          ; unfold var in *; rewrite eqq1 in IHs
          ; try contradiction.
          preserve_doms; simpl.
          generalize (nnrc_imp_stmt_eval_env_domain_stack eqq1).
          destruct p0; simpl; intros deq; invcs deq.
          destruct p; simpl in IHs.
          apply grouped_equiv_cons_invs in IHs.
          tauto.
        * match_option_in IHs; try contradiction.
          unfold var in *; rewrite eqq1; trivial.
      + rewrite all_disjoint3_iff in *.
        repeat split; try tauto
        ; apply disjoint_cons1; tauto.
    - Case "NNRCimpishLetMut"%string.
      destruct sf as [nin1 [nin2 [nin3 [sf1 sf2]]]].
      specialize (IHs1 _ _ ((v, None)::ψd) sf1).
      cut_to IHs1; [ | 
                     rewrite all_disjoint3_iff in *
                     ; repeat split; try tauto
                     ; apply disjoint_cons2; tauto].
      unfold lift2P in IHs1.
      repeat match_option_in IHs1; try contradiction.
      + apply some_lift in eqq.
        destruct eqq as [[[??]?] eqq ?]; subst.
        rewrite eqq.
        preserve_doms.
        generalize (nnrc_impish_stmt_eval_mdenv_domain_stack eqq)
        ; destruct m0; intros deq; invcs deq.
        destruct p; simpl in *.
        generalize (grouped_equiv_mdenv_env (s,None) σ ψc ψd); simpl
        ; intros geq1.
        generalize (grouped_equiv_mdenv_env (s,o) σ m m0); simpl
        ; intros geq2.
        rewrite geq2 in IHs1 by trivial.
        preserve_doms.
        cut_to geq1; trivial.
        generalize (nnrc_imp_stmt_eval_grouped_equiv geq1 h σc (nnrc_impish_stmt_to_nnrc_imp_stmt s1)); intros geq3.
        rewrite eqq0 in geq3.
        simpl in geq3.
        match_option_in geq3; try contradiction.
        simpl.
        rewrite geq3 in IHs1.
        rewrite H1 in *.
        specialize (IHs2 ((s, o)::σ) _ _ sf2).
        cut_to IHs2; [ | 
                       rewrite all_disjoint3_iff in *
                       ; repeat split; try tauto
                       ; apply disjoint_cons1; tauto].
        case_eq (nnrc_impish_stmt_eval h σc ((s, o) :: σ) m m0 s2)
        ; [ intros ? eqq2 | intros eqq2]
        ; rewrite eqq2 in *; simpl in *.
        * match_option_in IHs2; try contradiction.
          destruct p1 as [[??]?].
          preserve_doms; simpl.
          generalize (nnrc_imp_stmt_eval_grouped_equiv IHs1 h σc (nnrc_impish_stmt_to_nnrc_imp_stmt s2)); intros geq4.
          rewrite eqq3 in geq4; simpl in geq4.
          match_option_in geq4; try contradiction.
          rewrite geq4 in IHs2.
          generalize (nnrc_imp_stmt_eval_env_domain_stack eqq1)
          ; intros deq1.
          generalize (nnrc_imp_stmt_eval_env_domain_stack eqq4)
          ; intros deq2.
          rewrite deq2 in deq1.
          simpl in deq1.
          destruct p1; invcs deq1.
          destruct p1; simpl in *.
          apply grouped_equiv_cons_invs in IHs2.
          tauto.
        * match_option_in IHs2; try contradiction.
          generalize (nnrc_imp_stmt_eval_grouped_equiv IHs1 h σc (nnrc_impish_stmt_to_nnrc_imp_stmt s2)); intros geq4.
          rewrite eqq3 in geq4; simpl in *.
          match_option_in geq4; try contradiction.
      + apply none_lift in eqq.
        rewrite eqq; simpl.
        generalize (grouped_equiv_mdenv_env (v,None) σ ψc ψd); simpl
        ; intros geq1.
        cut_to geq1; trivial.
        generalize (nnrc_imp_stmt_eval_grouped_equiv geq1 h σc (nnrc_impish_stmt_to_nnrc_imp_stmt s1)); intros geq2.
        unfold var in *.
        rewrite eqq0 in geq2; simpl in *.
        match_option_in geq2; try contradiction.
    - Case "NNRCimpishLetMutColl"%string.
      destruct sf as [nin1 [nin2 [nin3 [sf1 sf2]]]].
      specialize (IHs1 _ ((v, [])::ψc) _ sf1).
      cut_to IHs1; [ | 
                     rewrite all_disjoint3_iff in *; simpl in *
                     ; repeat split; try tauto
                     ; try apply disjoint_cons1; try apply disjoint_cons2; tauto].
      unfold lift2P in IHs1.
      repeat match_option_in IHs1; try contradiction.
      + apply some_lift in eqq.
        destruct eqq as [[[??]?] eqq ?]; subst.
        rewrite eqq.
        preserve_doms.
        generalize (nnrc_impish_stmt_eval_mcenv_domain_stack eqq)
        ; destruct m; intros deq; invcs deq.
        destruct p; simpl in *.
        generalize (grouped_equiv_mcenv_env (s,nil) σ ψc ψd); simpl
        ; intros geq1.
        generalize (grouped_equiv_mcenv_env (s,l) σ m m0); simpl
        ; intros geq2.
        rewrite geq2 in IHs1 by trivial.
        preserve_doms.
        cut_to geq1; trivial.
        generalize (nnrc_imp_stmt_eval_grouped_equiv geq1 h σc (nnrc_impish_stmt_to_nnrc_imp_stmt s1)); intros geq3.
        rewrite eqq0 in geq3.
        simpl in geq3.
        match_option_in geq3; try contradiction.
        simpl.
        rewrite geq3 in IHs1.
        rewrite H1 in *.
        specialize (IHs2 ((s, (Some (dcoll l)))::σ) _ _ sf2).
        cut_to IHs2; [ | 
                       rewrite all_disjoint3_iff in *
                       ; repeat split; try tauto
                       ; apply disjoint_cons1; tauto].
        case_eq (nnrc_impish_stmt_eval h σc ((s, (Some (dcoll l))) :: σ) m m0 s2)
        ; [ intros ? eqq2 | intros eqq2]
        ; rewrite eqq2 in *; simpl in *.
        * match_option_in IHs2; try contradiction.
          destruct p1 as [[??]?].
          preserve_doms; simpl.
          generalize (nnrc_imp_stmt_eval_grouped_equiv IHs1 h σc (nnrc_impish_stmt_to_nnrc_imp_stmt s2)); intros geq4.
          rewrite eqq3 in geq4; simpl in geq4.
          match_option_in geq4; try contradiction.
          rewrite geq4 in IHs2.
          generalize (nnrc_imp_stmt_eval_env_domain_stack eqq1)
          ; intros deq1.
          generalize (nnrc_imp_stmt_eval_env_domain_stack eqq4)
          ; intros deq2.
          rewrite deq2 in deq1.
          simpl in deq1.
          destruct p1; invcs deq1.
          destruct p1; simpl in *.
          apply grouped_equiv_cons_invs in IHs2.
          tauto.
        * match_option_in IHs2; try contradiction.
          generalize (nnrc_imp_stmt_eval_grouped_equiv IHs1 h σc (nnrc_impish_stmt_to_nnrc_imp_stmt s2)); intros geq4.
          rewrite eqq3 in geq4; simpl in *.
          match_option_in geq4; try contradiction.
      + apply none_lift in eqq.
        rewrite eqq; simpl.
        generalize (grouped_equiv_mcenv_env (v,nil) σ ψc ψd); simpl
        ; intros geq1.
        cut_to geq1; trivial.
        generalize (nnrc_imp_stmt_eval_grouped_equiv geq1 h σc (nnrc_impish_stmt_to_nnrc_imp_stmt s1)); intros geq2.
        unfold var in *.
        simpl in *.
        rewrite eqq0 in geq2; simpl in *.
        match_option_in geq2; try contradiction.
    - Case "NNRCimpishAssign"%string.
      destruct sf as [disj1 [disj2 [nin1 nin2]]].
      rewrite <- nnrc_impish_expr_to_nnrc_imp_expr_correct.
      rewrite nnrc_impish_expr_eval_free_env, nnrc_impish_expr_eval_free_env_tail           by (try rewrite domain_map_codomain; tauto).
      match_option; simpl; trivial.
      repeat rewrite lookup_app.
      rewrite (lookup_nin_none _ nin1).
      rewrite (@lookup_nin_none _ _ _ (map_codomain (fun x : list data => Some (dcoll x)) ψc))
        by (try rewrite domain_map_codomain; trivial).
      match_option; simpl; trivial.
      repeat rewrite update_app_nin by (try rewrite domain_map_codomain; trivial).
      reflexivity.
    - Case "NNRCimpishPush"%string.
      destruct sf as [disj1 [disj2 [nin1 nin2]]].
      rewrite <- nnrc_impish_expr_to_nnrc_imp_expr_correct.
      rewrite nnrc_impish_expr_eval_free_env, nnrc_impish_expr_eval_free_env_tail           by (try rewrite domain_map_codomain; tauto).
      match_option; simpl; trivial; [ | rewrite olift2_none_r; trivial].
      repeat rewrite lookup_app.
      repeat rewrite (lookup_nin_none _ nin1).
      rewrite (lookup_nin_none _ nin2).
      repeat rewrite lookup_map_codomain.
      unfold equiv_dec, string_eqdec.
      match_option; simpl; trivial.
      rewrite (update_app_nin string_dec σ) by trivial.
      rewrite map_codomain_update_first; simpl.
      rewrite update_app_nin2 by trivial.
      unfold bunion.
      apply grouped_equiv_equiv.
    - Case "NNRCimpishFor"%string.
      destruct sf as [disj1 [disj2 [nin1 [nin2 sf]]]].
      rewrite <- nnrc_impish_expr_to_nnrc_imp_expr_correct.
      rewrite nnrc_impish_expr_eval_free_env, nnrc_impish_expr_eval_free_env_tail           by (try rewrite domain_map_codomain; tauto).
      match_option; simpl; trivial.
      destruct d; simpl; trivial.
      clear eqq.
      revert σ ψc ψd disj disj1 disj2 nin1 nin2 sf IHs.
      induction l; simpl; intros σ ψc ψd disj disj1 disj2 nin1 nin2 sf IHs; [reflexivity | ].
      generalize IHs; intros IHsH.
      specialize (IHs ((v,Some a)::σ) _ _ sf).
      cut_to IHs
      ; [ | rewrite all_disjoint3_iff in *
          ; repeat split; try tauto
          ; apply disjoint_cons1; tauto].
      unfold var in *.
      match_option
      ; rewrite eqq in IHs; simpl in IHs
      ; match_option_in IHs; try contradiction.
      destruct p as [[??]?].
      generalize (nnrc_impish_stmt_eval_env_stack eqq); intros; subst.
      generalize (nnrc_imp_stmt_eval_env_domain_stack eqq0)
      ; intros deq1.
      simpl in deq1.
      destruct p0; invcs deq1.
      destruct p; simpl in *.
      apply grouped_equiv_cons_invs in IHs.
      destruct IHs as [? geq1]; subst.
      preserve_doms.
      rewrite IHl; trivial.
      revert geq1.
      generalize (σ ++ map_codomain (fun x : list data => Some (dcoll x)) m ++ m0).
      clear.
      revert p0.
      induction l; simpl; trivial; intros p2 p1 geq1.
      assert (geq2: grouped_equiv ((s0, Some a)::p1) ((s0, Some a) :: p2)).
      { apply grouped_equiv_cons; trivial. }
      generalize (nnrc_imp_stmt_eval_grouped_equiv
                    geq2 h σc
                    (nnrc_impish_stmt_to_nnrc_imp_stmt s))
      ; intros geq3.
      unfold var in *.
      match_option; simpl in *
      ; rewrite eqq in geq3; simpl in geq3
      ; match_option_in geq3; try contradiction.
      generalize (nnrc_imp_stmt_eval_env_domain_stack eqq)
      ; intros deq1.
      generalize (nnrc_imp_stmt_eval_env_domain_stack eqq0)
      ; intros deq2.
      simpl in deq1, deq2.
      destruct p; invcs deq1.
      destruct p0; invcs deq2.
      destruct p; destruct p0; simpl in *; subst.
      apply grouped_equiv_cons_invs in geq3.
      apply IHl; tauto.
    - Case "NNRCimpishIf"%string.
      destruct sf as [disj1 [disj2 [sf1 sf2]]].
      rewrite <- nnrc_impish_expr_to_nnrc_imp_expr_correct.
      rewrite nnrc_impish_expr_eval_free_env, nnrc_impish_expr_eval_free_env_tail           by (try rewrite domain_map_codomain; tauto).
      match_option; simpl; trivial.
      destruct d; simpl; trivial.
      destruct b; simpl; auto.
    - Case "NNRCimpishEither"%string.
      destruct sf as [disj1 [disj2 [nin1 [nin2 [nin3 [nin4 [sf1 sf2]]]]]]].
      rewrite <- nnrc_impish_expr_to_nnrc_imp_expr_correct.
      rewrite nnrc_impish_expr_eval_free_env, nnrc_impish_expr_eval_free_env_tail           by (try rewrite domain_map_codomain; tauto).
      match_option; simpl; trivial.
      destruct d; simpl; trivial.
      + specialize (IHs1 ((v,Some d)::σ) _ _ sf1).
        cut_to IHs1
        ; [ | 
            rewrite all_disjoint3_iff in *
            ; repeat split; try tauto
            ; apply disjoint_cons1; tauto].
        unfold lift2P in IHs1.
        unfold var in *.
        match_option
        ; rewrite eqq0 in IHs1; simpl in IHs1
        ; match_option_in IHs1; try contradiction; simpl in *.
        destruct p as [[??]?].
        generalize (nnrc_impish_stmt_eval_env_stack eqq0); intros; subst.
        generalize (nnrc_imp_stmt_eval_env_domain_stack eqq1)
        ; intros deq1.
        simpl in deq1.
        destruct p0; invcs deq1.
        destruct p; simpl in *.
        apply grouped_equiv_cons_invs in IHs1.
        tauto.
      + specialize (IHs2 ((v0,Some d)::σ) _ _ sf2).
        cut_to IHs2
        ; [ | 
            rewrite all_disjoint3_iff in *
            ; repeat split; try tauto
            ; apply disjoint_cons1; tauto].
        unfold lift2P in IHs2.
        unfold var in *.
        match_option
        ; rewrite eqq0 in IHs2; simpl in IHs2
        ; match_option_in IHs2; try contradiction; simpl in *.
        destruct p as [[??]?].
        generalize (nnrc_impish_stmt_eval_env_stack eqq0); intros; subst.
        generalize (nnrc_imp_stmt_eval_env_domain_stack eqq1)
        ; intros deq1.
        simpl in deq1.
        destruct p0; invcs deq1.
        destruct p; simpl in *.
        apply grouped_equiv_cons_invs in IHs2.
        tauto.
  Qed.
  
  Theorem nnrc_impish_to_nnrc_imp_correct (s:nnrc_impish) :
    forall h σc,
      nnrc_impish_cross_shadow_free s ->
      nnrc_impish_eval h σc s = nnrc_imp_eval h σc (nnrc_impish_to_nnrc_imp s).
  Proof.
    unfold nnrc_impish_cross_shadow_free.
    intros h σc sf.
    destruct s as [s ret].
    generalize (nnrc_impish_stmt_to_nnrc_imp_stmt_correct s h σc nil nil ((ret,None)::nil)); simpl; intros HH.
    cut_to HH; trivial.
    - unfold var in *; match_option
      ; rewrite eqq in HH; simpl in HH.
      + match_option_in HH; try contradiction.
        destruct p as [[??]?].
        preserve_doms.
        generalize (nnrc_impish_stmt_eval_mcenv_domain_stack eqq)
        ; intros deq1.
        generalize (nnrc_impish_stmt_eval_mdenv_domain_stack eqq)
        ; intros deq2.
        generalize (nnrc_imp_stmt_eval_env_domain_stack eqq0)
        ; intros deq3.
        destruct m0; simpl in *; invcs deq2.
        destruct p0; simpl in *; invcs deq3.
        symmetry in H1; apply domain_nil in H1.
        symmetry in H2; apply domain_nil in H2.
        symmetry in deq1; apply domain_nil in deq1.
        subst.
        simpl in *.
        apply grouped_equiv_singleton in HH.
        invcs HH.
        trivial.
      + match_option_in HH; try contradiction.
    - apply all_disjoint3_iff; simpl.
      eauto.
  Qed.

    Theorem nnrc_impish_to_nnrc_imp_top_correct (sep:string) (s:nnrc_impish) :
    forall h σc,
      nnrc_impish_eval_top h σc s = nnrc_imp_eval_top h σc (nnrc_impish_to_nnrc_imp_top sep s).
    Proof.
      intros.
      unfold nnrc_impish_eval_top, nnrc_imp_eval_top, nnrc_impish_to_nnrc_imp_top.
      f_equal.
      rewrite <- nnrc_impish_to_nnrc_imp_correct.
      - rewrite nnrc_impish_uncross_shadow_eval; trivial.
      - apply nnrc_impish_uncross_shadow_free.
    Qed.

  Section Core.

    Lemma nnrc_impish_expr_to_nnrc_imp_expr_preserves_core {e:nnrc_impish_expr} :
      nnrc_impish_exprIsCore e <->
      nnrc_imp_exprIsCore (nnrc_impish_expr_to_nnrc_imp_expr e).
    Proof.
      induction e; simpl; tauto.
    Qed.

    Lemma nnrc_impish_stmt_to_nnrc_imp_stmt_preserves_core {s:nnrc_impish_stmt} :
      nnrc_impish_stmtIsCore s <->
      nnrc_imp_stmtIsCore (nnrc_impish_stmt_to_nnrc_imp_stmt s).
    Proof.
      induction s; simpl;
        repeat rewrite nnrc_impish_expr_to_nnrc_imp_expr_preserves_core
        ; tauto.
    Qed.

    Theorem nnrc_impish_to_nnrc_imp_preserves_core {s:nnrc_impish} :
      nnrc_impishIsCore s <->
      nnrc_impIsCore (nnrc_impish_to_nnrc_imp s).
    Proof.
      destruct s; simpl.
      apply nnrc_impish_stmt_to_nnrc_imp_stmt_preserves_core.
    Qed.

    Theorem nnrc_impish_to_nnrc_imp_top_preserves_core sep {s:nnrc_impish} :
      nnrc_impishIsCore s <->
      nnrc_impIsCore (nnrc_impish_to_nnrc_imp_top sep s).
    Proof.
      unfold nnrc_impish_to_nnrc_imp_top.
      rewrite <- nnrc_impish_to_nnrc_imp_preserves_core.
      rewrite nnrc_impish_uncross_shadow_preserves_core.
      tauto.
    Qed.

    Program Definition nnrc_impish_core_to_nnrc_imp_core_top
            sep (s:nnrc_impish_core) : nnrc_imp_core
      := nnrc_impish_to_nnrc_imp_top sep s.
    Next Obligation.
      destruct s; simpl.
      apply nnrc_impish_to_nnrc_imp_top_preserves_core; trivial.
    Qed.

    Theorem nnrc_impish_core_to_nnrc_imp_core_correct
            h σc sep (s:nnrc_impish_core) :
      nnrc_impish_core_eval_top h σc s
      = nnrc_imp_core_eval_top h σc (nnrc_impish_core_to_nnrc_imp_core_top sep s).
    Proof.
      destruct s as [q pf].
      unfold nnrc_impish_core_eval_top, nnrc_imp_core_eval_top.
      unfold nnrc_impish_core_eval, nnrc_imp_core_eval.
      simpl proj1_sig.
      apply nnrc_impish_to_nnrc_imp_top_correct.
    Qed.

  End Core.

End NNRCimpishtoNNRCimp.