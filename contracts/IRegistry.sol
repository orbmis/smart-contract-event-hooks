// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

/// @title IRegistry
/// @dev Implements the registry contract
interface IRegistry {
    /// @dev Registers a new hook event by a publisher
    /// @param publisherContract The address of the publisher contract
    /// @param threadId The id of the thread these hook events will be fired on
    /// @param signingKey The public key that corresponds to the signature of externally generated payloads (optional)
    /// @return Returns true if the hook is successfully registered
    function registerHook(
        address publisherContract,
        uint256 threadId,
        bytes calldata signingKey
    ) external returns (bool);

    /// @dev Verifies a hook with the publisher smart contract before adding it to the registry
    /// @param publisherAddress The address of the publisher contract
    /// @param threadId The id of the thread these hook events will be fired on
    /// @return Returns true if the hook is successfully verified
    function verifyHook(address publisherAddress, uint256 threadId)
        external
        returns (bool);

    /// @dev Update a previously registered hook event
    /// @dev Can be used to transfer hook authorization to a new address
    /// @dev To remove a hook, transfer it to the burn address
    /// @param publisherContract The address of the publisher contract
    /// @param publisherPubKey The public key used to verify the hook signatures
    /// @param threadId The id of the thread these hook events will be fired on
    /// @return Returns true if the hook is successfully updated
    function updateHook(
        address publisherContract,
        address publisherPubKey,
        uint256 threadId
    ) external returns (bool);

    /// @dev Registers a subscriber to a hook event
    /// @param publisherContract The address of the publisher contract
    /// @param subscriberContract The address of the contract subscribing to the event hooks
    /// @param threadId The id of the thread these hook events will be fired on
    /// @param fee The fee that the subscriber contract will pay the relayer
    /// @param maxGas The maximum gas that the subscriber allow to spend, to prevent griefing attacks
    /// @param maxGasPrice The maximum gas price that the subscriber is willing to rebate
    /// @param chainId The chain id that the subscriber wants updates on
    /// @param feeToken The address of the token that the fee will be paid in or 0x0 for the chain's native asset (e.g. ETH)
    /// @return Returns true if the subscriber is successfully registered
    function registerSubscriber(
        address publisherContract,
        address subscriberContract,
        uint256 threadId,
        uint256 fee,
        uint256 maxGas,
        uint256 maxGasPrice,
        uint256 chainId,
        address feeToken
    ) external returns (bool);

    /// @dev Registers a subscriber to a hook event
    /// @param publisherContract The address of the publisher contract
    /// @param subscriberContract The address of the contract subscribing to the event hooks
    /// @param threadId The id of the thread these hook events will be fired on
    /// @param fee The fee that the subscriber contract will pay the relayer
    /// @return Returns true if the subscriber is successfully updated
    function updateSubscriber(
        address publisherContract,
        address subscriberContract,
        uint256 threadId,
        uint256 fee
    ) external returns (bool);
}
