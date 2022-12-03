// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./IRegistry.sol";
import "./IPublisher.sol";

contract Registry is IRegistry {
    event HookRegistered(
        address indexed publisherContract,
        address publisherPubKey,
        uint256 threadId,
        address result,
        bool valid
    );

    event HookUpdated(
        address indexed publisherContract,
        address publisherPubKey,
        uint256 threadId
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

    /// mapping of publisherContractAddress to threadId to publisherPubKey
    /// a publisher contract can pubish multiple different hooks on different thread ids
    mapping(address => mapping(uint256 => address)) public publishers;

    /// mapping of subscriberContractAddress to publisherContractAddress to threadIds to fee
    /// a subscriber contract can subscribe to multiple hook events on one or more contracts
    mapping(address => mapping(address => mapping(uint256 => uint256)))
        public subscribers;

    /// records the owners of a subscriber contract so that updates can be authorized
    mapping(address => address) public owners;

    function registerHook(address publisherContract, uint256 threadId)
        public
        returns (bool)
    {
        require(
            (publishers[publisherContract][threadId] == address(0)),
            "Hook already registered"
        );

        address result = IPublisher(publisherContract).getEventHook(threadId);

        bool isHookValid = verifyHook(publisherContract, threadId);

        require(isHookValid, "Hook not valid");

        // the sender must be the account that signs the hook events
        publishers[publisherContract][threadId] = msg.sender;

        emit HookRegistered(
            publisherContract,
            msg.sender,
            threadId,
            result,
            isHookValid
        );

        return true;
    }

    function verifyHook(address publisherAddress, uint256 threadId)
        public
        view
        returns (bool)
    {
        return
            IPublisher(publisherAddress).verifyEventHook(threadId, msg.sender);
    }

    function updateHook(
        address publisherContract,
        address publisherPubKey,
        uint256 threadId
    ) public returns (bool) {
        require(
            publishers[publisherContract][threadId] == msg.sender,
            "Not authorized to update hook"
        );

        publishers[publisherContract][threadId] = publisherPubKey;

        emit HookUpdated(publisherContract, publisherPubKey, threadId);

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
}
