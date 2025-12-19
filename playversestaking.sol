// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

contract PlayverseStake is Ownable, ReentrancyGuard, Pausable {
    uint256 public constant BASE_STAKE_WEI = 1_000_000_000; // 0.001 ETH
    uint256 public constant CELO_STAKE_WEI = 1e18; // 1 CELO

    uint256 public feeBps = 100; // 1.00% by default (100 bps = 1%)
    uint256 public constant MAX_BPS = 10_000; // 100% in basis points

    uint256 public timeout = 1 days; // Default timeout for refunds

    struct Stake {
        address player;
        uint256 amount;
        uint256 timestamp;
        bool claimed;
    }

    mapping(bytes32 => Stake) public stakes;

    // Events
    event StakePlaced(bytes32 indexed gameId, address indexed player, uint256 amount);
    event GameResolved(bytes32 indexed gameId, address indexed player, bool playerWon, uint256 payout, uint256 fee);
    event Refunded(bytes32 indexed gameId, address indexed player, uint256 amount);
    event FeeWithdrawn(address indexed to, uint256 amount);
    event FeeUpdated(uint256 newFeeBps);
    event TimeoutUpdated(uint256 newTimeout);

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Place a stake for a game.
     * @dev Only accepts `BASE_STAKE_WEI` or `CELO_STAKE_WEI`.
     * @param gameId Unique identifier for the game (client-generated)
     */
    function placeStake(bytes32 gameId) external payable whenNotPaused nonReentrant {
        require(stakes[gameId].player == address(0), "Game already staked");
        require(msg.value == BASE_STAKE_WEI || msg.value == CELO_STAKE_WEI, "Invalid stake amount");

        stakes[gameId] = Stake({
            player: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp,
            claimed: false
        });

        emit StakePlaced(gameId, msg.sender, msg.value);
    }

    /**
     * @notice Owner resolves the game outcome.
     * @dev Transfers payout to player if they won; otherwise, keeps stake as fee.
     * @param gameId The game ID to resolve
     * @param playerWon Whether the player won (true) or lost (false)
     */
    function resolveGame(bytes32 gameId, bool playerWon) external onlyOwner nonReentrant {
        Stake storage stake = stakes[gameId];
        require(stake.player != address(0), "No stake exists");
        require(!stake.claimed, "Stake already claimed");

        stake.claimed = true;
        uint256 fee = (stake.amount * feeBps) / MAX_BPS;
        uint256 payout = playerWon ? (stake.amount - fee) : 0;

        if (playerWon) {
            (bool sent, ) = stake.player.call{value: payout}("");
            require(sent, "Payout transfer failed");
        } else {
            fee = stake.amount; // Entire stake becomes fee if player lost
        }

        emit GameResolved(gameId, stake.player, playerWon, payout, fee);
    }

    /**
     * @notice Player refunds their stake if unresolved after `timeout`.
     * @param gameId The game ID to refund
     */
    function refundStake(bytes32 gameId) external nonReentrant {
        Stake storage stake = stakes[gameId];
        require(stake.player != address(0), "No stake exists");
        require(!stake.claimed, "Stake already claimed");
        require(msg.sender == stake.player, "Not the staker");
        require(block.timestamp >= stake.timestamp + timeout, "Refund too early");

        stake.claimed = true;
        (bool sent, ) = stake.player.call{value: stake.amount}("");
        require(sent, "Refund transfer failed");

        emit Refunded(gameId, stake.player, stake.amount);
    }

    /**
     * @notice Withdraw accumulated fees to `to` address.
     * @param to Recipient address for fees
     */
    function withdrawFees(address payable to) external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance to withdraw");

        (bool sent, ) = to.call{value: balance}("");
        require(sent, "Withdrawal failed");

        emit FeeWithdrawn(to, balance);
    }

    // ---------------- Owner Utilities ----------------
    function setFeeBps(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= 1000, "Fee too large (max 10%)");
        feeBps = _feeBps;
        emit FeeUpdated(_feeBps);
    }

    function setTimeout(uint256 _timeout) external onlyOwner {
        timeout = _timeout;
        emit TimeoutUpdated(_timeout);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Allow direct ETH/CELO funding (e.g., for initial liquidity)
    receive() external payable {}
    fallback() external payable {}
}