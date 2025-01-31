# Franchiser (featuring Expiration)

Below is a revised version of the [Franchiser](https://github.com/uniswapfoundation/franchiser) design document, featuring the addition of permissionless recall of funds after a specified expiration time.

This document describes a smart contract design which allows holders of COMP-style voting tokens to selectively delegate portions of their voting power to third parties for a specified duration, while retaining full custody over the underlying tokens.

Familiarity with the design and functionality of checkpoint voting tokens is assumed, for background information refer to the following reference material from e.g. [Compound](https://compound.finance/docs/governance#comp) or [OpenZeppelin](https://docs.openzeppelin.com/contracts/4.x/api/token/erc20#ERC20Votes).

## Motivation

Often, holders of voting tokens want to delegate their voting power, but not all to the same party or for an indefinite period! Because of how these tokens are designed, it's impossible to do so without splitting balances across multiple addresses. While this constraint is somewhat frustrating, it opens up an interesting design space.

## Description

Imagine a `FranchiserFactory` contract designed to allocate voting tokens, with the following properties:

1. At any time, any voting token holder may specify some `amount` of voting power to give to a `delegatee` for a specified `expiration` timestamp. This creates and funds a `Franchiser` smart contract designed specifically for the holder, who becomes the `owner` of the contract, and the `delegatee`.

   1. The `Franchiser` contract allows the `owner` to recall the delegated tokens on demand.
   2. The `Franchiser` automatically delegates voting power to the `delegatee` with no further interaction required.
   3. Anyone can call `recallExpired` to return the delegated tokens back to the `owner` once the `expiration` timestamp is reached.
   4. Anyone can call `recallManyExpired` to recall multiple expired instances of `Franchiser` in a single transaction. However, the operation will revert if any instance of `Franchiser` has not yet expired. This ensures atomic execution and prevents partial recalls.
   5. The `owner` can update a `Franchiser`'s expiration by calling `fund` with an `amount` of `0` and a new `expiration` timestamp.

2. `Franchiser` contracts allow `delegatees` to further sub-divide their tokens amongst several `subDelegatees`.
   1. At any point before expiration, the `delegatee` of a `Franchiser` may specify an `amount` of voting power to give to a `subDelegatee`, which creates and funds a _nested_ `Franchiser` owned by the `delegatee`.
   2. The `delegatee` may recall any delegated tokens on demand.
   3. The maximum allowable number of `subDelegatees` varies. The `delegatee` who was granted voting power by an `owner` may designate up to 8 `subDelegatees`. Each of those may then specify 4 `subDelegatees` in turn, then 2, then 1, then 0.
   4. While nested `Franchiser` contracts do not have explicit `expiration` timestamps, they are implicitly bound by their parent's `expiration`. When a parent `Franchiser` expires or is recalled, all tokens in its subdelegation tree are automatically recalled recursively.

Note that at any level of nesting, a `delegatee` (or `owner`) always has the ability to recall any and all tokens they or any subsidiaries have delegated. The maximum number of nested `delegatees`/`subDelegatees` that any one `owner` could be associated with is 16 (8 + 8\*4 + 8\*4\*2 + 8\*4\*2), which costs about ~5m gas to fully unwind.
