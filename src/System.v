Require Import AV.Auction.
Require Import AV.Contract.
Require Import AV.Coqlib.
Require Import AV.Maps.

Require Import Bool.
Require Import Coq.Lists.List.
Require Import Omega.
Require Import ZArith.BinInt.

Open Scope positive_scope.
Open Scope list_scope.

(* Redefine from other modules for readability. *)

(* Definition ANState := Auction.State.
Definition ANStateList := Auction.StateList.

Definition ContractTime := Contract.Time.
Definition ContractLog := Contract.BidLog. *)

(* world states *)

Definition WorldState := (Auction.StateList * Contract.Time * Contract.BidLog)%type.
Definition WorldStateList := list WorldState.

Definition init_ws (beneficiary auctionStart biddingTime time : positive) : WorldState :=
  let ast := Auction.init beneficiary auctionStart biddingTime in
    (ast, time, nil).

(* step relations *)

Inductive step : WorldState -> WorldState -> Prop :=
(* | init_step : forall bn aus bt ast tm,
    Auction.init bn aus bt = Some(ast) ->
    step () (ast, tm, nil) *)
| bid_step : forall ast bdr amt tm log ast' tm',
    Auction.bid ast bdr amt tm' = Some(ast') ->
    tm' > tm ->
    step (ast, tm, log) (ast', tm', (bdr, amt) :: log)
| end_step : forall ast tm log ast' tm',
    Auction.sigEnd ast tm' = Some(ast') ->
    tm' > tm ->
    step (ast, tm, log) (ast', tm', log).

Inductive multistep : WorldState -> WorldState -> Prop :=
| multistep_0 : forall s,
    multistep s s
| multistep_m : forall s0 s1 s2,
    multistep s0 s1 -> 
    step s1 s2 -> 
    multistep s0 s2.

Theorem step_imp_multi : forall w w' ast t lg ast' t' lg',
  step w w' ->
  w = (ast, t, lg) ->
  w' = (ast', t', lg') ->
  multistep (ast, t, lg) (ast', t', lg').
Proof.
  intros.
  apply multistep_m with (s1 := (ast, t, lg)) (s2 := (ast', t', lg')).
  - apply multistep_0.
  - rewrite <- H0. rewrite <- H1. assumption. Qed.

(* Simple implementation. Terms may change in the future. *)
Definition valid_hist (hist : option Auction.StateList) : Prop := 
  match hist with
  | Some(_) => True
  | None => False
  end.

(* Theorem init_always_valid : 
  forall (beneficiary auctionStart biddingTime: positive),
    valid_hist Auction.init beneficiary auctionStart biddingTime.
Proof.
  intros. simpl. reflexivity.
Qed. *)

(* Lemma init_preserves_params : forall w bn aus bt t ast lg ast' t' lg',
  w = (init_ws bn aus bt t) ->
  w = (ast t lg) ->
  w' = (ast' t' lg') ->
  step w w' ->
  ast.(beneficiary) = ast'.(beneficiary) ->
  ast.(auctionStart) = ast'.(auctionStart) ->
  ast.(b *)

Lemma init_no_winner: forall bn aus bt t,
  let '(ast', _, lg') := (init_ws bn aus bt t) in
    Auction.getWinner ast' = None ->
    Contract.highestBidder lg' = None.
Proof.
  intros. simpl. auto. Qed.

Definition auction_did_end (ws : WorldState) : Prop :=
  let '(contract_state, t, _) := ws in
    match contract_state with
    | nil => False
    | last :: lst => 
        if Auction.auctionStart last + Auction.biddingTime last <=? t then True
        else False
    end.
  
(* Definition auction_did_end (ws : WorldState) : Prop :=
  let '(contract_state, _, _) := ws in
    if Auction.getEnded contract_state then True else False. *)

Lemma bool_taut : forall b : bool,
   b = false -> ~(if b then True else False).
Proof.
  intros. rewrite H. auto. Qed.

Lemma ab : forall b : bool,
  ~(if b then True else False) -> b = false.
Proof.
  intros. destruct b as []_eqn. contradiction. reflexivity. Qed.

Lemma ab_1 : forall ast,
  forall b,
    b = Auction.getEnded ast ->
    ~(if Auction.getEnded ast then True else False) ->
    Auction.getEnded ast = false.
Proof.
  intros. rewrite <- H. rewrite <- H in H0. apply ab in H0. apply H0. Qed.

Lemma ineq_flip : forall p q,
  (p <=? q) = false -> (q <? p) = true.
Proof.
  intros. apply not_false_iff_true. rewrite <- H. Admitted. 
 
Lemma geq_trans : forall p q r,
  p < q ->
    p > r ->
      r < q.
Proof.
  intros. Admitted.

Lemma ineq_reverse : forall m n,
  m < n <-> n > m.
Proof. Admitted.

Lemma lt_prop_to_flip : forall p q,
  p < q -> (q <=? p) = false.
Proof. Admitted.

Lemma lt_true_to_prop : forall m n,
  m <? n = true -> m < n.
Proof. Admitted.

Lemma le_false_to_prop : forall m n,
  m <=? n = false -> m > n.
Proof. Admitted.

Lemma hack : forall s ast0 ast'0,
  (if true || Auction.ended s
     then None
     else
      Some
        ({|
         Auction.beneficiary := Auction.beneficiary s;
         Auction.auctionStart := Auction.auctionStart s;
         Auction.biddingTime := Auction.biddingTime s;
         Auction.highestBidder := Auction.highestBidder s;
         Auction.highestBid := Auction.highestBid s;
         Auction.ended := true;
         Auction.pendingReturns := Auction.pendingReturns s |} :: 
         s :: ast0)) = Some ast'0 -> None = Some ast'0.
Proof. Admitted.

Lemma first_not_end_if_step : forall w w' ast t lg ast' t' lg',
  step w w' ->
  w = (ast, t, lg) ->
  w' = (ast', t', lg') ->
  ~(auction_did_end w).
Proof.
  intros.
  induction H. unfold Auction.bid in H. 
  - destruct ast0. discriminate H. 
    destruct (Auction.auctionStart s + Auction.biddingTime s <=? tm') eqn:Heq. discriminate H.
      destruct (Auction.highestBid s). destruct (amt <=? p) eqn:amt_lt_p. discriminate H.
        destruct ((Auction.pendingReturns s) ! bdr). simpl. apply ineq_flip in Heq.
          apply geq_trans with (p := tm') (q := Auction.auctionStart s + Auction.biddingTime s) (r := tm) in H2.
          apply lt_prop_to_flip in H2. rewrite H2. omega.
          apply lt_true_to_prop in Heq. assumption.
        unfold auction_did_end. apply le_false_to_prop in Heq. apply ineq_reverse in Heq.
          apply geq_trans with (p := tm') (q := Auction.auctionStart s + Auction.biddingTime s) (r := tm) in H2.
          apply lt_prop_to_flip in H2. rewrite H2. omega. assumption.
        unfold auction_did_end. apply le_false_to_prop in Heq. apply ineq_reverse in Heq.
          apply geq_trans with (p := tm') (q := Auction.auctionStart s + Auction.biddingTime s) (r := tm) in H2.
          apply lt_prop_to_flip in H2. rewrite H2. omega. assumption.
  - destruct ast0.
    + unfold Auction.sigEnd in H. discriminate H.
    + unfold Auction.sigEnd in H. destruct (tm' <=? Auction.auctionStart s + Auction.biddingTime s) eqn:Heq. 
        apply hack in H. discriminate H.
        destruct (false || Auction.ended s) eqn:Hb. discriminate H.
        unfold auction_did_end. apply le_false_to_prop in Heq. apply ineq_reverse in Heq.
          apply geq_trans with (p := tm') (q := Auction.auctionStart s + Auction.biddingTime s) (r := tm) in H2.
          apply lt_prop_to_flip in H2. rewrite H2. omega. inversion H. Abort.

Lemma not_end_if_bid : forall ast bdr amt tm w ast' tm' log,
  Auction.bid ast bdr amt tm = Some ast' ->
  tm <= tm' ->
  (* ~(ast = nil) -> *)
  w = (ast', tm', log) ->
  ~(auction_did_end w).
Proof.
  intros. replace w. simpl.
  unfold Auction.bid in H. destruct ast. discriminate H.
    + destruct (Auction.auctionStart s + Auction.biddingTime s <=? tm) eqn:Heq. discriminate H.
      destruct (Auction.highestBid s). destruct (amt <=? p). discriminate H.
        destruct ((Auction.pendingReturns s) ! bdr). inversion H. simpl.
(* apply ab_1 with (ast := ast') (b := Auction.getEnded ast'). *)
(*  apply ab with (b := Auction.getEnded ast'). *)
Abort.

Lemma add_list_same_nil : forall (x : Contract.BidEntry) (lst : Contract.BidLog),
  lst = x :: lst -> False.
Proof.
   induction lst.
discriminate 1.

intros.
  apply IHlst.
congruence. Qed.

Open Scope nat_scope.

Lemma list_len_eq : forall (l l' : list Type),
  l = l' -> length l = length l'.
Proof. 
  intros. induction l. 
  - rewrite H. reflexivity.
  - rewrite H. reflexivity. Qed.

Lemma step_length_inc_one : forall w w',
  step w w' ->
  forall a t lg a' t' lg', w = (a, t, lg) ->
    w' = (a', t', lg') ->
    length a' = length a + 1.
Proof.
  intros. destruct a. 
  - simpl. induction H. 
    + unfold Auction.bid in H. destruct ast. discriminate H. discriminate H0.
    + unfold Auction.sigEnd in H. destruct ast. discriminate H. discriminate H0.
  - induction H.
    + unfold Auction.bid in H. destruct ast. discriminate H. Open Scope positive_scope.
      destruct (Auction.auctionStart s0 + Auction.biddingTime s0 <=? tm').
      discriminate H. destruct (Auction.highestBid s0). destruct (amt <=? p).
        discriminate H. destruct ((Auction.pendingReturns s0) ! bdr).
      inversion H. inversion H0. inversion H1. rewrite <- H5. rewrite <- H6. rewrite <- H9.
        rewrite <- H4. simpl. omega.
      inversion H. inversion H0. inversion H1. rewrite <- H5. rewrite <- H6. rewrite <- H9.
        rewrite <- H4. simpl. omega.
      inversion H. inversion H0. inversion H1. rewrite <- H5. rewrite <- H6. rewrite <- H9.
        rewrite <- H4. simpl. omega.
    + unfold Auction.sigEnd in H. destruct ast. discriminate H.
      destruct ((tm' <=? Auction.auctionStart s0 + Auction.biddingTime s0) || Auction.ended s0).
        discriminate H. inversion H. inversion H0. inversion H1. rewrite <- H5. rewrite <- H6.
        rewrite <- H9. rewrite <- H4. simpl. omega. Qed.

Lemma end_auction_same_log : forall w w',
  step w w' ->
  auction_did_end w' ->
  forall a t lg a' t' lg', w = (a, t, lg) ->
    w' = (a', t', lg') ->
    lg = lg'.
Proof.
  intros. induction H.
  - inversion H1. 
    + rewrite <- H7. unfold Auction.bid in H. destruct ast. discriminate H. 
        destruct (Auction.auctionStart s + Auction.biddingTime s <=? tm'). discriminate H.
          destruct (Auction.highestBid s). destruct (amt <=? p). discriminate H.
            destruct ((Auction.pendingReturns s) ! bdr). inversion H. rewrite H5 in H. 
            inversion H2. rewrite H9 in H. 
            unfold auction_did_end in H0. destruct ast'. contradiction H0. 
            destruct (Auction.auctionStart s0 + Auction.biddingTime s0 <=? tm'). 
Abort. 

Definition is_progress_bid (lg lg' : Contract.BidLog) : Prop :=
  let pre := Contract.highestBidder lg in
  let post := Contract.highestBidder lg' in
    match pre with
    | None => True
    | Some(l) =>
        match post with
        | None => False
        | Some(l') => if (l <=? l') then True else False
        end
    end.

Theorem step_high_bid_geq : forall w w',
  step w w' ->
  forall a t lg a' t' lg', w = (a, t, lg) ->
    w' = (a', t', lg') ->
    is_progress_bid lg lg'.
Proof.
  intros. induction H.
  - unfold Auction.bid in H. destruct ast. discriminate H.
      destruct (Auction.auctionStart s + Auction.biddingTime s <=? tm'). discriminate H.
        destruct (Auction.highestBid s). destruct (amt <=? p). discriminate H.
          destruct ((Auction.pendingReturns s) ! bdr).
            unfold is_progress_bid. destruct (Contract.highestBidder lg). 
            destruct (Contract.highestBidder lg').
Abort.

Theorem winner_is_hi_bidder_step : forall w w',
  step w w' ->
  forall a t lg a' t' lg' p, w = (a, t, lg) ->
    ~(lg' = nil) ->
    w' = (a',t',lg') ->
    Auction.getWinner a' = p ->
    Contract.highestBidder lg' = p.
Proof.
  intros. unfold Auction.getWinner in H3. destruct a'. rewrite <- H3.
    unfold Contract.highestBidder. unfold Contract.highestBidder_0.
Abort.

Theorem winner_is_hi_bidder_mlt : forall w w',
  multistep w w' ->
  forall a t lg a' t' lg' p, w = (a, t, lg) ->
    ~(lg' = nil) ->
    w' = (a',t',lg') ->
    Auction.getWinner a' = p ->
    Contract.highestBidder lg' = p.
Proof.
  intros. 
Abort.

Theorem winner_is_hi_bidder_step_init : forall w w',
  step w w' ->
  forall bn aus bt t ast' t' lg' p, w = (init_ws bn aus bt t) ->
    w' = (ast',t',lg') ->
    Auction.getWinner ast' = p ->
    Contract.highestBidder lg' = p.
Proof.
  intros. unfold Auction.getWinner in H2. destruct ast'. rewrite <- H2.
    unfold Contract.highestBidder. destruct lg'. reflexivity.
    unfold Contract.highestBidder_0.
Abort.

Theorem winner_is_hi_bidder_mlt_init : forall w w',
  multistep w w' ->
  forall bn aus bt t ast' t' lg' p, w = (init_ws bn aus bt t) ->
    w' = (ast',t',lg') ->
    Auction.getWinner ast' = p ->
    Contract.highestBidder lg' = p.
Proof.
  intros. unfold Auction.getWinner in H2. destruct ast'. rewrite <- H2.
    unfold Contract.highestBidder. destruct lg'. reflexivity.
    unfold Contract.highestBidder_0.
Abort.
