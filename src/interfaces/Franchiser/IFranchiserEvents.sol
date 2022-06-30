// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8;

import {Franchiser} from "../../Franchiser.sol";

/// @title Events for the Franchiser contract.
interface IFranchiserEvents {
    /// @notice Emitted once per Franchiser.
    /// @param owner The `owner`.
    /// @param delegatee The `delegatee`.
    /// @param maximumSubDelegatees The `maximumSubDelegatees`.
    event Initialized(
        address indexed owner,
        address indexed delegatee,
        uint96 maximumSubDelegatees
    );

    /// @notice Emitted when a `subDelegatee` is activated.
    /// @param subDelegatee The `subDelegatee`.
    /// @param franchiser The Franchiser associated with the `subDelegatee`.
    event SubDelegateeActivated(
        address indexed subDelegatee,
        Franchiser franchiser
    );

    /// @notice Emitted when a `subDelegatee` is deactivated.
    /// @param subDelegatee The `subDelegatee`.
    /// @param franchiser The Franchiser associated with the `subDelegatee`.
    event SubDelegateeDeactivated(
        address indexed subDelegatee,
        Franchiser franchiser
    );
}
