// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IPlayverseStake {
    struct Stake {
        address player;
        uint256 amount;
        uint256 timestamp;
        bool claimed;
        uint8 tier;
    }

    event StakePlaced(bytes32 indexed gameId, address indexed player, uint256 amount, uint8 tier);
    event GameResolved(bytes32 indexed gameId, address indexed player, bool playerWon, uint256 payout, uint256 fee);
    event MultiplayerGameResolved(bytes32 indexed gameId, address indexed winner, uint256 prize);

    function placeStake(bytes32 gameId) external payable;
    function createMultiplayerGame(bytes32 gameId) external payable;
    function joinMultiplayerGame(bytes32 gameId) external payable;
    function refundStake(bytes32 gameId) external;
    function getPlayerStats(address player) external view returns (uint256 wins, uint256 losses, uint256 winnings);
}
