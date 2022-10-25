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

    mapping (uint256 => address) public hooks;

    function fireHook(bytes32 hashedMessage, uint256 threadId, uint8 v, bytes32 r, bytes32 s) public onlyOwner {
        emit Hook(threadId, hookNonce++, v, r, s, hashedMessage);
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