(** * Coq Proof Environment : Example *)

Theorem negation_fn_applied_twice :
  forall (f : bool -> bool),
  (forall (x : bool), f x = (negb x)) ->
  forall (b : bool), f (f b) = b.
Proof.
  intros f H [].
  - rewrite -> H; rewrite -> H. reflexivity.
  - rewrite -> H; rewrite -> H. reflexivity. Qed.