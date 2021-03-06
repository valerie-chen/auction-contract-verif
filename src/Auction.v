Require Import AV.SolTypes.
Require Import AV.Integers.
Require Import AV.Maps.
Require Import Coq.Lists.List.

Require Import Bool.
Require Import ZArith.BinInt.

Module Auction.

  Open Scope positive_scope.

  Record State := 
    { 
      beneficiary : positive;
      auctionStart : positive;
      biddingTime : positive;
      highestBidder : option positive;
      highestBid : option positive;
      ended : bool;
      pendingReturns : PTree.t positive (* Maps positive -> positive *)
    }.

  (* Check State. *)

  Definition StateList := list State.

  Infix "::" := cons (at level 60, right associativity) : StateList_scope.

  Open Scope StateList_scope.

  Notation "[ ]" := nil.
  Notation "[ s1 , .. , s2 ]" := (cons s1 .. (cons s2 nil) ..). 

  (* Examples *)
(*   Definition state1 := Build_State 0 0 0 0 0 false 0.
  Definition state2 := Build_State 0 0 0 0 0 true 0.
  Definition testList := [ state1, state2 ].
  Definition appList := state1 :: testList. *)

  (* currently set so prev_bid < next_bid. *)
  (* can modify so that next_bid exceeds prev_bid by a 
       certain amount or is greater than a multiple of 
       prev_bid. *)
  (* Definition valid_next_bid (prev next : positive) : Prop :=
    prev < next. *)

  (* Eval simpl in (valid_next_bid 0 1). *)

  (* Definition valid_next_bidder (prev) *)

  (* Definition new_bidder (prev next : positive) : Prop :=
    ~(prev = next).

  Definition valid_new_bid (prev next : State) : Prop :=
    (new_bidder prev.(highestBidder) next.(highestBidder)) 
    /\ (valid_next_bid prev.(highestBid) next.(highestBid)). *)

  (* Note: Option type is specified though no invalidating condition exists in the source contract.
           This is in anticipation of future proofs related to validity of data structures, Solidity
           types, etc. *) 

(* from source contract *)

  Definition init 
    (beneficiary auctionStart biddingTime : positive) : StateList := 
    [ Build_State beneficiary 
                  auctionStart 
                  biddingTime 
                  None
                  None
                  false
                  (PTree.empty positive)].
     

  Definition bid (history : StateList) (newBidder newBid now: positive) : option StateList :=
    match history with
    | nil => None
    | latest :: hist 
        => if (latest.(auctionStart) + latest.(biddingTime) <=? now) then None
(*           || latest.(ended))  *)
           else 
             match latest.(highestBid) with
             | Some(hiBid) =>
                 if (newBid <=? hiBid) then None
                 else
                   match (PTree.get newBidder latest.(pendingReturns)) with
                   | Some(v) =>
                       Some((Build_State latest.(beneficiary)
                                    latest.(auctionStart) 
                                    latest.(biddingTime)
                                    (Some newBidder)
                                    (Some newBid)
                                    latest.(ended)
                                    (PTree.set 
                                      newBidder 
                                      (newBid + v)
                                      latest.(pendingReturns))) :: history)
                   | None => 
                       Some((Build_State latest.(beneficiary)
                                    latest.(auctionStart) 
                                    latest.(biddingTime)
                                    (Some newBidder)
                                    (Some newBid)
                                    latest.(ended)
                                    (PTree.set newBidder newBid latest.(pendingReturns))) :: history)
                   end
             | None => 
                 Some((Build_State latest.(beneficiary)
                                   latest.(auctionStart) 
                                   latest.(biddingTime)
                                   (Some newBidder)
                                   (Some newBid)
                                   latest.(ended)
                                   latest.(pendingReturns)) :: history)
             end
        end.

  Definition sigEnd (history : StateList) (now : positive) : option StateList :=
    match history with
    | nil => None
    | latest :: hist
        => if (now <=? latest.(auctionStart) + latest.(biddingTime))
              || latest.(ended) then None
           else
             Some ((Build_State latest.(beneficiary)
                                latest.(auctionStart)
                                latest.(biddingTime)
                                latest.(highestBidder)
                                latest.(highestBid)
                                true
                                latest.(pendingReturns)) :: history)
    end.

(* auxiliary definitions for proofs *)

  Definition getWinner (history : StateList) : option positive :=
    match history with
    | nil => None
    | latest :: hist => 
        if latest.(ended) then latest.(highestBidder)
        else None
    end.

  Definition getEnded (history : StateList) : bool :=
    match history with
    | nil => false
    | latest :: hist => latest.(ended)
    end.

End Auction.