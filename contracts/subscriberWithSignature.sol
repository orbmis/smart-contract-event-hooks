// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ISubscriber.sol";

contract SubscriberWithSignature is ISubscriber, Ownable {
    uint256 public constant RELAYER_FEE = 0.001 ether;
    uint256 public constant MAX_AGE = 3;
    uint256 public constant STARTING_GAS = 21000;
    uint256 public constant VERIFY_HOOK_ENTRY_GAS = 8000;
    uint256 public constant VERIFY_HOOK_GAS_COST = 30000;
    uint256 public constant MAX_GAS_PRICE = 10000000000;

    uint256 public constant MAX_GAS_ALLOWED =
        STARTING_GAS + VERIFY_HOOK_ENTRY_GAS + VERIFY_HOOK_GAS_COST;

    // mapping of publisher address to threadId to nonce
    mapping(address => mapping(uint256 => uint256)) public validPublishers;

    bytes32 private constant DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract,bytes32 salt)"
        );

    bytes32 private constant DOMAIN_SALT =
        0x5db5bd0cd6f41d9d705525bc4773e06c1cdcb68185b4e00b0b26cc7d2e23761d;

    bytes32 private constant DOMAIN_NAME_HASH = keccak256("Hook");

    bytes32 private constant DOMAIN_VERSION_HASH = keccak256("1");

    bytes32 private constant TYPE_HASH =
        keccak256(
            "Hook(bytes32 payload,uint256 nonce,uint256 blockheight,uint256 threadId)"
        );

    receive() external payable { }

    function updateValidPublishers(
        address publisherAddress,
        uint256 threadId,
        uint256 nonce
    ) public onlyOwner {
        require(nonce > 0, "nonce must be greater than zero");

        validPublishers[publisherAddress][threadId] = nonce;
    }

    function getPublisherNonce(address publisherAddress, uint256 threadId)
        public
        view
        returns (uint256)
    {
        return validPublishers[publisherAddress][threadId];
    }

    function verifyHook(
        address publisher,
        bytes calldata payload,
        uint256 threadId,
        uint256 nonce,
        uint256 blockheight
    ) public {
        uint256 gasStart = gasleft();

        bytes32 message = keccak256(payload[65:161]);

        bytes32 messageHash = keccak256(
            abi.encode(TYPE_HASH, message, nonce, blockheight, threadId)
        );

        bytes32 domainHash = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                DOMAIN_NAME_HASH,
                DOMAIN_VERSION_HASH,
                block.chainid,
                publisher,
                DOMAIN_SALT
            )
        );

        bytes32 digest = keccak256(
            abi.encodePacked("\x19\x01", domainHash, messageHash)
        );

        bytes memory _sigv = bytes(payload[64:65]);

        address signer = ecrecover(
            digest,
            uint8(_sigv[0]),
            bytes32(payload[:32]),
            bytes32(payload[32:64])
        );

        // checks
        require(
            nonce > validPublishers[signer][threadId],
            "Obsolete hook detected"
        );
        require(signer == publisher, "Publisher not signer");
        require(validPublishers[signer][threadId] != 0, "Publisher not valid");
        require(tx.gasprice <= MAX_GAS_PRICE, "Gas price is too high");
        require(blockheight < block.number, "Hook event not valid yet");
        require((block.number - blockheight) < MAX_AGE, "Hook has expired");

        // effects
        validPublishers[signer][threadId] = nonce;

        // interactions
        (bool result, ) = msg.sender.call{value: RELAYER_FEE}("");

        require(result, "Failed to send relayer fee");

        require(
            (gasStart - gasleft()) < MAX_GAS_ALLOWED,
            "Function call exceeded gas allowance"
        );
    }
}
