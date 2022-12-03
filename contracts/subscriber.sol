// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ISubscriber.sol";

contract Subscriber is ISubscriber, Ownable {
    uint256 public constant MAX_AGE = 300;
    uint256 public constant STARTING_GAS = 21000;
    uint256 public constant VERIFY_HOOK_ENTRY_GAS = 8000;
    uint256 public constant MAX_GAS_ALLOWED = STARTING_GAS + VERIFY_HOOK_ENTRY_GAS;
    uint256 public constant MAX_GAS_PRICE = 10000000000;

    event ValueReceived(address user, uint256 amount);

    // mapping of publisher address to threadId to nonce
    mapping(address => mapping(uint256 => uint256)) public validPublishers;

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
        keccak256("Hook(bytes32 payload,uint256 nonce,uint256 blockheight,uint256 threadId)");

    constructor() {
        currentNonce = 1;
    }

    function addPublisher(address publisherAddress, uint256 threadId)
        public
        onlyOwner
    {
        validPublishers[publisherAddress][threadId] = 1;
    }

    function getPublisherNonce(address publisherAddress, uint256 threadId)
        public
        view
        returns (uint256)
    {
        return validPublishers[publisherAddress][threadId];
    }

    receive() external payable {
        emit ValueReceived(msg.sender, msg.value);
    }

    function verifyHook(
        bytes32[] memory payload,
        uint256 threadId,
        uint256 nonce,
        uint256 blockheight,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public returns (address signer, bytes32 message) {
        uint256 gasStart = gasleft();

        bytes32 domainHash = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                DOMAIN_NAME_HASH,
                DOMAIN_VERSION_HASH,
                block.chainid,
                address(this),
                DOMAIN_SALT
            )
        );

        message = keccak256(abi.encode(payload[0], payload[1], payload[2]));

        bytes32 messageHash = keccak256(
            abi.encode(TYPE_HASH, message, nonce, blockheight, threadId)
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainHash, messageHash)
        );

        signer = ecrecover(digest, v, r, s);

        bool isPublisherValid = validPublishers[signer][threadId] != 0;

        // checks
        require(nonce > currentNonce, "Obsolete hook detected");
        require(isPublisherValid, "Publisher not valid");
        require(tx.gasprice <= MAX_GAS_PRICE, "Gas price is too high");
        // require(blockheight < block.number, "Hook event not valid yet");
        // require((blockheight - block.number) < MAX_AGE, "Hook event has expired");

        // effects
        currentNonce = nonce;

        // interactions
        (bool result, ) = msg.sender.call{value: RELAYER_FEE}("");

        require(result, "Failed to send relayer fee");

        require(
            (gasStart - gasleft()) < MAX_GAS_ALLOWED,
            "Function call exceeded gas allowance"
        );
    }
}
