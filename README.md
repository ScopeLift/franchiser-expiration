# Franchiser (featuring Expiration)

This is a modified version of [Franchiser](https://github.com/uniswapfoundation/franchiser) that allows for permissionless recall of funds back to their original owner after a specified expiration time. All other Franchiser features are untouched.

## Running Locally

- Ensure that [foundry](https://book.getfoundry.sh/) is installed on your machine
- `forge build`
- `forge test --no-match-contract Integration`
- `forge test --match-contract Integration --fork-url $FORK_URL`

## Deploying

- Create and populate a .env file
- `source .env`
- `forge script script/Deploy.s.sol:Deploy --broadcast --private-key $PRIVATE_KEY --rpc-url $RPC_URL [--etherscan-api-key $ETHERSCAN_API_KEY --verify --chain-id $CHAIN_ID]`

## Deployed Instance

No deployed instance yet.

## Audit

This codebase will be audited soon by ChainSecurity.
