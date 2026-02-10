# 🏛️ On-Chain Grant Distribution

> A decentralized grant distribution system built on Stacks blockchain for transparent DAO treasury management

## 🚀 Overview

This smart contract enables DAOs to manage grant distributions through a transparent, on-chain voting system. Members can propose grants, vote on proposals, and automatically execute approved funding distributions.

## ✨ Features

- 📝 **Proposal Creation**: DAO members can submit grant proposals with recipient and amount
- 🗳️ **Weighted Voting**: Vote on proposals with configurable voting power per member  
- ⏰ **Time-based Voting**: Automatic voting periods with configurable deadlines
- 💰 **Treasury Management**: Secure fund deposits and automatic distribution
- 👥 **Member Management**: Add/remove DAO members with customizable voting power
- 🔒 **Security Controls**: Owner-only administrative functions and emergency withdrawals
- 📊 **Real-time Analytics**: Track proposal status, voting stats, and treasury balance

## 🛠️ Core Functions

### Treasury Management
```clarity
(deposit-funds)                    ;; Deposit STX to treasury
(get-treasury-balance)             ;; Check current treasury balance
(emergency-withdraw)               ;; Owner emergency withdrawal
```

### Member Management  
```clarity
(add-dao-member member voting-power)     ;; Add new DAO member
(remove-dao-member member)               ;; Remove DAO member
(update-voting-power member new-power)   ;; Update member voting power
```

### Proposal Lifecycle
```clarity
(create-proposal title description recipient amount)  ;; Submit new proposal
(vote-on-proposal proposal-id vote-yes)              ;; Vote on proposal
(execute-proposal proposal-id)                       ;; Execute approved proposal
```

### Information & Analytics
```clarity
(get-proposal proposal-id)            ;; Get proposal details
(get-proposal-status proposal-id)     ;; Get voting status & analytics
(get-voting-stats proposal-id)        ;; Get detailed voting statistics
(get-active-proposals)               ;; List all active proposals
(get-executed-proposals)             ;; List all executed proposals
```

## 🎯 Usage Example

### 1. Setup DAO
```bash
# Add DAO members with voting power
(contract-call? .on-chain-grant-distribution add-dao-member 'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7 u50)
(contract-call? .on-chain-grant-distribution add-dao-member 'SP1WTA0YBPC5R6GDMPPJCEDEA6Z2ZEPNMQ4C39W6M u75)
```

### 2. Fund Treasury
```bash
# Members deposit STX to treasury
(contract-call? .on-chain-grant-distribution deposit-funds)
```

### 3. Create Grant Proposal
```bash
# Submit proposal for community project funding
(contract-call? .on-chain-grant-distribution create-proposal 
  u"Community Development Grant"
  u"Funding for open-source tooling development"
  'SP2J6ZY48GV1EZ5V2V5RB9MP66SW86PYKKNRV9EJ7
  u1000000)  ;; 1 STX
```

### 4. Vote on Proposals
```bash
# Vote yes on proposal #1
(contract-call? .on-chain-grant-distribution vote-on-proposal u1 true)

# Vote no on proposal #1  
(contract-call? .on-chain-grant-distribution vote-on-proposal u1 false)
```

### 5. Execute Approved Proposals
```bash
# Execute proposal after voting period ends
(contract-call? .on-chain-grant-distribution execute-proposal u1)
```

## ⚙️ Configuration

- **Voting Period**: 144 blocks (~24 hours)
- **Approval Threshold**: 51% of votes cast
- **Initial Owner**: Contract deployer
- **Minimum Voting Power**: 1

## 🔐 Security Features

- ✅ Only DAO members can create proposals and vote
- ✅ One vote per member per proposal
- ✅ Time-locked voting periods
- ✅ Automatic execution based on approval threshold
- ✅ Emergency withdrawal for contract owner
- ✅ Proposal cancellation by owner
- ✅ Protection against invalid recipients

## 🧪 Development

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet)
- [Stacks CLI](https://github.com/blockstack/stacks-blockchain)

### Local Testing
```bash
# Check contract syntax
clarinet check

# Run tests  
clarinet test

# Start local testnet
clarinet integrate
```

### Deployment
```bash
# Deploy to testnet
clarinet deploy --testnet

# Deploy to mainnet
clarinet deploy --mainnet
```

## 📋 Error Codes

| Code | Description |
|------|-------------|
| u100 | Not authorized |
| u101 | Proposal not found |
| u102 | Proposal expired |
| u103 | Proposal already executed |
| u104 | Insufficient funds |
| u105 | Invalid amount |
| u106 | Already voted |
| u107 | Voting period ended |
| u108 | Proposal not approved |
| u109 | Invalid recipient |

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License.

---

Built with ❤️ on Stacks blockchain
