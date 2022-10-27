// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ISubscriber.sol";

contract Subscriber is ISubscriber, Ownable {

    event ValueReceived(address user, uint amount);

    address[] public validPublishers;

    bool stateToggleSwitch;

    uint256 public currentNonce;

    uint256 private constant RELAYER_FEE = 0.001 ether;

    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)"
        );

    bytes32 private constant DOMAIN_SALT =
        0x5db5bd0cd6f41d9d705525bc4773e06c1cdcb68185b4e00b0b26cc7d2e23761d;

    bytes32 private constant DOMAIN_NAME_HASH = keccak256("Hook");

    bytes32 private constant DOMAIN_VERSION_HASH = keccak256("1");

    bytes32 private constant TYPE_HASH =
        keccak256("Hook(bytes32 payload,uint256 nonce)");

    constructor() {
        stateToggleSwitch = false;
        currentNonce = 1;
    }

    function addPublisher(address publisherAddress) public onlyOwner {
        validPublishers.push(publisherAddress);
    }

    receive() external payable {
        emit ValueReceived(msg.sender, msg.value);
    }

    function verifyHook(
        bytes32[] memory message,
        uint256 nonce,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public returns (address signer, bytes32 payload) {
        require(nonce > currentNonce, "Obsolete hook detected");

        uint256 chainId;

        assembly {
            chainId := chainid()
        }

        bytes32 domainHash = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                DOMAIN_NAME_HASH,
                DOMAIN_VERSION_HASH,
                chainId,
                address(this),
                DOMAIN_SALT
            )
        );

        payload = keccak256(abi.encode(message[0], message[1], message[2]));

        bytes32 messageHash = keccak256(abi.encode(TYPE_HASH, payload, nonce));

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainHash, messageHash)
        );

        signer = ecrecover(digest, v, r, s);

        bool isPublisherValid = false;

        for (uint256 i = 0; i < validPublishers.length; i++) {
            isPublisherValid = isPublisherValid || validPublishers[i] == signer;
        }

        require(isPublisherValid, "Publisher not valid");

        currentNonce = nonce;

        (bool result, ) = msg.sender.call{value: RELAYER_FEE}("");

        require(result, "Failed to send relayer fee");
    }
}
