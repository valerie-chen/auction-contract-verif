(* *********************************************************************)
(*                                                                     *)
(*              The Compcert verified compiler                         *)
(*                                                                     *)
(*          Xavier Leroy, INRIA Paris-Rocquencourt                     *)
(*                                                                     *)
(*  Copyright Institut National de Recherche en Informatique et en     *)
(*  Automatique.  All rights reserved.  This file is distributed       *)
(*  under the terms of the GNU General Public License as published by  *)
(*  the Free Software Foundation, either version 2 of the License, or  *)
(*  (at your option) any later version.  This file is also distributed *)
(*  under the terms of the INRIA Non-Commercial License Agreement.     *)
(*                                                                     *)
(* *********************************************************************)

(** Tactics to generate Boolean-valued equalities *)

(** The [decide equality] tactic can generate a term of type
[forall (x y: A), {x=y} + {x<>y}] if [A] is an inductive type.
This term is a decidable equality function.

Similarly, this module defines a [boolean_equality] tactic that generates
a term of type [A -> A -> bool].  This term is a Boolean-valued equality
function over the inductive type [A].  Two internal tactics generate
proofs that show the correctness of this equality function [f], namely
proofs of the following two properties:
- [forall (x: A), f x x = true]
- [forall (x y: A), f x y = true -> x = y]

Finally, the [decide_equality_from f] tactic wraps [f] (the Boolean equality
generated by [boolean_equality]) and those proofs together, producing
a decidable equality of type [forall (x y: A), {x=y} + {x<>y}].

The advantage of the present tactics over the standard [decide equality]
tactic is that the former produce smaller transparent definitions than
the latter.

For a type [A] that has N constructors, [decide equality] produces a
single term of size O(N^3), which must be kept transparent so that
it computes and extracts as expected.  Given such a big transparent
definition, the virtual machine compiler of Coq produces very big
chunks of VM code, causing memory overflows on 32-bit platforms.

In contrast, the term produced by [boolean_equality] has size O(N^2)
only (so to speak).  The proofs that this term is a correct boolean
equality are still O(N^3), but those proofs are opaque and do not need
to be compiled to VM code.  Only the boolean equality itself is defined
transparently and compiled.

The present tactics also have some restrictions:
- Constructors must have at most 4 arguments.
- Decidable equalities must be provided (as hypotheses in the context)
  for all the types [T] of constructor arguments other than type [A].
- They probably do not work for mutually-defined inductive types.
*)

Require Import AV.Coqlib.

Module BE.

Definition bool_eq {A: Type} (x y: A) : Type := bool.

Ltac bool_eq_base x y :=
  change (bool_eq x y);
  match goal with
  | [ H: forall (x y: ?A), bool |- @bool_eq ?A x y ] => exact (H x y)
  | [ H: forall (x y: ?A), {x=y} + {x<>y}  |- @bool_eq ?A x y ] => exact (proj_sumbool (H x y))
  | _ => idtac
  end.

Ltac bool_eq_case :=
  match goal with
  | |- bool_eq (?C ?x1 ?x2 ?x3 ?x4) (?C ?y1 ?y2 ?y3 ?y4) =>
         refine (_ && _ && _ && _); [bool_eq_base x1 y1|bool_eq_base x2 y2|bool_eq_base x3 y3|bool_eq_base x4 y4]
  | |- bool_eq (?C ?x1 ?x2 ?x3) (?C ?y1 ?y2 ?y3) =>
         refine (_ && _ && _); [bool_eq_base x1 y1|bool_eq_base x2 y2|bool_eq_base x3 y3]
  | |- bool_eq (?C ?x1 ?x2) (?C ?y1 ?y2) =>
         refine (_ && _); [bool_eq_base x1 y1|bool_eq_base x2 y2]
  | |- bool_eq (?C ?x1) (?C ?y1) => bool_eq_base x1 y1
  | |- bool_eq ?C ?C => exact true
  | |- bool_eq _ _ => exact false
  end.

Ltac bool_eq :=
  match goal with
  | [ |- ?A -> ?A -> bool ] =>
      let f := fresh "rec" in let x := fresh "x" in let y := fresh "y" in
      fix f 1; intros x y; change (bool_eq x y); destruct x, y; bool_eq_case
  | [ |- _ -> _ ] =>
      let eq := fresh "eq" in intro eq; bool_eq
  end.

Lemma proj_sumbool_is_true:
  forall (A: Type) (f: forall (x y: A), {x=y} + {x<>y}) (x: A),
  proj_sumbool (f x x) = true.
Proof.
  intros. unfold proj_sumbool. destruct (f x x). auto. elim n; auto.
Qed.

Ltac bool_eq_refl_case :=
  match goal with
  | [ |- true = true ] => reflexivity
  | [ |- proj_sumbool _ = true ] => apply proj_sumbool_is_true
  | [ |- _ && _ = true ] => apply andb_true_iff; split; bool_eq_refl_case
  | _ => auto
  end.

Ltac bool_eq_refl :=
  let H := fresh "Hrec" in let x := fresh "x" in
  fix H 1; intros x; destruct x; simpl; bool_eq_refl_case.

Lemma false_not_true:
  forall (P: Prop), false = true -> P.
Proof.
  intros. discriminate.
Qed.

Lemma proj_sumbool_true:
  forall (A: Type) (x y: A) (a: {x=y} + {x<>y}),
  proj_sumbool a = true -> x = y.
Proof.
  intros. destruct a. auto. discriminate.
Qed.

Ltac bool_eq_sound_case :=
  match goal with
  | [ H: false = true |- _ ] => exact (false_not_true _ H)
  | [ H: _ && _ = true |- _ ] => apply andb_prop in H; destruct H; bool_eq_sound_case
  | [ H: proj_sumbool ?a = true |- _ ] => apply proj_sumbool_true in H; bool_eq_sound_case
  | [ |- ?C ?x1 ?x2 ?x3 ?x4 = ?C ?y1 ?y2 ?y3 ?y4 ] => apply f_equal4; auto
  | [ |- ?C ?x1 ?x2 ?x3 = ?C ?y1 ?y2 ?y3 ] => apply f_equal3; auto
  | [ |- ?C ?x1 ?x2 = ?C ?y1 ?y2 ] => apply f_equal2; auto
  | [ |- ?C ?x1 = ?C ?y1 ] => apply f_equal; auto
  | [ |- ?x = ?x ] => reflexivity
  | _ => idtac
  end.

Ltac bool_eq_sound :=
  let Hrec := fresh "Hrec" in let x := fresh "x" in let y := fresh "y" in
  fix Hrec 1; intros x y; destruct x, y; simpl; intro; bool_eq_sound_case.

Lemma dec_eq_from_bool_eq:
  forall (A: Type) (f: A -> A -> bool)
     (f_refl: forall x, f x x = true) (f_sound: forall x y, f x y = true -> x = y),
  forall (x y: A), {x=y} + {x<>y}.
Proof.
  intros. destruct (f x y) eqn:E.
  left. apply f_sound. auto.
  right; red; intros. subst y. rewrite f_refl in E. discriminate.
Defined.

End BE.

(** Applied to a goal of the form [t -> t -> bool], the [boolean_equality]
  tactic defines a function with that type, returning [true] iff the two
  arguments of type [t] are equal.  [t] must be an inductive type.
  For any type [u] other than [t] that appears in arguments of constructors
  of [t], a decidable equality over [u] must be provided, as an hypothesis
  of type [forall (x y: u), {x=y}+{x<>y}]. *)
Ltac boolean_equality := BE.bool_eq.

(** Given a function [beq] of type [t -> t -> bool] produced by [boolean_equality],
  the [decidable_equality_from beq] produces a decidable equality with type
  [forall (x y: t], {x=y}+{x<>y}. *)

Ltac decidable_equality_from beq :=
  apply (BE.dec_eq_from_bool_eq _ beq); [abstract BE.bool_eq_refl|abstract BE.bool_eq_sound].
