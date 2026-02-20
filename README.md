# Playverse Staking Smart Contract

A Solidity smart contract for gaming stakes with multiplayer support, deployed on EVM-compatible chains.

## Features

- **Tiered Stakes** - Bronze (0.001), Silver (0.01), Gold (0.1), Platinum (1.0) ETH
- **Solo Games** - 1v1 stake-based gaming with 2x potential payout
- **Multiplayer Games** - Support for 2-10 players, winner takes pool
- **Player Statistics** - Track wins, losses, and total winnings
- **Fee System** - Configurable platform fee (default 1%)
- **Timeout Refunds** - Auto-refund after 24 hours if unresolved
- **Security** - ReentrancyGuard, Pausable, Ownable

## Contract Functions

### Player Functions
| Function | Description |
|----------|-------------|
| \placeStake\ | Place a stake for solo game |
| \createMultiplayerGame\ | Create and join multiplayer game |
| \joinMultiplayerGame\ | Join existing multiplayer game |
efundStake\ | Claim refund after timeout |
| \refundStake\ | Claim refund after timeout |

### Admin Functions
| Function | Description |
|----------|-------------|
esolveGame\ | Resolve solo game outcome |
esolveMultiplayerGame\ | Resolve multiplayer with winner |
| \resolveGame\ | Resolve solo game outcome |
| \resolveMultiplayerGame\ | Resolve multiplayer with winner |
| \withdrawFees\ | Withdraw accumulated fees |
| \setFeeBps\ | Update fee percentage |
| \pause/unpause\ | Emergency pause |

## Deployment

\\\ash
# Using Hardhat
npx hardhat compile
npx hardhat deploy --network celo

# Using Foundry
forge build
forge create --rpc-url \ --private-key \ PlayverseStake
\\\

## Supported Networks

- Ethereum Mainnet
- Celo
- Polygon
- Arbitrum
- Base

## Security

- Uses OpenZeppelin contracts
- ReentrancyGuard on all state-changing functions
- Pausable for emergencies
- Fee capped at 10%

## License

MIT
