Require Import Bool.
Require Import Coq.Lists.List.
Require Import ZArith.BinInt.

Module Contract.

Open Scope positive_scope.

Definition Time := positive.

Definition address := positive.
Definition amount := positive.

Definition BidEntry := (address * amount)%type.
Definition BidLog := list (BidEntry).

Fixpoint highestBidder_0 (log : BidLog) (bdr bid : positive) : positive :=
  match log with
  | nil => bdr
  | (this_bdr, this_bid) :: l => 
      if (bid <? this_bid) then
        highestBidder_0 l this_bdr this_bid
      else
        highestBidder_0 l bdr bid
  end.

Definition highestBidder (log : BidLog) : option positive :=
  match log with
  | nil => None
  | (bdr, bid) :: l => Some(highestBidder_0 log bdr bid)
  end.

End Contract.