// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

/// @title Errors thrown by the FranchiserExpiryFactory contract.
interface IFranchiserExpiryFactoryErrors {
    /// @notice Emitted when two array arguments have different cardinalities.
    /// @param length0 The length of the first array argument.
    /// @param length1 The length of the second array argument.
    error ArrayLengthMismatch(uint256 length0, uint256 length1);

    /// @notice Thrown when attempting to set an expiration timestamp that is in the past
    error InvalidExpiration();

    /// @notice Thrown when attempting to recall tokens from a franchiser before its expiration timestamp.
    error FranchiserNotExpired();
}
