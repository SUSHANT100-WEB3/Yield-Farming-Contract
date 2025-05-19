# Yield Farming Smart Contract

A Solidity smart contract for yield farming that allows users to stake tokens and earn rewards over time.

## Features

- Token staking and unstaking
- Reward distribution
- Emergency withdrawal functionality
- Admin controls for reward refilling
- Reentrancy protection
- Safe math operations

## Setup

1. Install dependencies:
```bash
npm install
```

2. Compile the contracts:
```bash
npx hardhat compile
```

## Contract Details

The contract implements a yield farming mechanism where users can:
- Stake tokens to start earning rewards
- Unstake tokens and claim rewards
- Emergency withdraw their staked tokens
- View pending rewards

## Security Features

- ReentrancyGuard for protection against reentrancy attacks
- Safe math operations using OpenZeppelin's SafeCast
- Owner-only functions for administrative tasks

## License

MIT 