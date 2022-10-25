---
eip: <to be assigned>
title: Smart Contract Event Hooks Standard
description: Format that allows contracts to semi-autonoumously respond to events emitted by other contracts
author: Simon Brown (@orbmis)
discussions-to: <URL>
status: Draft
type: Standards Track
category: ERC
created: 2022-07-11
requires: erc-712
---

## Abstract

This ERC proposes contract standard to allow for creating "hooks" that facilitate smart contract function being called automatically in response to a trigger fired by another contract, by using a public relayer network as a messaging bus.

It relies on two interfaces, one for a publisher contract and one for a subscriber contract.  The publisher contract emits events that are picked up by "relayers", who are independent entities that subscribe to hook events on publisher contracts, and call respective functions on subscriber contacts whenever a hook event is fired by the publisher contract.  When a relayer calls the respective subscriber's hook function with the details of the hook event emitted by the publisher contract, they are paid a fee by the subscriber.  Both the publisher and subscriber contracts are registered in a central registry smart contract that relayers can use to discover hooks.

## Motivation

There exists a number of use cases that require some off-chain party to monitor the chain and respond to on-chain events by broadcasting a transaction.  Such cases usually require some off-chain process to run alongside an Ethereum node, in order to subscribe to events via a web socket connection, and perform some logic in response to an event, by broadcasting a respective transaction to the network.  For some use-cases, this may require an Ethereum node and an open websocket connection to some long-running process that may only be used infrequently, resulting in a sub-optimal use of resources.

This proposal would allow for a smart contract to contain the logic it needs to respond to events without having to store that logic in some off-chain process.  The smart contract can subscribe to events fired by other smart contracts and would only execute the required logic when it's needed. This method would suit any contract logic that does not require off-chain computation, but requires an off-chain process to monitor chain state in order to call one of it's functions in response response.

Firing hooks from publisher smart contracts still requires an off-chain process to sign a hook payload and broadcast a transaction to execute a function.  To put it another way, somebody has to pull the trigger on the publisher contract, by submitting a transsaction to the publisher contract in order to emit the hook event.  This is how it works today, and this proposal doesn't change that.  Where it does offer an improvement, is that each subscriber no longer needs it's own dedicated off-chain process for monitoring and responding to these events.  Instead, a single incentivized relayer can subscribe to many different events on behalf of multiple consumer contracts.

Thanks to innovations such as [web3 webhooks](https://moralis.io/web3-webhooks-the-ultimate-guide-to-blockchain-webhooks/), [web3 actions](https://blog.tenderly.co/new-features-web3-actions-war-rooms-sandbox-debugger-extension/), or [hal.xyz](hal.xyz) creating a relayer is easier than ever.

Examples of use cases that would benefit from this scheme include:

### Collateralised lending protocols

For example, Maker uses the [medianizer](https://docs.makerdao.com/smart-contract-modules/oracle-module/median-detailed-documentation) smart contract which maintains a whitelist of price feed contracts which are allowed to post price updates. Every time a new price update is received, the median of all feed prices is re-computed and the medianized value is updated.  In this case, the medianizer smart contract could fire a hook event that would allow subscriber contracts to decide to re-collateralize their positions.

### Automated market makers

AMM liquidity pools could fire a hook event whenever liquidity is added or removed.  This could allow a subscriber smart contracts to add or remove liquidity once the total pool liquidity reaches a certain point.

## Rationale

The rationale for this design is that it allows smart contract developers to write contract logic that listens and responds to events fired in other smart contracts, without requiring them to run some dedicated off-chain process to achieve this.  This best suits any simple smart contract logic that runs relatively infrequently in reponse to events in other contracts.

This improves on the existing solutions to achieve a pub/sub design pattern. To elaborate: a number of service providers currently offer "webhooks" as a way to subscribe to events emitted by smart contracts, by having some API endpoint called when the events are emitted, or alternatively offer some serverless feature that can be triggered by some smart contract event.  This approach works very well, but it does require that some API endpoint or serverless function be always available, which may require some dedicated server / process, which in turn will need to have some private key, and some amount of ETH in order to re-broadcast transactions.

This approach offers a more suitable alternative for when an "always-on" server instance is not desirable, e.g. in the case that it will be called infrequently.

This approach is similar in some ways to the erc-777 standard, which defines 'Hooks' that are fired when a contract receives erc-20 tokens, however this appraoch is a more generalized and scalable approach that allows hooks to be fired an any event, for any reason.

This proposal incorporates a decentralised market-driven relay network, and this decision is based on the fact that this is a highly scalable approach.  Conversely, it is possible to implement this functionality without resorting to a market-driven approach, by simply defining a standard for contract to allow other contracts to subscribe directly.  That approach is conceptually simpler, but has it's drawbacks, in so far as it requires a publisher contract to record subscribers in it's own state, creating an overhead for data management, upgradeability etc.  That approach would also require the publisher to call the subscriber contract's `Hook` function on each subscriver contract, which will incur potentially significant gas costs for the publisher contract, and would be a vector for denial of service attacks.

## Specification

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC 2119.

### Registering a Publisher

Both the publisher and subscriber contracts **MUST** register in a specific register contract, similarly to how smart contracts register an interface in the erc-1820 contract.

To register a hook in a publisher contract, the `registerHook` function **MUST** be called on the registry contract.  The parameters that need to be supplied are:

 - address - The publisher contract address, in the form of an ethereum address
 - bytes32 - The public key associated with the hook events
 - uint256 - The thread id that the hooks events will reference (a single contract can fire hook events with any number of threads, subscribers can choose which threads to subscribe to)

When the `registerHook` function is called on the registry contract, the registry contract **MUST** make a downstream call to the publisher contract address, by calling the publisher contract's `verifyHook` function, with the same arguments as passed to the `registerHook` function on the registry contract.  The `verifyHook` function in the publisher contract **MUST** return true in order to indicate that the contract will allow itself to be added to the registry as a publisher.  The registry contract **MUST** emit a `HookRegistered` event to indicate that a new publisher contract has been added.

### Updating a Publisher

Publishers may want to revoke or update public keys associated with a hook event, or indeed remove support for a hook event completely.  The registry contract **MUST** implement the `updatePublisher` function to allow for an existing publisher contract to be updated.  The registry contract **MUST** emit a `PublisherUpdated` event to indicate that the publisher contract was updated.

### Registering a Subscriber

To register a subscriber to a hook, the `registerSubscriber` function **MUST** be called on the registry contract with the following parameters:

 - address - The publisher contract address
 - bytes32 - The subscriber contract address
 - uint256 - The thread id to subscribe to
 - uint256 - the fee that the subscriber is willing to pay to get updates
 - uint256 - the chain id that the subscriber wants updates on
 - uint256 - the address of the token that the fee will be paid in or 0x0 for the chain's native asset (e.g. ETH)

 Note that while the chain id and the token address were not included in the original version of the spec, the simple addition of these two parameters allows for leveraging the relayers for cross chain messages, should the subcriber wish to do this, and allows to for payment in various tokens.

### Updating a subscriber

To update a subscription, the `updateSubscriber` function **MUST** be called with the same set of parameters as the `registerSubscriber` function.  This might be done in order to cancel a subscription, or to change the subscription fee.  Note that if the average gas fees on a network change over time, the subscription fee might not be enough to incentivise relayers to notify the subscribers of hook events, so in this case the subscription fee might want to be updated periodically. Note that the `updateSubscriber` function **MUST** maintain the same `msg.sender` that the `registerSubscriber` function was called with.

### Publishing an event

A publisher contract **SHOULD** emit a hook event from at least one function. The emitted event **MUST** be called `Hook` and **MUST** contain the following parameters:

 - uint256 (indexed) - threadId
 - uint256 (indexed) - nonce
 - uint8 - v
 - uint8 - r
 - uint8 - s
 - bytes32[] - payload

The signature **MUST** be based as arguments to the function that is emitting the `Hook` event, and this **MUST** originate from an EOA (obviously signatures can't be created on chain).  The payload **MAY** be passed to the function firing the event or **MAY** be generated by the contract itself, but the signature **MUST** sign a hash of the payload, and it is strongly recommended to use the erc-712 standard as described in the "Replay Attacks" section below.  This signature **SHOULD** be verified by the subscribers to ensure they are getting authentic events. The signature **MUST** correspond to the public key that was registered with the event.

The payload is encoded as an array of bytes32.  The subscriber smart contract **SHOULD** convert the bytes32 array into the required data type.  For example, if the payload is a snark proof, the actual payload might look something like:

 - uint256[2] a
 - uint256[2][2] b
 - uint256[2] c
 - uint256[1] input

In this case the publisher would need to serialize the variables into a bytes32 array, and the subscriber smart contract would need to deserialize it on the other end, e.g.:

```
a[0]     = uint256(bytes32(payload[0]));
a[1]     = uint256(bytes32(payload[1]));
b[0][0]  = uint256(bytes32(payload[2]));
b[0][1]  = uint256(bytes32(payload[3]));
b[1][0]  = uint256(bytes32(payload[4]));
b[1][1]  = uint256(bytes32(payload[5]));
c[0]     = uint256(bytes32(payload[6]));
c[1]     = uint256(bytes32(payload[7]));
input[0] = uint256(bytes32(payload[8]));
```

### Relayers

Relayers are independent parties that listen to `Hook` events on publisher smart contracts.  Relayers retrieve a list of subscribers for different hooks from the registry, and listen for hook events being fired on the publisher contracts.  Once a hook event has been fired by a publisher smart contract, relayers can decide to relay the hook event's payload and signature to the subscriber contracts by broadcasting a transaction that calls the subscriber contract's `executeHook` function.  Relayers are incentivised to do this because it is expected that the hook function will remunerate them with ETH, or potentially some other asset.

Relayers **SHOULD** simulate the transaction locally before broadcasting it to make sure that the contract has sufficient balance for payment of the fee.  Subscriber smart contracts are incentivised to maintain a sufficient balance to pay for hook events, because not maintaining a sufficient balance could cause relayers to blocklist them. Note that relayer blocklists are not part of the specification, but are logical likelyhood.

### Verifying a hook event

The `executeHook` function of the subscriber contracts **SHOULD** include logic to ensure that they are retrieving authentic events. To do this, subscriber contracts **SHOULD** create a hash of the required parameters, and **SHOULD** verify that the signature in the hook event is valid against the derived hash and the publisher's public key (see the erc-712 example for reference).  The hook function **SHOULD** also verify the nonce of the hook event and record it internally, in order to prevent replay attacks.  For optimal security, the subscriber contract **MAY** call the `verifyHookEvent` on the publisher contract in order to verify that the hook event is valid.  The publisher smart contract **MAY** implement the `verifyHookEvent`, which accepts the nonce of a Hook event, and checks it against a mapping of `hookId => nonce`.  The publisher contract **MAY** store every `Hook` event it emits in this mapping.

### Reference Implementation

IRegistry.sol
```js
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
```

IPublisher.sol
```js
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IPublisher.sol";

contract Publisher is IPublisher, Ownable {
    uint256 hookNonce;

    event Hook(
        uint256 indexed threadId,
        uint256 indexed nonce,
        uint8 v,
        bytes32 r,
        bytes32 s,
        bytes32 hashedMessage
    );

    mapping (uint256 => address) hooks;

    function fireHook(bytes32 hashedMessage, uint8 v, bytes32 r, bytes32 s) public onlyOwner {
        emit Hook(1, hookNonce++, v, r, s, hashedMessage);
    }

    function addHook(uint256 threadId, address publisherPubKey) public onlyOwner {
        hooks[threadId] = publisherPubKey;
    }

    function verifyEventHook(uint256 threadId, address publisherPubKey) public view override returns (bool) {
        return (hooks[threadId] == publisherPubKey);
    }

    function getEventHook(uint256 threadId) public view returns (address) {
        return hooks[threadId];
    }
}
```

ISubscriber.sol
```js
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

/// @title ISubscriber
/// @dev Implements a subscriber contract
interface ISubscriber {

    /// @dev Example of a function that is called when a hook is fired by a publisher
    /// @param hashedMessage Hash of the hook event payload that was signed
    /// @param v The v part of the signature
    /// @param r The r part of the signature
    /// @param s The s part of the signature
    function verifyEventHook(bytes32 hashedMessage, uint8 v, bytes32 r, bytes32 s) external returns (address);

    /// @dev Contains the logic to execute when a valid hook event has been received
    function executeHookLogic() external;
}
```

## Reference Implementation

registry.sol
```js
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./IRegistry.sol";
import "./IPublisher.sol";

contract Registry is IRegistry {
    event HookRegistered(
        address indexed publisherContract,
        address publisherPubKey,
        uint256 threadId
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
        uint256 fee
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
    mapping(address => mapping(address => mapping(uint256 => uint256))) public subscribers;

    /// records the owners of a subscriber contract so that updates can be authorized
    mapping(address => address) public owners;

    function registerHook(address publisherContract, uint256 threadId) public returns (bool) {
        require(
            (publishers[publisherContract][threadId] != address(0)),
            "Hook already registered"
        );

        require(verifyHook(publisherContract, threadId), "Publisher verification failed");

        publishers[publisherContract][threadId] = msg.sender;

        emit HookRegistered(publisherContract, msg.sender, threadId);

        return true;
    }

    function verifyHook(address publisherAddress, uint256 threadId) internal returns (bool) {
        return EventHookPublisher(publisherAddress).verifyEventHook(threadId, msg.sender);
    }

    function updateHook(address publisherContract, address publisherPubKey, uint256 threadId) public returns (bool) {
        require(publishers[publisherContract][threadId] == msg.sender, "Not authorized to update hook");

        publishers[publisherContract][threadId] = publisherPubKey;

        emit HookUpdated(publisherContract, publisherPubKey, threadId);

        return true;
    }

    function registerSubscriber(address publisherContract, address subscriberContract, uint256 threadId, uint256 fee) public returns (bool) {
        // there is probably a minimum amount we should consider, e.g. 21,000 wei
        require(fee > 0, "Fee must be greater than 0");

        require(
            subscribers[subscriberContract][publisherContract][threadId] != fee,
            "Hook already registered"
        );

        subscribers[subscriberContract][publisherContract][threadId] = fee;

        owners[subscriberContract] = msg.sender;

        emit SubscriberRegistered(publisherContract, subscriberContract, threadId, fee);

        return true;
    }

    function updateSubscriber(address publisherContract, address subscriberContract, uint256 threadId, uint256 fee) public returns (bool) {
        require(owners[subscriberContract] == msg.sender, "Not authorized to update subscriber");

        subscribers[subscriberContract][publisherContract][threadId] = fee;

        emit SubscriberUpdated(publisherContract, subscriberContract, threadId, fee);

        return true;
    }
}
```

publisher.sol
```js
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IPublisher.sol";

contract Publisher is IPublisher, Ownable {
    uint256 hookNonce;

    event Hook(
        uint256 indexed threadId,
        uint256 indexed nonce,
        bytes32 signature,
        bytes32 payload
    );

    mapping (uint256 => address) hooks;

    function fireHook(bytes32 hashedMessage, uint8 v, bytes32 r, bytes32 s) public onlyOwner {
        emit Hook(1, hookNonce++, signature, payload);
    }

    function addHook(uint256 threadId, address publisherPubKey) public onlyOwner {
        hooks[threadId] = publisherPubKey;
    }

    function verifyEventHook(uint256 threadId, address publisherPubKey) public view override returns (bool) {
        return (hooks[threadId] == publisherPubKey);
    }
}
```

subscriber.sol
```js
// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./ISubscriber.sol";

contract Subscriber is ISubscriber {
    address[] validPublishers;

    constructor() {
        validPublishers.push(0xdD4c825203f97984e7867F11eeCc813A036089D1);
    }

    function verifyEventHook(bytes32 hashedMessage, uint8 v, bytes32 r, bytes32 s) public returns (address) {
        bytes memory prefix = "\x19Ethereum Signed Message:\n32";

        bytes32 prefixedHashMessage = keccak256(abi.encodePacked(prefix, hashedMessage));

        address signer = ecrecover(prefixedHashMessage, v, r, s);

        bool publisherValid = false;

        for (uint i = 0; i < validPublishers.length; i++) {
            if (validPublishers[i] == signer) {
                publisherValid = true;
            }
        }

        if (publisherValid == true) {
            executeHookLogic();
        }

        return publisherValid ? signer : address(0);
    }

    function executeHookLogic() internal {
        // do something in response to hook
    }
}
```

## Security Considerations

### Griefing attacks

It is imperative that subscriber contracts trust the publisher contracts not to fire events that hold no intrinsic interest or value for them, as it is possible that malicious publisher contracts can publish a large number of events that will in turn drain the ETH from the subscriber contracts.  If the private key used to sign the hook events is ever compromised, then the potential to drain ETH from all subscriber contracts is a very real possibility.

### Front-running attacks

It is important for publishers and subscribers of hooks to realise that it is possible for a relayer to relay hook events before they are broadcast by examining the originating transaction in the mempool.  The normal flow is for the originating transaction to call a function in the publisher smart contract which in turn fires an event which is then picked up by relayers.  Competitive relayers will observe that it is possible to pluck the signature from the originating transaction from the mempool and simply relay it to subscriber contracts before the originating transaction has been actually included in a block.  In fact, it is possible that the subscriber contracts process the event before the originating transaction is processed, based purely on gas fee dynamics.

To this end, publishers must bear in mind that the transaction that fires hooks should not affect significant state changes, and that ideally any state changes should be finalised in a block before the transaction that fires the hook event is even broadcast.  The hook event should really only be used as a P2P messaging bus, rather than being used for state changes.  The two concerns should be separate. That being said, it is possible to mitigate against this sort of front-running risk by implementing the `verifyHook` function in the publisher smart contract, which will be called by subscriber contracts to verify that the hook they have been notified of has indeed been triggered by the publisher smart contract, and that the transaction that triggered the hook event has been finalised.

Another risk from front-running affects relayers, whereby the relayer's transactions to the subscriber contracts can be front-run by generalized MEV searchers in the mempool.  It is likely that this sort of MEV capture will occurr in the public mempool, and therefore it is advised that relayers use private channels to block builders to mitigate against this issue.  By broadcasting transcations to a segrated mempool, relayers protect themselves from front-running by generalized MEV bots, but their transactions can still fail due to competition from other relayers.  If two or more relayers decide to start relaying hook events from the same publisher, than the relay transactions with the highest gas price will be executed before the others.  This will result in the other relayer's transactions failing on-chain, by being included later in the same block.  For now, there are certain transaction optimisation services that will prevent transactions from failing on-chain, which will offer a solution to this problem, though this is out-of-scope for this document.  A future iteration of this proposal may well include the option for trusted relayers, who can enter into an on-chain enforceable agreement with subscribers, which shoudl reduce the race-to-the-bottom competitive gas fee issue.

### Replay attacks

It is advised to use the erc-712 standard in order to prevent cross network replay attacks, where the same contract deployed on more than one network can have it's hook events pushed to subscribers on other networks, e.g. a publisher contract on Polygon can fire an hook event that could be relayed to a subscriber contract on Gnosis Chain.  Whereas the keys used to sign the hook events should ideally be unique, in reality this may not always be the case.

For this reason, it is recommended to use erc-721 Typed Data Signatures.  In this case the off-chain process that initiates the hook should create the signature according to the following data structure:

```js
const domain = [
    {name: "name", type: "string" },
    {name: "version", type: "string"},
    {name: "chainId", type: "uint256"},
    { name: "verifyingContract", type: "address" },
    { name: "salt", type: "bytes32" },
]
 
const hook = [
    {"name": "payload", "type": "string"},
]
 
const domainData = {
    name: "Name of Publisher Dapp",
    version: "1",
    chainId: parseInt(web3.version.network, 10),
    verifyingContract: "0x123456789abcedf....publisher contract address",
    salt: "0x123456789abcedf....random hash unique to publisher contract"
}
 
const message = {
    payload: "RLP encoded payload"
}
 
const eip712TypedData = {
    types: {
        EIP712Domain: domain,
        Hook: hook
    },
    domain: domainData,
    primaryType: "Hook",
    message: message
}
```

Verifying in subscriber smart contract:

```js
contract SubscriberExample {
    
    struct EIP712Domain {
        string  name;
        string  version;
        uint256 chainId;
        address verifyingContract;
    }

    struct Hook {
        string payload;
        uint256 threadId;
        uint256 nonce;
    }

    bytes32 constant EIP712DOMAIN_TYPEHASH = keccak256(
        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
    );

    bytes32 constant HOOK_TYPEHASH = keccak256(
        "Hook(string payload,uint256 threadId,uint256 nonce)"
    );

    bytes32 DOMAIN_SEPARATOR;

    constructor () public {
        DOMAIN_SEPARATOR = hash(EIP712Domain({
            name: "Name of Publisher Dapp",
            version: '1',
            chainId: 1,
            verifyingContract: "0x123456789abcedf....publisher contract address"
        }));
    }

    function hash(EIP712Domain eip712Domain) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            EIP712DOMAIN_TYPEHASH,
            keccak256(bytes(eip712Domain.name)),
            keccak256(bytes(eip712Domain.version)),
            eip712Domain.chainId,
            eip712Domain.verifyingContract
        ));
    }

    function hash(Hook hook) internal pure returns (bytes32) {
        return keccak256(abi.encode(
            HOOK_TYPEHASH,
            keccak256(bytes(hook.payload)),
            keccak256(bytes(hook.threadId)),
            keccak256(bytes(hook.nonce)),
        ));
    }

    function verify(Hook hook, uint8 v, bytes32 r, bytes32 s) internal view returns (bool) {
        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            DOMAIN_SEPARATOR,
            hash(hook)
        ));
        
        return ecrecover(digest, v, r, s) == address(0); // should be same s publisher's registered public key
    }
}        
```

Replay attacks can also occur on the same network that the event hook was fired, by simply re-broadcasting an event hook that was already broadcast previously.  For this reason, subscriber contracts should check that a nonce is included in the event hook being received, and record the nonce in the contract's state.  If the hook nonce is not valid, or has already been recorded, the transaction should revert.

It is worth noting that the `chainId` event topic should also be used to prevent cross chain replay attacks, in the case that a dapp is deployed on multiple networks.

There is also the possibilty to leverage the `chainId` for more than preventing replay attacks, but also for accepting messages from other chains.

## Copyright

Copyright and related rights waived via CC0.