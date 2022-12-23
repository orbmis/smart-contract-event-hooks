// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IPublisher.sol";

contract Publisher is IPublisher, Ownable {
    uint256 public hookNonce = 1;

    // mappoing of threadId to nonce to digest (payload data hash)
    mapping(uint256 => mapping(uint256 => bytes32)) public firedHooks;

    event Hook(
        uint256 indexed threadId,
        uint256 indexed nonce,
        bytes32 digest,
        bytes payload,
        bytes32 checksum
    );

    mapping(uint256 => address) public hooks;

    function fireHook(
        bytes calldata payload,
        bytes32 digest,
        uint256 threadId
    ) public onlyOwner {
        // nonces should be initiated to 1,
        // therefore first hook's nonce will always be 2
        hookNonce++;

        bytes32 checksum = keccak256(abi.encodePacked(digest, block.number));

        firedHooks[threadId][hookNonce] = checksum;

        emit Hook(threadId, hookNonce, digest, payload, checksum);
    }

    function addHook(uint256 threadId, address publisherPubKey)
        public
        onlyOwner
    {
        hooks[threadId] = publisherPubKey;
    }

    function verifyEventHookRegistration(
        uint256 threadId,
        address publisherPubKey
    ) public view override returns (bool) {
        return (hooks[threadId] == publisherPubKey);
    }

    function verifyEventHook(
        bytes32 payloadhash,
        uint256 threadId,
        uint256 nonce,
        uint256 blockheight
    ) external view returns (bool) {
        bytes32 checksum = keccak256(
            abi.encodePacked(payloadhash, blockheight)
        );

        bool result = firedHooks[threadId][nonce] == checksum;

        return result;
    }

    function getEventHook(uint256 threadId) public view returns (address) {
        return hooks[threadId];
    }
}
