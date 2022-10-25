// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

/// @title IRegistry
/// @dev Implements a registry contract
interface IRegistry {

    /// @dev Registers a new hook event by a publisher
    /// @param publisherContract The address of the publisher contract
    /// @param threadId The id of the thread these hook events will be fired on
    function registerHook(address publisherContract, uint256 threadId) external returns (bool);

    /// @dev Verifies a hook with the publisher smart contract before adding it to the registry
    /// @param publisherAddress The address of the publisher contract
    /// @param threadId The id of the thread these hook events will be fired on
    function verifyHook(address publisherAddress, uint256 threadId) external returns (bool);

    /// @dev Update a previously registered hook event
    /// @dev Can be used to transfer hook authorization to a new address
    /// @dev To remove a hook, transfer it to the burn address
    /// @param publisherContract The address of the publisher contract
    /// @param publisherPubKey The public key used to verify the hook signatures
    /// @param threadId The id of the thread these hook events will be fired on
    function updateHook(address publisherContract, address publisherPubKey, uint256 threadId) external returns (bool);

    /// @dev Registers a subscriber to a hook event
    /// @param publisherContract The address of the publisher contract
    /// @param subscriberContract The address of the contract subscribing to the event hooks
    /// @param threadId The id of the thread these hook events will be fired on
    /// @param fee The fee that the subscriber contract will pay the relayer
    function registerSubscriber(address publisherContract, address subscriberContract, uint256 threadId, uint256 fee) external returns (bool);

    /// @dev Registers a subscriber to a hook event
    /// @param publisherContract The address of the publisher contract
    /// @param subscriberContract The address of the contract subscribing to the event hooks
    /// @param threadId The id of the thread these hook events will be fired on
    /// @param fee The fee that the subscriber contract will pay the relayer
    function updateSubscriber(address publisherContract, address subscriberContract, uint256 threadId, uint256 fee) external returns (bool);
}