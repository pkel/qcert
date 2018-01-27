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

(** Support for defining and reasoning about sub-lists. *)

Section Sublist.
  Require Import List.
  Require Import ListSet.
  Require Import Bool.
  Require Import Permutation.
  Require Import Equivalence.
  Require Import Morphisms.
  Require Import Setoid.
  Require Import EquivDec.
  Require Import RelationClasses.
  Require Import Omega.
  Require Import CoqLibAdd.
  Require Import ListAdd.
  Require Import SortingAdd.
  Require Import Assoc.

  (** * Sublists *)
  
  Section sublist.
    Context {A:Type}.
    Inductive sublist : list A -> list A -> Prop :=
    | sublist_nil : sublist nil nil
    | sublist_cons :
        forall x l1 l2, sublist l1 l2 -> sublist (x::l1) (x::l2)
    | sublist_skip : 
        forall x l1 l2, sublist l1 l2 -> sublist l1 (x::l2)
    .
    
    Hint Constructors sublist.
    
    Lemma sublist_In {l1 l2:list A} :
      sublist l1 l2 -> forall x, In x l1 -> In x l2.
    Proof.
      induction 1; simpl; intuition.
    Qed.

    Lemma sublist_nil_l l : sublist nil l.
    Proof.
      induction l; intuition.
    Qed.

    Lemma sublist_nil_r l : sublist l nil -> l = nil.
    Proof.
      inversion 1; trivial.
    Qed.
    
    Global Instance sublist_incl_sub : subrelation sublist (@incl A).
    Proof.
      intros l1 l2 subl x inx.
      eapply sublist_In; eauto.
    Qed.

    
    Hint Immediate sublist_nil_l.
    
    Global Instance sublist_pre : PreOrder sublist.
    Proof.
      constructor; red; intros l; [induction l; intuition | ].
      intros y z; revert l y. induction z.
      - intros.
        apply sublist_nil_r in H0; subst.
        apply sublist_nil_r in H; subst.
        auto.
      - intros.
        inversion H0; subst; eauto 3.
        inversion H; subst; eauto 3.
    Qed.

    Lemma sublist_trans l1 l2 l3:
      sublist l1 l2 -> sublist l2 l3 -> sublist l1 l3.
    Proof.
      intros.
      apply (PreOrder_Transitive l1 l2 l3); assumption.
    Qed.
    
    Lemma sublist_length {l1 l2} : sublist l1 l2 -> length l1 <= length l2.
    Proof.
      revert l1. induction l2; simpl; intros.
      - apply sublist_nil_r in H; subst; auto.
      - inversion H; subst; simpl; auto with arith.
    Qed.

    Lemma sublist_length_eq {l1 l2} :
      sublist l1 l2 -> length l1 = length l2 -> l1 = l2.
    Proof.
      revert l1; induction l2; simpl.
      - intros; apply sublist_nil_r in H; subst; auto.
      - inversion 1; subst; simpl; intros.
        + f_equal; auto with arith.
        + apply sublist_length in H2. omega.
     Qed.

    Global Instance sublist_antisymm : Antisymmetric (list A) eq sublist.
    Proof.
      red; intros x y sub1 sub2.
      apply (sublist_length_eq sub1).
      apply sublist_length in sub1.
      apply sublist_length in sub2.
      omega.
    Qed.

    Global Instance sublist_part : PartialOrder eq sublist.
    Proof.
      unfold PartialOrder, relation_equivalence, relation_conjunction,
      predicate_equivalence, predicate_intersection, Basics.flip; simpl.
      split; intros; subst; trivial; intuition.
      apply sublist_antisymm; trivial.
    Qed.
    
    Require Import Morphisms.
    Require Import Program.Basics.
    Global Instance sublist_NoDup : Proper (sublist --> impl) (@NoDup A).
    Proof.
      repeat red; unfold flip.
      induction x; simpl; intros.
      - apply sublist_nil_r in H; subst; auto.
      - inversion H0; subst.
        inversion H; subst; auto.
        constructor; auto.
        intro inn; apply H3.
        eapply sublist_In; eauto.
    Qed.

    Lemma sublist_app {a1 b1 a2 b2:list A}:
      sublist a1 b1 ->
      sublist a2 b2 ->
      sublist (a1 ++ a2) (b1 ++ b2).
    Proof.
      Hint Constructors sublist.
      revert a1 a2 b2.
      induction b1; inversion 1; subst; simpl; eauto.
    Qed.

    Lemma sublist_app_l (l1 l2:list A) : sublist l1 (l1 ++ l2).
    Proof.
      induction l1; simpl.
      - apply sublist_nil_l.
      - apply sublist_cons. trivial.
    Qed.

    Lemma sublist_app_r (l1 l2:list A) : sublist l2 (l1 ++ l2).
    Proof.
      induction l1; simpl.
      - reflexivity.
      - apply sublist_skip. trivial.
    Qed.

    Lemma filter_sublist f (l:list A) : sublist (filter f l) l.
    Proof.
      induction l; simpl.
      - reflexivity.
      - match_destr.
        + apply sublist_cons; trivial.
        + apply sublist_skip; trivial.
    Qed.
   
  End sublist.

  Hint Constructors sublist.

  Lemma cut_down_to_sublist
        {A B} {dec:EqDec A eq}
        (l:list (A*B)) (l2:list A) :
    sublist (cut_down_to l l2) l.
  Proof.
    unfold cut_down_to.
    apply filter_sublist.
  Qed.

  Lemma sublist_map {A B} {l1 l2} (f:A->B) :
    sublist l1 l2 -> sublist (map f l1) (map f l2).
  Proof.
    revert l1; induction l2; intros.
    - apply sublist_nil_r in H; subst; simpl; auto.
    - inversion H; subst; simpl; auto.
  Qed.

  Lemma sublist_domain {A B} {l1 l2:list(A*B)} :
    sublist l1 l2 -> sublist (domain l1) (domain l2).
  Proof.
    intros; apply sublist_map; trivial.
  Qed.

  Lemma sublist_set_inter {A} dec (l1 l2 l3:list A):
    sublist l1 l3 ->
    sublist (set_inter dec l1 l2) l3.
  Proof.
    revert l1 l2.
    induction l3; intros.
    - apply sublist_nil_r in H; subst; simpl; trivial.
    - inversion H; subst.
      + simpl.
        match_destr; eauto.
      + eauto.
  Qed.
  
  Global Instance Forall_sublist {A} {P:A->Prop} :
    Proper (sublist --> impl) (Forall P).
  Proof.
    repeat red; unfold flip.
    induction x; intros.
    - apply sublist_nil_r in H; subst; trivial.
    - inversion H0; clear H0; subst.
      inversion H; clear H; subst; auto.
  Qed.

  Lemma forallb_sublist {A} f (l1 l2:list A) :
    sublist l1 l2 ->
    forallb f l2 = true ->
    forallb f l1 = true.
  Proof.
    intros.
    eapply forallb_incl; eauto.
    apply sublist_incl_sub; trivial.
  Qed.

  Lemma forallb_ordpairs_sublist {A} f (l1 l2:list A) :
    sublist l1 l2 ->
    forallb_ordpairs f l2 = true ->
    forallb_ordpairs f l1 = true.
  Proof.
    revert l2.
    induction l1; simpl; trivial; intros.
    induction l2; simpl; inversion H; subst; simpl in * ;
      rewrite andb_true_iff in *.
    - rewrite (IHl1 l2); intuition.
      eapply forallb_sublist; eauto.
    - intuition.
  Qed.

  Lemma forallb_ordpairs_refl_sublist {A} f (l1 l2:list A) :
    sublist l1 l2 ->
    forallb_ordpairs_refl f l2 = true ->
    forallb_ordpairs_refl f l1 = true.
  Proof.
    repeat rewrite forallb_ordpairs_refl_conj.
    repeat rewrite andb_true_iff; intuition.
    - eapply forallb_ordpairs_sublist; eauto.
    - eapply forallb_sublist; eauto.
  Qed.

  Global Instance StronglySorted_sublist {A} {R:A->A->Prop} : Proper (sublist --> impl) (StronglySorted R).
  Proof.
    repeat red; unfold flip.
    induction x; simpl; intros.
    - apply sublist_nil_r in H; subst; trivial.
    - inversion H0; clear H0; subst.
      inversion H; clear H; subst; auto 3.
      rewrite <- H2 in H4; constructor; auto.
  Qed.

  Lemma is_list_sorted_sublist {A} {R} {Rdec} {l l':list A}
        `{Transitive A R} :
    @is_list_sorted A R Rdec l = true ->
    sublist l' l ->
    is_list_sorted Rdec l' = true.
  Proof.
    repeat rewrite sorted_StronglySorted by auto.
    intros ? sl.
    rewrite sl.
    trivial.
  Qed.

  Hint Immediate sublist_nil_l.

  Lemma StronglySorted_incl_sublist {A R l1 l2} `{EqDec A eq} `{StrictOrder A R} : 
    StronglySorted R l1 ->
    StronglySorted R l2 ->
    (forall x : A, In x l1 -> In x l2) ->
    sublist l1 l2.
  Proof.
    intros. 
    generalize (StronglySorted_NoDup _ H1).
    generalize (StronglySorted_NoDup _ H2).
    revert l1 H1 H2 H3.
    induction l2; simpl.
    - destruct l1; simpl; auto 1.
      intros. specialize (H3 a); intuition.
    - intros. inversion H2; subst.
      destruct l1; auto 1.
      simpl in *.
      inversion H1; subst.
      inversion H4; inversion H5; subst.
      destruct (a == a0); unfold Equivalence.equiv, complement in *; subst.
      unfold equiv in *.
      + apply sublist_cons. apply IHl2; trivial.
        intros x inn.
        specialize (H3 x); intuition. subst; intuition.
      + apply sublist_skip. apply IHl2; auto.
        simpl; intros x inn.
        generalize (H3 a0).
        specialize (H3 _ inn). intuition; subst.
        * intuition.
        * rewrite Forall_forall in H9,H11.
          specialize (H11 _ H3).
          specialize (H9 _ H14).
          rewrite H9 in H11.
          eelim irreflexivity; eauto.
  Qed.

  Lemma Sorted_incl_sublist {A R l1 l2} `{EqDec A eq} `{StrictOrder A R}: 
    Sorted R l1 ->
    Sorted R l2 ->
    (forall x : A, In x l1 -> In x l2) ->
    sublist l1 l2.
  Proof.
    intros.
    apply StronglySorted_incl_sublist; trivial;
    apply Sorted_StronglySorted; trivial; apply StrictOrder_Transitive.
  Qed.

  Lemma Sorted_incl_both_eq {A R l1 l2} `{EqDec A eq} `{StrictOrder A R}: 
    Sorted R l1 ->
    Sorted R l2 ->
    (forall x : A, In x l1 -> In x l2) ->
    (forall x : A, In x l2 -> In x l1) ->
    l1 = l2.
  Proof.
    intros.
    apply sublist_antisymm; apply Sorted_incl_sublist; trivial.
  Qed.

  Lemma insertion_sort_equivlist_strong {A R R_dec} `{EqDec A eq} `{StrictOrder A R} l l' (contr:asymmetric_over R l) :
    equivlist l l' ->
    @insertion_sort A R R_dec l = 
    @insertion_sort A R R_dec l'.
  Proof.
    intros.
    generalize (equivlist_insertion_sort_strong R_dec contr H1); intros.
    apply Sorted_incl_both_eq; try apply insertion_sort_Sorted.
    intros. eapply equivlist_in; eauto.
    intros. symmetry in H2. eapply equivlist_in; eauto.
  Qed.

  Lemma insertion_sort_equivlist {A R R_dec} `{EqDec A eq} `{StrictOrder A R}  (contr:forall x y,  ~R x y -> ~R y x -> x = y) l l' :
    equivlist l l' ->
    @insertion_sort A R R_dec l = 
    @insertion_sort A R R_dec l'.
  Proof.
    intros.
    apply insertion_sort_equivlist_strong; eauto.
    eapply asymmetric_asymmetric_over; trivial.
  Qed.

  Lemma sublist_skip_l {A} (a:A) {l1 l2} :
    sublist (a::l1) l2 ->
    sublist l1 l2.
  Proof.
    revert l1.
    induction l2; inversion 1; subst.
    - apply sublist_skip; trivial.
    - apply sublist_skip. eauto.
  Qed.

  Lemma sublist_cons_eq_inv {A a l1 l2} :
    @sublist A (a::l1) (a::l2) ->
    sublist l1 l2.
  Proof.
    inversion 1; subst; trivial.
    rewrite <- H2. apply sublist_skip; reflexivity.
  Qed.
  
  Lemma sublist_filter {A} (f:A->bool) {l1 l2} :
    sublist l1 l2 -> sublist (filter f l1) (filter f l2).
  Proof.
    revert l1. induction l2; simpl; intros.
    - apply sublist_nil_r in H; subst; simpl; auto 1.
    - inversion H; subst.
      + specialize (IHl2 _ H2); simpl.
        destruct (f a); [apply sublist_cons | ]; congruence.
      + specialize (IHl2 _ H2); simpl.
        destruct (f a); [apply sublist_skip | ]; congruence.
  Qed.
  
  Lemma sublist_cons_inv' {A B l1 a l2} :
    sublist l1(a::l2) ->
    NoDup (@domain A B (a::l2)) ->
    (exists l',
        l1 = a::l' /\ sublist l' l2)
    \/
    (~ In (fst a) (domain l1)
     /\ sublist l1 l2).
  Proof.
    inversion 1; subst.
    intuition; eauto.
    intros; right. split; trivial.
    generalize (sublist_In (sublist_domain H2)); intros inn.
    inversion H0; subst.
    auto.
  Qed.

  Lemma sublist_cons_inv {A B l1 a l2 R R_dec} `{StrictOrder A R}:
    sublist l1(a::l2) ->
    @is_list_sorted A R R_dec (@domain _ B (a::l2)) = true ->
    (exists l',
        l1 = a::l' /\ sublist l' l2)
    \/
    (~ In (fst a) (domain l1)
     /\ sublist l1 l2).
  Proof.
    inversion 1; subst.
    intuition; eauto.
    intros; right. split; trivial.
    generalize (sublist_In (sublist_domain H3)); intros inn.
    apply is_list_sorted_NoDup in H1; eauto.
    inversion H1; subst.
    auto.
  Qed.

  Lemma sublist_cons_inv_simple {A l1} {a:A} {l2} :
    sublist l1(a::l2) ->
    NoDup (a::l2) ->
    (exists l',
       l1 = a::l' /\ sublist l' l2)
    \/
    (~ In a l1
     /\ sublist l1 l2).
  Proof.
    inversion 1; subst.
    intuition; eauto.
    intros; right. split; trivial.
    generalize (sublist_In H2); intros inn.
    inversion H0; subst.
    auto.
  Qed.
  
  Lemma sublist_dec {A}  {dec:EqDec A eq} (l1 l2 : list A) :
    {sublist l1 l2} + { ~ sublist l1 l2}.
  Proof.
    revert l1.
    induction l2; intros l1; destruct l1.
    - left; trivial.
    - right; inversion 1.
    - left; apply sublist_nil_l.
    - destruct (a0 == a).
      + destruct (IHl2 l1).
        * left. rewrite e. eauto.
        * right. rewrite e. intro subl.
          apply sublist_cons_eq_inv in subl.
          intuition.
      + destruct (IHl2 (a0::l1)).
        * left. apply sublist_skip; trivial.
        * right; inversion 1; subst; intuition.
  Defined.

  Lemma sublist_remove {A} dec (x:A) l1 l2 :
    sublist l1 l2 ->
    sublist (remove dec x l1) (remove dec x l2).
  Proof.
    revert l1. induction l2; simpl; intros.
    - apply sublist_nil_r in H; subst; simpl; auto 1.
    - inversion H; subst.
      + specialize (IHl2 _ H2); simpl.
        match_destr. apply sublist_cons; auto.
      + specialize (IHl2 _ H2); simpl.
        match_destr.
        apply sublist_skip; auto.
  Qed.

  Lemma sublist_nin_remove {A} dec (l1 l2:list (A)) a :
    ~ In a l1 -> sublist l1 l2 -> sublist l1 (remove dec a l2).
  Proof.
    intros.
    apply (sublist_remove dec a) in H0.
    rewrite (nin_remove dec l1 a) in H0 by trivial.
    trivial.
  Qed.

  
  Lemma assoc_lookupr_nodup_sublist {A B} {R_dec:forall a a' : A, {a = a'} + {a <> a'}} {l1 l2} {a:A} {b:B} :
    NoDup (domain l2) ->
    sublist l1 l2 ->
    assoc_lookupr R_dec l1 a = Some b ->
    assoc_lookupr R_dec l2 a = Some b.
  Proof.
    revert a b l1.  induction l2; simpl; intros.
    - apply sublist_nil_r in H0; subst. simpl in *; discriminate.
    - destruct a; simpl.
      generalize (sublist_cons_inv' H0 H).
      inversion H; subst.
      destruct 1.
      + destruct H2 as [? [??]]; subst.
        simpl in H1.
        case_eq (assoc_lookupr R_dec x a0); [ intros? eqq | intros eqq]
        ; rewrite eqq in H1. 
        * inversion H1; clear H1; subst.
          rewrite (IHl2 _ _ _ H5 H3 eqq); trivial.
        * destruct (R_dec a0 a); inversion H1; subst.
          case_eq (assoc_lookupr R_dec l2 a); trivial.
          intros.
          apply assoc_lookupr_in in H2.
          apply in_dom in H2.
          congruence.
      + simpl in H2. destruct H2.
        rewrite (IHl2 _ _ _ H5 H3 H1); trivial.
  Qed.

  
    Lemma insertion_sort_insert_sublist_self {A R}
        R_dec (a:A) l :
    sublist l (@insertion_sort_insert A R R_dec a l).
  Proof.
    induction l; simpl.
    - apply sublist_skip; reflexivity.
    - match_destr.
      + apply sublist_skip; apply sublist_cons; reflexivity.
      + match_destr; try reflexivity.
        apply sublist_cons.
        eauto.
  Qed.

  Lemma insertion_sort_insert_sublist_prop {A R} {rstrict:StrictOrder R}
        (trich:forall a b, {R a b} + {a = b} + {R b a})
        R_dec a l1 l2:
  is_list_sorted R_dec l2 = true ->
  sublist l1 l2 ->
  sublist (@insertion_sort_insert A R R_dec a l1)
          (@insertion_sort_insert A R R_dec a l2).
Proof.
  unfold Proper, respectful; intros; subst.
  revert l1 H H0. induction l2.
  - inversion 2; subst; simpl; reflexivity.
  - intros. apply sublist_cons_inv_simple in H0;
      [ | apply (is_list_sorted_NoDup R_dec); trivial].
    destruct H0 as [[?[??]]|[??]]; subst.
    + simpl. match_destr.
      * do 2 apply sublist_cons; eauto.
      * match_destr; apply sublist_cons; trivial.
        apply IHl2; trivial.
        eapply is_list_sorted_cons_inv; eauto.
    + simpl. match_destr.
      * rewrite IHl2; trivial; [| eapply is_list_sorted_cons_inv; eauto].
        rewrite insertion_sort_insert_forall_lt.
        { apply sublist_cons; apply sublist_skip; reflexivity. }
        apply sorted_StronglySorted in H; [| eapply StrictOrder_Transitive].
        inversion H; subst.
        revert H5. apply Forall_impl; intros.
        rewrite <- H2; trivial.
      * specialize (IHl2 l1).
        cut_to IHl2; trivial; [| eapply is_list_sorted_cons_inv; eauto].
        match_destr; [apply sublist_skip; trivial | ].
        destruct (trich a a0) as [[?|?]|?]; try congruence.
        subst.
        rewrite insertion_sort_insert_forall_lt; [ apply sublist_cons; trivial | ].
        rewrite H1.
        apply sorted_StronglySorted in H; [| eapply StrictOrder_Transitive].
        inversion H; subst. trivial.
Qed.

Lemma insertion_sort_sublist_proper {A R} {rstrict:StrictOrder R}
        (trich:forall a b, {R a b} + {a = b} + {R b a}) R_dec :
  Proper (sublist ==> sublist) (@insertion_sort A R R_dec).
Proof.
  unfold Proper, respectful; intros.
  revert x H. induction y; simpl; inversion 1; subst; simpl; trivial.
  - specialize (IHy _ H2).
    apply insertion_sort_insert_sublist_prop; trivial.
    apply is_list_sorted_Sorted_iff.
    apply insertion_sort_Sorted.
  - rewrite IHy; trivial.
    apply insertion_sort_insert_sublist_self.
Qed.
        
Lemma sublist_of_sorted_sublist {A R} {rstrict:StrictOrder R}
      (trich:forall a b, {R a b} + {a = b} + {R b a})
      R_dec {l1 l2} : 
  sublist (@insertion_sort A R R_dec l1) l2 ->
  forall l1',
        sublist l1' l1 -> 
        sublist (insertion_sort R_dec l1') l2.
Proof.
  intros.
  transitivity (insertion_sort R_dec l1); trivial.
  apply insertion_sort_sublist_proper; trivial.
Qed.


End Sublist.
Hint Immediate sublist_nil_l.

