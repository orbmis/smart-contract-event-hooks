// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

/// @title ISubscriber
/// @dev Implements a subscriber contract
interface ISubscriber {
    /// @dev Example of a function that is called when a hook is fired by a publisher
    /// @param message Hash of the hook event payload that was signed
    /// @param threadId The id of the thread this hook was fired on
    /// @param nonce Unique nonce of this hook
    /// @param v The v part of the signature
    /// @param r The r part of the signature
    /// @param s The s part of the signature
    function verifyHook(
        bytes32[] memory message,
        uint256 threadId,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (address signer, bytes32 payload);
}
