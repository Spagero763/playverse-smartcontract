// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title PlayverseStake
 * @notice Gaming stake contract with support for multiple stake tiers and multiplayer games
 * @dev Implements stake management with fee distribution and timeout refunds
 */
contract PlayverseStake is Ownable, ReentrancyGuard, Pausable {
    // Stake tier constants
    uint256 public constant TIER_BRONZE = 1_000_000_000; // 0.001 ETH
    uint256 public constant TIER_SILVER = 10_000_000_000; // 0.01 ETH
    uint256 public constant TIER_GOLD = 100_000_000_000; // 0.1 ETH
    uint256 public constant TIER_PLATINUM = 1e18; // 1 ETH/CELO

    // Fee configuration
    uint256 public feeBps = 100; // 1.00% default (100 bps = 1%)
    uint256 public constant MAX_BPS = 10_000;
    uint256 public constant MAX_FEE_BPS = 1000; // 10% max fee

    // Timeout for refunds
    uint256 public timeout = 1 days;
    
    // Minimum players for multiplayer games
    uint256 public constant MIN_PLAYERS = 2;
    uint256 public constant MAX_PLAYERS = 10;

    // Stake structure
    struct Stake {
        address player;
        uint256 amount;
        uint256 timestamp;
        bool claimed;
        uint8 tier;
    }

    // Multiplayer game structure
    struct MultiplayerGame {
        bytes32 gameId;
        address[] players;
        uint256 stakeAmount;
        uint256 totalPool;
        bool resolved;
        address winner;
    }

    // Storage
    mapping(bytes32 => Stake) public stakes;
    mapping(bytes32 => MultiplayerGame) public multiplayerGames;
    mapping(address => uint256) public playerWins;
    mapping(address => uint256) public playerLosses;
    mapping(address => uint256) public totalWinnings;

    // Events
    event StakePlaced(bytes32 indexed gameId, address indexed player, uint256 amount, uint8 tier);
    event GameResolved(bytes32 indexed gameId, address indexed player, bool playerWon, uint256 payout, uint256 fee);
    event Refunded(bytes32 indexed gameId, address indexed player, uint256 amount);
    event FeeWithdrawn(address indexed to, uint256 amount);
    event FeeUpdated(uint256 newFeeBps);
    event TimeoutUpdated(uint256 newTimeout);
    event MultiplayerGameCreated(bytes32 indexed gameId, uint256 stakeAmount);
    event PlayerJoined(bytes32 indexed gameId, address indexed player);
    event MultiplayerGameResolved(bytes32 indexed gameId, address indexed winner, uint256 prize);

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Get stake tier for amount
     */
    function getTier(uint256 amount) public pure returns (uint8) {
        if (amount == TIER_PLATINUM) return 4;
        if (amount == TIER_GOLD) return 3;
        if (amount == TIER_SILVER) return 2;
        if (amount == TIER_BRONZE) return 1;
        return 0;
    }

    /**
     * @notice Place a stake for a solo game
     */
    function placeStake(bytes32 gameId) external payable whenNotPaused nonReentrant {
        require(stakes[gameId].player == address(0), "Game already staked");
        uint8 tier = getTier(msg.value);
        require(tier > 0, "Invalid stake amount");

        stakes[gameId] = Stake({
            player: msg.sender,
            amount: msg.value,
            timestamp: block.timestamp,
            claimed: false,
            tier: tier
        });

        emit StakePlaced(gameId, msg.sender, msg.value, tier);
    }

    /**
     * @notice Create a multiplayer game
     */
    function createMultiplayerGame(bytes32 gameId) external payable whenNotPaused nonReentrant {
        require(multiplayerGames[gameId].gameId == bytes32(0), "Game exists");
        uint8 tier = getTier(msg.value);
        require(tier > 0, "Invalid stake amount");

        address[] memory players = new address[](1);
        players[0] = msg.sender;

        multiplayerGames[gameId] = MultiplayerGame({
            gameId: gameId,
            players: players,
            stakeAmount: msg.value,
            totalPool: msg.value,
            resolved: false,
            winner: address(0)
        });

        emit MultiplayerGameCreated(gameId, msg.value);
        emit PlayerJoined(gameId, msg.sender);
    }

    /**
     * @notice Join a multiplayer game
     */
    function joinMultiplayerGame(bytes32 gameId) external payable whenNotPaused nonReentrant {
        MultiplayerGame storage game = multiplayerGames[gameId];
        require(game.gameId != bytes32(0), "Game not found");
        require(!game.resolved, "Game already resolved");
        require(game.players.length < MAX_PLAYERS, "Game full");
        require(msg.value == game.stakeAmount, "Wrong stake amount");

        // Check player not already in game
        for (uint i = 0; i < game.players.length; i++) {
            require(game.players[i] != msg.sender, "Already joined");
        }

        game.players.push(msg.sender);
        game.totalPool += msg.value;

        emit PlayerJoined(gameId, msg.sender);
    }

    /**
     * @notice Resolve multiplayer game with winner
     */
    function resolveMultiplayerGame(bytes32 gameId, address winner) external onlyOwner nonReentrant {
        MultiplayerGame storage game = multiplayerGames[gameId];
        require(game.gameId != bytes32(0), "Game not found");
        require(!game.resolved, "Already resolved");
        require(game.players.length >= MIN_PLAYERS, "Not enough players");

        bool validWinner = false;
        for (uint i = 0; i < game.players.length; i++) {
            if (game.players[i] == winner) {
                validWinner = true;
                break;
            }
        }
        require(validWinner, "Invalid winner");

        game.resolved = true;
        game.winner = winner;

        uint256 fee = (game.totalPool * feeBps) / MAX_BPS;
        uint256 prize = game.totalPool - fee;

        playerWins[winner]++;
        totalWinnings[winner] += prize;

        for (uint i = 0; i < game.players.length; i++) {
            if (game.players[i] != winner) {
                playerLosses[game.players[i]]++;
            }
        }

        (bool sent, ) = winner.call{value: prize}("");
        require(sent, "Prize transfer failed");

        emit MultiplayerGameResolved(gameId, winner, prize);
    }

    /**
     * @notice Resolve solo game
     */
    function resolveGame(bytes32 gameId, bool playerWon) external onlyOwner nonReentrant {
        Stake storage stake = stakes[gameId];
        require(stake.player != address(0), "No stake exists");
        require(!stake.claimed, "Already claimed");

        stake.claimed = true;
        uint256 fee = (stake.amount * feeBps) / MAX_BPS;
        uint256 payout = playerWon ? (stake.amount * 2 - fee) : 0;

        if (playerWon) {
            playerWins[stake.player]++;
            totalWinnings[stake.player] += payout;
            (bool sent, ) = stake.player.call{value: payout}("");
            require(sent, "Payout failed");
        } else {
            playerLosses[stake.player]++;
            fee = stake.amount;
        }

        emit GameResolved(gameId, stake.player, playerWon, payout, fee);
    }

    /**
     * @notice Refund stake after timeout
     */
    function refundStake(bytes32 gameId) external nonReentrant {
        Stake storage stake = stakes[gameId];
        require(stake.player != address(0), "No stake");
        require(!stake.claimed, "Already claimed");
        require(msg.sender == stake.player, "Not staker");
        require(block.timestamp >= stake.timestamp + timeout, "Too early");

        stake.claimed = true;
        (bool sent, ) = stake.player.call{value: stake.amount}("");
        require(sent, "Refund failed");

        emit Refunded(gameId, stake.player, stake.amount);
    }

    /**
     * @notice Get player statistics
     */
    function getPlayerStats(address player) external view returns (uint256 wins, uint256 losses, uint256 winnings) {
        return (playerWins[player], playerLosses[player], totalWinnings[player]);
    }

    /**
     * @notice Withdraw accumulated fees
     */
    function withdrawFees(address payable to) external onlyOwner nonReentrant {
        uint256 balance = address(this).balance;
        require(balance > 0, "No balance");
        (bool sent, ) = to.call{value: balance}("");
        require(sent, "Withdrawal failed");
        emit FeeWithdrawn(to, balance);
    }

    function setFeeBps(uint256 _feeBps) external onlyOwner {
        require(_feeBps <= MAX_FEE_BPS, "Fee too high");
        feeBps = _feeBps;
        emit FeeUpdated(_feeBps);
    }

    function setTimeout(uint256 _timeout) external onlyOwner {
        timeout = _timeout;
        emit TimeoutUpdated(_timeout);
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    receive() external payable {}
    fallback() external payable {}
}
