// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import {Test, console2} from "forge-std/Test.sol";
import {IVotingToken} from "src/interfaces/IVotingToken.sol";
import {FranchiserExpiryFactory} from "src/FranchiserExpiryFactory.sol";
import {FranchiserExpiryFactoryHandler} from "test/handlers/FranchiserExpiryFactoryHandler.sol";
import {VotingTokenConcrete} from "./VotingTokenConcrete.sol";

contract FranchiserExpiryFactoryInvariantTest is Test {
    FranchiserExpiryFactory factory;
    FranchiserExpiryFactoryHandler handler;
    VotingTokenConcrete token;

    function setUp() public virtual {
        token = new VotingTokenConcrete();
        factory = new FranchiserExpiryFactory(IVotingToken(address(token)));
        handler = new FranchiserExpiryFactoryHandler(factory);
        bytes4[] memory selectors = new bytes4[](14);
        selectors[0] = FranchiserExpiryFactoryHandler.factory_fund.selector;
        selectors[1] = FranchiserExpiryFactoryHandler.factory_fundMany.selector;
        selectors[2] = FranchiserExpiryFactoryHandler.factory_recall.selector;
        selectors[3] = FranchiserExpiryFactoryHandler.factory_recallMany.selector;
        selectors[4] = FranchiserExpiryFactoryHandler.factory_permitAndFund.selector;
        selectors[5] = FranchiserExpiryFactoryHandler.factory_permitAndFundMany.selector;
        selectors[6] = FranchiserExpiryFactoryHandler.franchiser_subDelegate.selector;
        selectors[7] = FranchiserExpiryFactoryHandler.franchiser_subDelegateMany.selector;
        selectors[8] = FranchiserExpiryFactoryHandler.franchiser_unSubDelegate.selector;
        selectors[9] = FranchiserExpiryFactoryHandler.franchiser_unSubDelegateMany.selector;
        selectors[10] = FranchiserExpiryFactoryHandler.franchiser_recall.selector;
        selectors[11] = FranchiserExpiryFactoryHandler.factory_recallExpired.selector;
        selectors[12] = FranchiserExpiryFactoryHandler.factory_recallManyExpired.selector;
        selectors[13] = FranchiserExpiryFactoryHandler.factory_warpTime.selector;
        targetSelector(FuzzSelector({addr: address(handler), selectors: selectors}));
        targetContract(address(handler));
    }

    function invariant_FranchiserFactory_fund_code_size_non_zero() external view {
        assertGt(address(handler.franchiser()).code.length, 0);
    }

    function invariant_Franchiser_subdelegate_code_size_non_zero() external view {
        assertGt(address(handler.subDelegatedFranchiser()).code.length, 0);
    }

    function invariant_Franchisers_and_recalled_balance_sum_matches_total_supply() external {
        assertEq(token.totalSupply(), handler.sumDelegatorsBalances() + handler.sumFundedFranchisersBalances());
    }

    function invariant_Total_funded_less_total_recalled_matches_franchisers_totals() external {
        assertEq(handler.ghost_totalFunded() - handler.ghost_totalRecalled(), handler.sumFundedFranchisersBalances());
    }

    function invariant_Franchiser_subdelegation_totals_are_correct() external {
        handler.forEachFundedFranchiserAddress(this.assertFundedFranchisersSubDelegationBalancesAreCorrect);
    }

    // Used to see distribution of non-reverting calls
    function invariant_callSummary() public {
        handler.callSummary();
    }

    function assertFundedFranchisersSubDelegationBalancesAreCorrect(address _franchiser) external {
        assertEq(
            handler.getTotalAmountDelegatedByFranchiser(_franchiser),
            handler.ghost_fundedFranchiserBalances(_franchiser)
        );
    }
}
