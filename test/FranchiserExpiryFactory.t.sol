// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.15;

import {Test, console2} from "forge-std/Test.sol";
import {IFranchiserExpiryFactoryErrors} from "../src/interfaces/FranchiserExpiryFactory/IFranchiserExpiryFactoryErrors.sol";
import {IFranchiserEvents} from "../src/interfaces/Franchiser/IFranchiserEvents.sol";
import {IFranchiserErrors} from "../src/interfaces/Franchiser/IFranchiserErrors.sol";
import {VotingTokenConcrete} from "./VotingTokenConcrete.sol";
import {IVotingToken} from "../src/interfaces/IVotingToken.sol";
import {FranchiserExpiryFactory} from "../src/FranchiserExpiryFactory.sol";
import {Franchiser} from "../src/Franchiser.sol";
import {Utils} from "./Utils.sol";

contract FranchiserExpiryFactoryTest is Test, IFranchiserExpiryFactoryErrors, IFranchiserEvents {
    VotingTokenConcrete private votingToken;
    FranchiserExpiryFactory private franchiserFactory;

    uint safeFutureExpiration = block.timestamp + 1 weeks;

    function setUp() public {
        votingToken = new VotingTokenConcrete();
        franchiserFactory = new FranchiserExpiryFactory(IVotingToken(address(votingToken)));
    }

    function _validActorAddress(address _address) internal view returns (bool valid) {
        valid =
            (_address != address(0)) && (_address != address(votingToken) && (_address != address(franchiserFactory)));
    }

    function _boundAmount(uint256 _amount) internal pure returns (uint256) {
        return bound(_amount, 0, 100_000_000e18);
    }

    function testSetUp() public {
        assertEq(franchiserFactory.INITIAL_MAXIMUM_SUBDELEGATEES(), 8);
        assertEq(
            address(franchiserFactory.franchiserImplementation()),
            address(franchiserFactory.franchiserImplementation().franchiserImplementation())
        );
        assertEq(franchiserFactory.franchiserImplementation().owner(), address(0));
        assertEq(franchiserFactory.franchiserImplementation().delegator(), address(0));
        assertEq(franchiserFactory.franchiserImplementation().delegatee(), address(1));
        assertEq(franchiserFactory.franchiserImplementation().maximumSubDelegatees(), 0);
    }

    function testFundZero() public {
        Franchiser expectedFranchiser = franchiserFactory.getFranchiser(Utils.alice, Utils.bob);

        vm.expectEmit(true, true, true, true, address(expectedFranchiser));
        emit Initialized(address(franchiserFactory), Utils.alice, Utils.bob, 8);
        vm.prank(Utils.alice);
        Franchiser franchiser = franchiserFactory.fund(Utils.bob, 0, safeFutureExpiration);

        assertEq(address(expectedFranchiser), address(franchiser));
        assertEq(franchiser.owner(), address(franchiserFactory));
        assertEq(franchiser.delegatee(), Utils.bob);
        assertEq(votingToken.delegates(address(franchiser)), Utils.bob);
        assertEq(franchiserFactory.expirations(franchiser), safeFutureExpiration);
    }

    function testFundCanCallTwice() public {
        vm.startPrank(Utils.alice);
        franchiserFactory.fund(Utils.bob, 0, safeFutureExpiration);
        franchiserFactory.fund(Utils.bob, 0, safeFutureExpiration);
        vm.stopPrank();
    }

    function testFundNonZeroRevertsTRANSFER_FROM_FAILED() public {
        vm.expectRevert(bytes("TRANSFER_FROM_FAILED"));
        franchiserFactory.fund(Utils.bob, 100, safeFutureExpiration);
    }

    function testFundNonZero() public {
        votingToken.mint(Utils.alice, 100);

        vm.startPrank(Utils.alice);
        votingToken.approve(address(franchiserFactory), 100);
        Franchiser franchiser = franchiserFactory.fund(Utils.bob, 100, safeFutureExpiration);
        vm.stopPrank();

        assertEq(votingToken.balanceOf(address(franchiser)), 100);
        assertEq(votingToken.getVotes(Utils.bob), 100);
        assertEq(franchiserFactory.expirations(franchiser), safeFutureExpiration);
    }

    function testFuzz_FundBalances_VotingPower_ExpirationUpdated(address _delegator, address _delegatee, uint256 _amount, uint256 _expiration)
        public
    {
        vm.assume(_validActorAddress(_delegator));
        vm.assume(_delegatee != address(0));
        _amount = _boundAmount(_amount);
        _expiration = bound(_expiration, block.timestamp, type(uint).max);
        Franchiser expectedFranchiser = franchiserFactory.getFranchiser(_delegator, _delegatee);
        uint256 _delegateeVotesBefore = votingToken.getVotes(_delegatee);
        uint256 _franchiserBalanceBefore = votingToken.balanceOf(address(expectedFranchiser));

        votingToken.mint(_delegator, _amount);
        uint256 _delegatorBalanceBefore = votingToken.balanceOf(_delegator);

        vm.startPrank(_delegator);
        votingToken.approve(address(franchiserFactory), _amount);
        Franchiser franchiser = franchiserFactory.fund(_delegatee, _amount, _expiration);
        vm.stopPrank();

        assertEq(votingToken.balanceOf(address(franchiser)), _franchiserBalanceBefore + _amount);
        assertEq(votingToken.getVotes(_delegatee), _delegateeVotesBefore + _amount);
        assertEq(votingToken.balanceOf(_delegator), _delegatorBalanceBefore - _amount);
        assertEq(franchiserFactory.expirations(franchiser), _expiration);
    }

    function testFuzz_Fund_OverwritesExpiration_BeforeExpiry(address _owner, address _delegatee, uint256 _amount, uint256 _expiration, uint256 _warpTime, uint256 _newExpiration) public {
        vm.assume(_validActorAddress(_owner));
        vm.assume(_delegatee != address(0));

        _amount = _boundAmount(_amount);
        _expiration = bound(_expiration, block.timestamp + 1 days, type(uint).max);
        _warpTime = bound(_warpTime, block.timestamp, _expiration - 1);
        _newExpiration = bound(_newExpiration, _warpTime, type(uint).max);

        votingToken.mint(_owner, _amount);

        vm.startPrank(_owner);
        votingToken.approve(address(franchiserFactory), _amount);
        Franchiser franchiser = franchiserFactory.fund(_delegatee, _amount, _expiration);
        assertEq(_expiration, franchiserFactory.expirations(franchiser));

        vm.warp(_warpTime);
        votingToken.mint(_owner, _amount);

        votingToken.approve(address(franchiserFactory), _amount);
        Franchiser newFranchiser = franchiserFactory.fund(_delegatee, _amount, _newExpiration);
        assertEq(address(newFranchiser), address(franchiser));
        assertEq(_newExpiration, franchiserFactory.expirations(newFranchiser));
        vm.stopPrank();
    }

    function testFuzz_Fund_OverwritesExpiration_AfterExpiry(address _owner, address _delegatee, uint256 _amount, uint256 _expiration, uint256 _warpTime, uint256 _newExpiration) public {
        vm.assume(_validActorAddress(_owner));
        vm.assume(_delegatee != address(0));

        _amount = _boundAmount(_amount);
        _expiration = bound(_expiration, block.timestamp + 1 days, type(uint).max);
        _warpTime = bound(_warpTime, _expiration, type(uint).max);
        _newExpiration = bound(_newExpiration, _warpTime, type(uint).max);

        votingToken.mint(_owner, _amount);

        vm.startPrank(_owner);
        votingToken.approve(address(franchiserFactory), _amount);
        Franchiser franchiser = franchiserFactory.fund(_delegatee, _amount, _expiration);
        assertEq(_expiration, franchiserFactory.expirations(franchiser));

        vm.warp(_warpTime);
        votingToken.mint(_owner, _amount);

        votingToken.approve(address(franchiserFactory), _amount);
        Franchiser newFranchiser = franchiserFactory.fund(_delegatee, _amount, _newExpiration);
        assertEq(address(newFranchiser), address(franchiser));
        assertEq(_newExpiration, franchiserFactory.expirations(newFranchiser));
        vm.stopPrank();
    }

    function testFuzz_FundFailsWhenDelegateeIsAddressZero(address _delegator, uint256 _amount) public {
        vm.assume(_validActorAddress(_delegator));
        address _delegatee = address(0);
        _amount = _boundAmount(_amount);

        votingToken.mint(_delegator, _amount);

        vm.startPrank(_delegator);
        votingToken.approve(address(franchiserFactory), _amount);
        vm.expectRevert(IFranchiserErrors.NoDelegatee.selector);
        franchiserFactory.fund(_delegatee, _amount, safeFutureExpiration);
        vm.stopPrank();
    }

    function testFuzz_RevertIf_BalanceTooLow(address _delegator, address _delegatee, uint256 _amount, uint256 _delta)
        public
    {
        vm.assume(_validActorAddress(_delegator));
        vm.assume(_delegatee != address(0));
        vm.assume((_amount >= _delta) && (_amount <= 100_000_000e18));
        _delta = bound(_delta, 1, 100_000_000e18);
        _amount = bound(_amount, _delta, 100_000_000e18);

        votingToken.mint(_delegator, _amount - _delta);

        vm.startPrank(_delegator);
        votingToken.approve(address(franchiserFactory), _amount);
        vm.expectRevert(bytes("TRANSFER_FROM_FAILED"));
        franchiserFactory.fund(_delegatee, _amount, safeFutureExpiration);
        vm.stopPrank();
    }

    function testFuzz_RevertIf_ExpirationLessThanBlockTimestamp(address _delegator, address _delegatee, uint256 _amount, uint256 _expiration) public {
        vm.assume(_validActorAddress(_delegator));
        vm.assume(_delegatee != address(0));
        _amount = _boundAmount(_amount);
        _expiration = bound(_expiration, 0, block.timestamp - 1);
        votingToken.mint(_delegator, _amount);

        vm.startPrank(_delegator);
        votingToken.approve(address(franchiserFactory), _amount);
        vm.expectRevert(IFranchiserExpiryFactoryErrors.InvalidExpiration.selector);
        franchiserFactory.fund(_delegatee, _amount, _expiration);
        vm.stopPrank();
    }

    function testFundManyRevertsArrayLengthMismatch() public {
        vm.expectRevert(abi.encodeWithSelector(ArrayLengthMismatch.selector, 0, 1));
        franchiserFactory.fundMany(new address[](0), new uint256[](1), safeFutureExpiration);

        vm.expectRevert(abi.encodeWithSelector(ArrayLengthMismatch.selector, 1, 0));
        franchiserFactory.fundMany(new address[](1), new uint256[](0), safeFutureExpiration);
    }

    function testFundMany() public {
        votingToken.mint(Utils.alice, 100);

        address[] memory delegatees = new address[](2);
        delegatees[0] = Utils.bob;
        delegatees[1] = Utils.carol;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 50;
        amounts[1] = 50;

        vm.startPrank(Utils.alice);
        votingToken.approve(address(franchiserFactory), 100);
        Franchiser[] memory franchisers = franchiserFactory.fundMany(delegatees, amounts, safeFutureExpiration);
        vm.stopPrank();

        assertEq(votingToken.balanceOf(address(franchisers[0])), 50);
        assertEq(votingToken.balanceOf(address(franchisers[1])), 50);
        assertEq(franchiserFactory.expirations(franchisers[0]), safeFutureExpiration);
        assertEq(franchiserFactory.expirations(franchisers[1]), safeFutureExpiration);
    }

    function testRecallZero() public {
        franchiserFactory.recall(Utils.bob, Utils.alice);
    }

    function testRecallNonZero() public {
        votingToken.mint(Utils.alice, 100);

        vm.startPrank(Utils.alice);
        votingToken.approve(address(franchiserFactory), 100);
        Franchiser franchiser = franchiserFactory.fund(Utils.bob, 100, safeFutureExpiration);
        franchiserFactory.recall(Utils.bob, Utils.alice);
        vm.stopPrank();

        assertEq(votingToken.balanceOf(address(franchiser)), 0);
        assertEq(votingToken.balanceOf(Utils.alice), 100);
        assertEq(votingToken.getVotes(Utils.bob), 0);
        assertEq(franchiserFactory.expirations(franchiser), safeFutureExpiration);
    }

    function testFuzz_RecallDelegatorBalanceUpdated(address _delegator, address _delegatee, uint256 _amount) public {
        vm.assume(_validActorAddress(_delegator));
        vm.assume(_delegatee != address(0));
        _amount = _boundAmount(_amount);

        votingToken.mint(_delegator, _amount);

        vm.startPrank(_delegator);
        votingToken.approve(address(franchiserFactory), _amount);
        franchiserFactory.fund(_delegatee, _amount, safeFutureExpiration);

        uint256 _delegatorBalanceBeforeRecall = votingToken.balanceOf(_delegator);
        franchiserFactory.recall(_delegatee, _delegator);
        vm.stopPrank();

        assertEq(votingToken.balanceOf(_delegator), _delegatorBalanceBeforeRecall + _amount);
    }

    function testRecallManyRevertsArrayLengthMismatch() public {
        vm.expectRevert(abi.encodeWithSelector(ArrayLengthMismatch.selector, 0, 1));
        franchiserFactory.recallMany(new address[](0), new address[](1));

        vm.expectRevert(abi.encodeWithSelector(ArrayLengthMismatch.selector, 1, 0));
        franchiserFactory.recallMany(new address[](1), new address[](0));
    }

    function testRecallMany() public {
        votingToken.mint(Utils.alice, 100);

        address[] memory delegatees = new address[](2);
        delegatees[0] = Utils.bob;
        delegatees[1] = Utils.carol;

        address[] memory tos = new address[](2);
        tos[0] = Utils.alice;
        tos[1] = Utils.alice;

        vm.startPrank(Utils.alice);
        votingToken.approve(address(franchiserFactory), 100);
        franchiserFactory.fund(Utils.bob, 50, safeFutureExpiration);
        franchiserFactory.fund(Utils.carol, 50, safeFutureExpiration);
        franchiserFactory.recallMany(delegatees, tos);
        vm.stopPrank();

        assertEq(votingToken.balanceOf(Utils.alice), 100);
    }

    function testRecallGasWorstCase() public {
        Utils.nestMaximum(vm, votingToken, franchiserFactory, safeFutureExpiration);
        vm.prank(address(1));
        uint256 gasBefore = gasleft();
        franchiserFactory.recall(address(2), address(1));
        uint256 gasUsed = gasBefore - gasleft();
        unchecked {
            assertGt(gasUsed, 2 * 1e6);
            assertLt(gasUsed, 5 * 1e6);
            console2.log(gasUsed);
        }
        assertEq(votingToken.balanceOf(address(1)), 64);
    }

    function testFuzz_RecallExpired_Owner_BalanceUpdated(address _owner, address _delegatee, uint256 _amount, uint256 _expiration, address _recallExpiredCaller, uint _recallTimestamp) public {
        vm.assume(_validActorAddress(_owner));
        vm.assume(_delegatee != address(0));

        _amount = _boundAmount(_amount);
        _expiration = bound(_expiration, block.timestamp, type(uint).max);
        _recallTimestamp = bound(_recallTimestamp, _expiration, type(uint).max);

        votingToken.mint(_owner, _amount);

        vm.startPrank(_owner);
        votingToken.approve(address(franchiserFactory), _amount);
        franchiserFactory.fund(_delegatee, _amount, _expiration);
        vm.stopPrank();
        vm.warp(_recallTimestamp);
        uint256 _ownerBalanceBeforeRecall = votingToken.balanceOf(_owner);

        vm.prank(_recallExpiredCaller);
        franchiserFactory.recallExpired(_owner, _delegatee);

        assertEq(votingToken.balanceOf(_owner), _ownerBalanceBeforeRecall + _amount);
    }

    function testFuzz_RecallExpired_NestedSubDelegatees_BalancesUpdated(address _owner, address _delegatee, address _subDelegatee1, address _subDelegatee2, uint256 _expiration, uint256 _recallTimestamp, address _recallExpiredCaller, uint256 _amount
    ) public {
        vm.assume(_validActorAddress(_owner));
        vm.assume(_validActorAddress(_delegatee));
        vm.assume(_validActorAddress(_subDelegatee1));
        vm.assume(_subDelegatee2 != address(0));

        _amount = _boundAmount(_amount);
        _expiration = bound(_expiration, block.timestamp, type(uint).max);
        _recallTimestamp = bound(_recallTimestamp, _expiration, type(uint).max);

        votingToken.mint(_owner, _amount);

        vm.startPrank(_owner);
        votingToken.approve(address(franchiserFactory), _amount);
        Franchiser franchiser = franchiserFactory.fund(_delegatee, _amount, _expiration);
        vm.stopPrank();

        // sub-delegate one-fourth of the amount to each sub-delegatee
        vm.prank(_delegatee);
        Franchiser _subFranchiser1 = franchiser.subDelegate(_subDelegatee1, _amount / 4);
        assertEq(votingToken.balanceOf(address(franchiser)), _amount  - _amount / 4);
        assertEq(votingToken.balanceOf(address(_subFranchiser1)), _amount / 4);

        vm.prank(_subDelegatee1);
        Franchiser _subFranchiser2 = _subFranchiser1.subDelegate(_subDelegatee2, _amount / 4);
        assertEq(votingToken.balanceOf(address(_subFranchiser1)), 0);
        assertEq(votingToken.balanceOf(address(_subFranchiser2)), _amount / 4);

        vm.warp(_recallTimestamp);

        vm.prank(_recallExpiredCaller);
        franchiserFactory.recallExpired(_owner, _delegatee);
        assertEq(votingToken.balanceOf(address(franchiser)), 0);
        assertEq(votingToken.balanceOf(address(_subFranchiser1)), 0);
        assertEq(votingToken.balanceOf(address(_subFranchiser2)), 0);
        assertEq(votingToken.balanceOf(_owner), _amount);
    }

    function testFuzz_RevertIf_RecallExpired_CalledBeforeExpiration(address _owner, address _delegatee, uint256 _amount, uint256 _expiration, address _recallExpiredCaller, uint _recallTimestamp) public {
        vm.assume(_validActorAddress(_owner));
        vm.assume(_delegatee != address(0));

        _amount = _boundAmount(_amount);
        _expiration = bound(_expiration, block.timestamp + 1 hours, type(uint).max);
        _recallTimestamp = bound(_recallTimestamp, block.timestamp, _expiration - 1);

        votingToken.mint(_owner, _amount);

        vm.startPrank(_owner);
        votingToken.approve(address(franchiserFactory), _amount);
        franchiserFactory.fund(_delegatee, _amount, _expiration);
        vm.stopPrank();

        vm.warp(_recallTimestamp);

        vm.prank(_recallExpiredCaller);
        vm.expectRevert(abi.encodeWithSelector(DelegateeNotExpired.selector));
        franchiserFactory.recallExpired(_owner, _delegatee);
    }

    function testFuzz_recallManyExpired(
        address _owner,
        address _delegatee1,
        address _delegatee2,
        uint256 _amount,
        uint256 _expiration,
        address _recallExpiredCaller,
        uint256 _recallTimestamp
    ) public {
        vm.assume(_validActorAddress(_owner));
        vm.assume(_delegatee1 != address(0));
        vm.assume(_delegatee2 != address(0));

        _amount = _boundAmount(_amount);
        _expiration = bound(_expiration, block.timestamp, type(uint256).max);
        _recallTimestamp = bound(_recallTimestamp, _expiration, type(uint256).max);

        votingToken.mint(_owner, _amount * 2);

        address[] memory delegatees = new address[](2);
        delegatees[0] = _delegatee1;
        delegatees[1] = _delegatee2;

        address[] memory owners = new address[](2);
        owners[0] = _owner;
        owners[1] = _owner;

        vm.startPrank(_owner);
        votingToken.approve(address(franchiserFactory), _amount * 2);
        franchiserFactory.fund(_delegatee1, _amount, _expiration);
        franchiserFactory.fund(_delegatee2, _amount, _expiration);
        vm.stopPrank();

        vm.warp(_recallTimestamp);
        uint256 _ownerBalanceBeforeRecall = votingToken.balanceOf(_owner);

        vm.prank(_recallExpiredCaller);
        franchiserFactory.recallManyExpired(owners, delegatees);

        assertEq(votingToken.balanceOf(_owner), _ownerBalanceBeforeRecall + _amount * 2);
    }

    function testPermitAndFund() public {
        (address owner, uint256 deadline, uint8 v, bytes32 r, bytes32 s) =
            votingToken.getPermitSignature(vm, 0xa11ce, address(franchiserFactory), 100);
        votingToken.mint(owner, 100);
        vm.prank(owner);
        Franchiser franchiser = franchiserFactory.permitAndFund(Utils.bob, 100, safeFutureExpiration, deadline, v, r, s);

        assertEq(votingToken.balanceOf(address(franchiser)), 100);
        assertEq(votingToken.getVotes(Utils.bob), 100);
        assertEq(franchiserFactory.expirations(franchiser), safeFutureExpiration);
        }

    function testPermitAndFundManyRevertsArrayLengthMismatch() public {
        vm.expectRevert(abi.encodeWithSelector(ArrayLengthMismatch.selector, 0, 1));
        franchiserFactory.permitAndFundMany(new address[](0), new uint256[](1), safeFutureExpiration, 0, 0, 0, 0);

        vm.expectRevert(abi.encodeWithSelector(ArrayLengthMismatch.selector, 1, 0));
        franchiserFactory.permitAndFundMany(new address[](1), new uint256[](0), safeFutureExpiration, 0, 0, 0, 0);
    }

    // fails because of overflow
    function testFailPermitAndFundMany() public {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = type(uint256).max;
        amounts[1] = 1;

        franchiserFactory.permitAndFundMany(new address[](2), amounts, 0, safeFutureExpiration, 0, 0, 0);
    }

    function testPermitAndFundMany() public {
        (address owner, uint256 deadline, uint8 v, bytes32 r, bytes32 s) =
            votingToken.getPermitSignature(vm, 0xa11ce, address(franchiserFactory), 100);
        votingToken.mint(owner, 100);

        address[] memory delegatees = new address[](2);
        delegatees[0] = Utils.bob;
        delegatees[1] = Utils.carol;

        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 50;
        amounts[1] = 50;

        vm.prank(owner);
        Franchiser[] memory franchisers = franchiserFactory.permitAndFundMany(delegatees, amounts, safeFutureExpiration, deadline, v, r, s);

        assertEq(votingToken.balanceOf(address(franchisers[0])), 50);
        assertEq(votingToken.balanceOf(address(franchisers[1])), 50);
        assertEq(franchiserFactory.expirations(franchisers[0]), safeFutureExpiration);
        assertEq(franchiserFactory.expirations(franchisers[1]), safeFutureExpiration);
    }
}
