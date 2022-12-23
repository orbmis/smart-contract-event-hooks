// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./ISubscriber.sol";
import "./IPublisher.sol";

contract SubscriberTwo is ISubscriber, Ownable {
    uint256 public constant RELAYER_FEE = 0.001 ether;
    uint256 public constant MAX_AGE = 4;
    uint256 public constant STARTING_GAS = 21000;
    uint256 public constant VERIFY_HOOK_ENTRY_GAS = 8000;
    uint256 public constant VERIFY_HOOK_GAS_COST = 30000;
    uint256 public constant MAX_GAS_PRICE = 10000000000;

    uint256 public constant MAX_GAS_ALLOWED =
        STARTING_GAS + VERIFY_HOOK_ENTRY_GAS + VERIFY_HOOK_GAS_COST;

    event ValueReceived(address user, uint256 amount);

    // mapping of publisher address to threadId to nonce
    mapping(address => mapping(uint256 => uint256)) public validPublishers;

    function updateValidPublishers(
        address publisher,
        uint256 threadId,
        uint256 nonce
    ) public onlyOwner {
        require(nonce > 0, "nonce must be greater than zero");

        validPublishers[publisher][threadId] = nonce;
    }

    function getPublisherNonce(address publisher, uint256 threadId)
        public
        view
        returns (uint256)
    {
        return validPublishers[publisher][threadId];
    }

    receive() external payable {
        emit ValueReceived(msg.sender, msg.value);
    }

    function verifyHook(
        address publisher,
        bytes calldata payload,
        uint256 threadId,
        uint256 nonce,
        uint256 blockheight
    ) public {
        uint256 gasStart = gasleft();

        bool isHookValid = IPublisher(publisher).verifyEventHook(
            keccak256(payload),
            threadId,
            nonce,
            blockheight
        );

        // checks
        require(isHookValid, "Hook not verified by publisher");
        require(
            nonce > validPublishers[publisher][threadId],
            "Obsolete hook detected"
        );
        require(tx.gasprice <= MAX_GAS_PRICE, "Gas price is too high");
        require(blockheight < block.number, "Hook event not valid yet");
        require((block.number - blockheight) < MAX_AGE, "Hook has expired");

        require(
            validPublishers[publisher][threadId] != 0,
            "Publisher not valid"
        );

        // effects
        validPublishers[publisher][threadId] = nonce;

        // interactions
        (bool result, ) = msg.sender.call{value: RELAYER_FEE}("");

        require(result, "Failed to send relayer fee");

        require(
            (gasStart - gasleft()) < MAX_GAS_ALLOWED,
            "Function call exceeded gas allowance"
        );
    }
}
