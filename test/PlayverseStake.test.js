const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("PlayverseStake", function () {
  let contract, owner, player1, player2;
  const TIER_BRONZE = ethers.parseUnits("0.001", "ether");
  const TIER_SILVER = ethers.parseUnits("0.01", "ether");

  beforeEach(async function () {
    [owner, player1, player2] = await ethers.getSigners();
    const PlayverseStake = await ethers.getContractFactory("PlayverseStake");
    contract = await PlayverseStake.deploy();
  });

  describe("Solo Games", function () {
    it("should place stake", async function () {
      const gameId = ethers.encodeBytes32String("game1");
      await contract.connect(player1).placeStake(gameId, { value: TIER_BRONZE });
      const stake = await contract.stakes(gameId);
      expect(stake.player).to.equal(player1.address);
    });

    it("should resolve game with win", async function () {
      const gameId = ethers.encodeBytes32String("game2");
      await owner.sendTransaction({ to: contract.target, value: TIER_BRONZE });
      await contract.connect(player1).placeStake(gameId, { value: TIER_BRONZE });
      await contract.resolveGame(gameId, true);
      const [wins] = await contract.getPlayerStats(player1.address);
      expect(wins).to.equal(1n);
    });
  });

  describe("Multiplayer Games", function () {
    it("should create and join multiplayer game", async function () {
      const gameId = ethers.encodeBytes32String("multi1");
      await contract.connect(player1).createMultiplayerGame(gameId, { value: TIER_SILVER });
      await contract.connect(player2).joinMultiplayerGame(gameId, { value: TIER_SILVER });
      const game = await contract.multiplayerGames(gameId);
      expect(game.totalPool).to.equal(TIER_SILVER * 2n);
    });
  });
});
