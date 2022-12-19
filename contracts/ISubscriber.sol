// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

/// @title ISubscriber
/// @dev Implements a subscriber contract
interface ISubscriber {
    /// @dev Example of a function that is called when a hook is fired by a publisher
    /// @param payload Hash of the hook event payload that was signed
    /// @param threadId The id of the thread this hook was fired on
    /// @param nonce Unique nonce of this hook
    /// @param blockheight The block height at which the hook event was fired
    function verifyHook(
        bytes calldata payload,
        uint256 threadId,
        uint256 nonce,
        uint256 blockheight
    ) external returns (address signer, bytes32 message);
}
