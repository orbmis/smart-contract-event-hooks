// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "./ISubscriber.sol";

contract Subscriber is ISubscriber {
    address[] validPublishers;

    bool stateToggleSwitch;

    // TODO: replay attacks - record nonces

    bytes32 private constant DOMAIN_TYPEHASH = keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)");
    bytes32 private constant DOMAIN_SALT = 0xb225c57bf2111d6955b97ef0f55525b5a400dc909a5506e34b102e193dd53406;
    bytes32 private constant DOMAIN_NAME_HASH = keccak256("Hook");
    bytes32 private constant DOMAIN_VERSION_HASH = keccak256("1");
    bytes32 private constant TYPE_HASH = keccak256("Hook(bytes32 payload)");

    constructor () {
        stateToggleSwitch = false;
    }

    function addPublisher(address publisherAddress) public {
        validPublishers.push(publisherAddress);
    }

    // NB:  Remember to record and verify the nonces !!!!

    // https://www.theweb3dev.com/blog/on-chain-authentication
    // https://blog.mycrypto.com/the-magic-of-digital-signatures-on-ethereum
    // https://github.com/decentral-ee/eip712-helpers
    function verifyHook(bytes32[] memory message, address publisher,
        uint8 v, bytes32 r, bytes32 s) public view returns (address signer, bytes32 payload) {
        uint256 chainId;

        assembly {
            chainId := chainid()
        }

        bytes32 domainHash = keccak256(abi.encode(
            DOMAIN_TYPEHASH,
            DOMAIN_NAME_HASH,
            DOMAIN_VERSION_HASH,
            chainId,
            address(this),
            DOMAIN_SALT)
        );

        payload = keccak256(abi.encode(message[0], message[1], message[2]));

        bytes32 messageHash = keccak256(abi.encode(
            TYPE_HASH,
            payload));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            domainHash,
            messageHash));

        signer = ecrecover(digest, v, r, s);

        require(signer == publisher);
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

    // do something in response to verified hook
    function executeHookLogic() internal {
        stateToggleSwitch = !stateToggleSwitch;
    }
}