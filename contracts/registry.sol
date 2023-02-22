// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./IRegistry.sol";
import "./IPublisher.sol";

contract Registry is IRegistry {
    event HookRegistered(
        address indexed publisherContract,
        address publisherAddress,
        uint256 threadId,
        bytes signingKey
    );

    event HookUpdated(
        address indexed publisherContract,
        address publisherAddress,
        uint256 threadId,
        bytes signingKey
    );

    event HookRemoved(
        address indexed publisherContract,
        address publisherAddress,
        uint256 threadId,
        bytes signingKey
    );

    event SubscriberRegistered(
        address indexed publisherContract,
        address indexed subscriberContract,
        uint256 threadId,
        uint256 fee,
        uint256 maxGas,
        uint256 maxGasPrice,
        uint256 chainId,
        address feeToken
    );

    event SubscriberUpdated(
        address indexed publisherContract,
        address indexed subscriberContract,
        uint256 threadId,
        uint256 fee
    );

    event SubscriptionRemoved(
        address indexed publisherContract,
        address indexed subscriberContract,
        uint256 threadId
    );

    /// mapping of publisherContractAddress to threadId to publisherPubKey
    /// a publisher contract can pubish multiple different hooks on different thread ids
    mapping(address => mapping(uint256 => address)) public publishers;

    /// mapping of subscriberContractAddress to publisherContractAddress to threadIds to fee
    /// a subscriber contract can subscribe to multiple hook events on one or more contracts
    mapping(address => mapping(address => mapping(uint256 => uint256)))
        public subscribers;

    /// records the owners of a subscriber contract so that updates can be authorized
    mapping(address => address) public owners;

    mapping(address => string) public relayers;

    function registerHook(
        address publisherContract,
        uint256 threadId,
        bytes calldata signingKey
    ) public returns (bool) {
        require(
            (publishers[publisherContract][threadId] == address(0)),
            "Hook already registered"
        );

        bool isHookValid = verifyHook(publisherContract, threadId, signingKey);

        require(isHookValid, "Hook not valid");

        publishers[publisherContract][threadId] = msg.sender;

        emit HookRegistered(
            publisherContract,
            msg.sender,
            threadId,
            signingKey
        );

        return true;
    }

    function registerRelayerHandle(address relayer, string memory handle)
        external
    {
        uint256 handleSize = bytes(relayers[relayer]).length;

        require(handleSize < 65, "Handle exceeds 64 bytes");
        require(
            handleSize == 0 || relayer == msg.sender,
            "Address already registered"
        );

        relayers[relayer] = handle;
    }

    function verifyHook(
        address publisherAddress,
        uint256 threadId,
        bytes calldata signingKey
    ) public view returns (bool) {
        return
            IPublisher(publisherAddress).verifyEventHookRegistration(
                threadId,
                signingKey
            );
    }

    function updateHook(
        address publisherContract,
        uint256 threadId,
        bytes calldata signingKey
    ) public returns (bool) {
        require(
            publishers[publisherContract][threadId] == msg.sender,
            "Not authorized to update hook"
        );

        emit HookUpdated(publisherContract, msg.sender, threadId, signingKey);

        return true;
    }

    function removeHook(
        address publisherContract,
        uint256 threadId,
        bytes calldata signingKey
    ) public returns (bool) {
        require(
            publishers[publisherContract][threadId] == msg.sender,
            "Not authorized to update hook"
        );

        publishers[publisherContract][threadId] = address(0);

        emit HookRemoved(publisherContract, msg.sender, threadId, signingKey);

        return true;
    }

    function registerSubscriber(
        address publisherContract,
        address subscriberContract,
        uint256 threadId,
        uint256 fee,
        uint256 maxGas,
        uint256 maxGasPrice,
        uint256 chainId,
        address feeToken
    ) public returns (bool) {
        require(fee > 0, "Fee must be greater than 0");

        require(
            subscribers[subscriberContract][publisherContract][threadId] != fee,
            "Subscriber already registered"
        );

        subscribers[subscriberContract][publisherContract][threadId] = fee;

        owners[subscriberContract] = msg.sender;

        emit SubscriberRegistered(
            publisherContract,
            subscriberContract,
            threadId,
            fee,
            maxGas,
            maxGasPrice,
            chainId,
            feeToken
        );

        return true;
    }

    function updateSubscriber(
        address publisherContract,
        address subscriberContract,
        uint256 threadId,
        uint256 fee
    ) public returns (bool) {
        require(
            owners[subscriberContract] == msg.sender,
            "Not authorized to update subscriber"
        );

        subscribers[subscriberContract][publisherContract][threadId] = fee;

        emit SubscriberUpdated(
            publisherContract,
            subscriberContract,
            threadId,
            fee
        );

        return true;
    }

    function removeSubscription(
        address publisherContract,
        address subscriberContract,
        uint256 threadId
    ) public returns (bool) {
        require(
            owners[subscriberContract] == msg.sender,
            "Not authorized to update subscriber"
        );

        subscribers[subscriberContract][publisherContract][threadId] = 0;

        emit SubscriptionRemoved(
            publisherContract,
            subscriberContract,
            threadId
        );

        return true;
    }
}
