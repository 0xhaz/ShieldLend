# 🛡️ ShieldLend

> **Privacy-Native BTC Lending Protocol on Starknet**
> Built for the Re{define} Hackathon | Feb 2026

ShieldLend is the first lending protocol where privacy is a first-class feature. Deposit BTC, borrow stablecoins, earn yield — all without exposing your positions to the public chain.

---

## Quick Start

### Prerequisites

```bash
# Cairo / Starknet toolchain
curl -L https://raw.githubusercontent.com/foundry-rs/starknet-foundry/master/scripts/install.sh | sh
snfoundryup

curl --proto '=https' --tlsv1.2 -sSf https://docs.swmansion.com/scarb/install.sh | sh

# Noir toolchain
curl -L https://raw.githubusercontent.com/noir-lang/noirup/main/install | bash
noirup

# Node.js 18+
nvm use 18

# Starkli (CLI)
curl https://get.starkli.sh | sh
starkliup
```

### Build & Test Contracts

```bash
cd contracts
scarb build
snforge test
```

### Build & Test Circuits

```bash
cd circuits
nargo compile
nargo test
```

### Run Frontend

```bash
cd frontend
npm install
cp .env.example .env.local   # Fill in contract addresses
npm run dev                   # → http://localhost:3000
```

### Deploy to Testnet

```bash
cd scripts
chmod +x deploy.sh
./deploy.sh sepolia
```

---

## Architecture

See **[ARCHITECTURE.md](./docs/ARCHITECTURE.md)** for the full technical specification including:

- System diagram & module dependency graph
- Smart contract interfaces (Cairo)
- Privacy layer design (Pedersen commitments, ElGamal encryption, Noir circuits)
- Core protocol flows (shielded deposit, borrow, flash loans, yield tokenization)
- Frontend architecture & proof generation

---

## Features

| Feature | Description |
|---|---|
| 🔒 **Shielded Lending** | Deposit collateral and borrow with hidden amounts via ZK proofs |
| ⚡ **Shielded Flash Loans** | Uncollateralized atomic loans where amounts and operations are private |
| 🏦 **Isolated Markets** | Each collateral/loan pair is a separate risk-isolated market |
| 📊 **Yield Tokenization** | Split deposits into Principal Tokens (PT) and Yield Tokens (YT) |
| 🔄 **eMode** | High-LTV borrowing between correlated BTC variants |
| 🫧 **Soft Liquidation** | Gradual, private rebalancing instead of sudden liquidation |
| ₿ **BTC-Native** | First-class support for strkBTC, tBTC, wBTC on Starknet |

---

## Hackathon Tracks

- **🔒 Privacy Track** — ZK-powered shielded balances, confidential transactions, solvency proofs
- **₿ Bitcoin Track** — strkBTC/tBTC lending, Xverse API integration, BTC yield tokenization
- **🚀 Open Track** — Novel flash loan primitive, isolated market architecture

---

## Team

_[Your team info here]_

---

## License

MIT
