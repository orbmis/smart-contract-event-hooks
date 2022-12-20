// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

/// @title IPublisher
/// @dev Implements a publisher contract
interface IPublisher {
    /// @dev Example of a function that fires a hook event when it is called
    /// @param payload The actual payload of the hook event
    /// @param digest Hash of the hook event payload that was signed
    /// @param threadId The thread number to fire the hook event on
    function fireHook(
        bytes calldata payload,
        bytes32 digest,
        uint256 threadId
    ) external;

    /// @dev Adds / updates a new hook event internally
    /// @param threadId The thread id of the hook
    /// @param publisherPubKey The public key associated with the private key that signs the hook events
    function addHook(uint256 threadId, address publisherPubKey) external;

    /// @dev Called by the registry contract when registering a hook, used to verify the hook is valid before adding
    /// @param threadId The thread id of the hook
    /// @param publisherPubKey The public key associated with the private key that signs the hook events
    /// @return Returns true if the hook is valid and is ok to add to the registry
    function verifyEventHookRegistration(
        uint256 threadId,
        address publisherPubKey
    ) external view returns (bool);

    /// @dev Returns the address that will sign the hook events on a given thread
    /// @param threadId The thread id of the hook
    /// @return Returns the address that will sign the hook events on a given thread
    function getEventHook(uint256 threadId) external view returns (address);

    /// @dev Returns true if the specified hook is valid
    /// @param payloadhash The hash of the hook's data payload
    /// @param threadId The thread id of the hook
    /// @param nonce The nonce of the current thread
    /// @param blockheight The blockheight that the hook was fired at
    /// @return Returns true if the specified hook is valid
    function verifyEventHook(
        bytes32 payloadhash,
        uint256 threadId,
        uint256 nonce,
        uint256 blockheight
    ) external view returns (bool);
}
