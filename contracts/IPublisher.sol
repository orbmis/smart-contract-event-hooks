// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

/// @title IPublisher
/// @dev Implements a publisher contract
interface IPublisher {
    /// @dev Example of a function that fires a hook event when it is called
    /// @param hashedMessage Hash of the hook event payload that was signed
    /// @param threadId The thread number to fire the hook event on
    /// @param v The v part of the signature
    /// @param r The r part of the signature
    /// @param s The s part of the signature
    function fireHook(
        bytes32 hashedMessage,
        uint256 threadId,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /// @dev Adds / updates a new hook event internally
    /// @param threadId The thread id of the hook
    /// @param publisherPubKey The public key associated with the private key that signs the hook events
    function addHook(uint256 threadId, address publisherPubKey) external;

    /// @dev Called by the registry contract when registering a hook, used to verify the hook is valid before adding
    /// @param threadId The thread id of the hook
    /// @param publisherPubKey The public key associated with the private key that signs the hook events
    /// @return Returns true if the hook is valid and is ok to add to the registry
    function verifyEventHook(uint256 threadId, address publisherPubKey)
        external
        view
        returns (bool);

    function getEventHook(uint256 threadId) external view returns (address);
}
