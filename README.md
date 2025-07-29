# 🎓 Smart Assignment System

A blockchain-based automated assignment grading and reward system built on Ethereum. This system enables transparent, tamper-proof assignment submissions with automated reward distribution for students who achieve passing grades.

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Architecture](#architecture)
- [Smart Contracts](#smart-contracts)
- [Installation](#installation)
- [Deployment](#deployment)
- [Usage](#usage)
- [Testing](#testing)
- [Gas Optimization](#gas-optimization)
- [Security](#security)
- [Contributing](#contributing)
- [License](#license)

## 🌟 Overview

The Smart Assignment System addresses key challenges in educational technology by providing:

- **Transparent Grading**: All submissions and grades are recorded on-chain for transparency
- **Automated Rewards**: Students receive ERC-20 tokens for achieving passing grades
- **Tamper-Proof Submissions**: Content integrity verified through cryptographic hashes
- **Cost-Effective Storage**: Large files stored off-chain (IPFS) with on-chain verification
- **Oracle Integration**: Flexible grading system supporting both automated and manual assessment

## ✨ Features

### For Students
- Submit assignments with IPFS content hashes
- View assignment details and deadlines
- Track submission status and grades
- Claim reward tokens for passing submissions
- Batch claim multiple rewards

### For Instructors
- Create assignments with custom parameters
- Set deadlines, reward amounts, and submission limits
- Track assignment statistics
- Manage assignment visibility

### For Oracles/Graders
- Grade submissions off-chain
- Provide detailed feedback via IPFS
- Trigger automated reward distribution
- Support for various assignment types

### For Administrators
- Manage oracle and instructor permissions
- Control system parameters
- Emergency pause functionality
- Token supply management

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│                 │    │                 │    │                 │
│   Frontend      │◄──►│ Smart Contracts │◄──►│  IPFS Storage   │
│   (Web3.js)     │    │  (Ethereum)     │    │ (Assignment     │
│                 │    │                 │    │  Content)       │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │                 │
                    │ Oracle Service  │
                    │ (Off-chain      │
                    │  Grading)       │
                    └─────────────────┘
```

### Design Principles
- **Hybrid Architecture**: On-chain coordination with off-chain storage and computation
- **Gas Efficiency**: Minimal on-chain data storage using content hashes
- **Scalability**: Batch operations and efficient data structures
- **Security**: Role-based access control and reentrancy protection

## 📄 Smart Contracts

### RewardToken.sol
ERC-20 token contract for student rewards.

**Key Features:**
- Custom token with configurable decimals
- Mint/burn functionality for administrators
- Integration with assignment system

### AssignmentSystem.sol
Main contract managing assignments, submissions, and rewards.

**Key Components:**
- Assignment creation and management
- Student submission handling
- Oracle-based grading system
- Automated reward distribution
- Role-based access control

## 🚀 Installation

### Prerequisites
- Node.js (v16 or higher)
- npm or yarn
- MetaMask or similar Web3 wallet
- Access to Ethereum testnet (Goerli, Sepolia) or mainnet

### Clone Repository
```bash
git clone https://github.com/your-username/smart-assignment-system.git
cd smart-assignment-system
```

### Install Dependencies
```bash
npm install
# or
yarn install
```

## 📦 Deployment

### Using Remix IDE (Recommended for Testing)

1. **Open Remix IDE**: Visit [remix.ethereum.org](https://remix.ethereum.org)

2. **Create new files**:
   - `RewardToken.sol`
   - `AssignmentSystem.sol`

3. **Copy contract code** from the artifacts into respective files

4. **Compile contracts**:
   - Select Solidity compiler version `^0.8.19`
   - Compile both contracts

5. **Deploy RewardToken first**:
   ```
   Constructor Parameters:
   - name: "EduToken"
   - symbol: "EDU"
   - decimals: 18
   - initialSupply: 1000000
   ```

6. **Deploy AssignmentSystem**:
   ```
   Constructor Parameters:
   - _rewardToken: [RewardToken contract address]
   ```

### Using Hardhat (Production)

```bash
# Install Hardhat
npm install --save-dev hardhat

# Initialize Hardhat project
npx hardhat

# Create deployment script
# scripts/deploy.js
```

Example deployment script:
```javascript
async function main() {
  // Deploy RewardToken
  const RewardToken = await ethers.getContractFactory("RewardToken");
  const rewardToken = await RewardToken.deploy(
    "EduToken",
    "EDU", 
    18,
    1000000
  );
  
  // Deploy AssignmentSystem
  const AssignmentSystem = await ethers.getContractFactory("AssignmentSystem");
  const assignmentSystem = await AssignmentSystem.deploy(rewardToken.address);
  
  console.log("RewardToken deployed to:", rewardToken.address);
  console.log("AssignmentSystem deployed to:", assignmentSystem.address);
}
```

## 🎯 Usage

### Creating an Assignment

```javascript
const tx = await assignmentSystem.createAssignment(
  "Introduction to Blockchain",           // title
  "Write a 1000-word essay on blockchain", // description
  "QmXxXxXxXxXxXxXxXxXxXxXxXxXxXxXxX",      // IPFS content hash
  Math.floor(Date.now() / 1000) + 86400,  // deadline (24 hours)
  ethers.utils.parseEther("10"),          // reward amount
  100,                                    // max submissions
  0                                       // assignment type (Essay)
);
```

### Submitting an Assignment

```javascript
const tx = await assignmentSystem.submitAssignment(
  1,                                      // assignment ID
  "QmYyYyYyYyYyYyYyYyYyYyYyYyYyYyYyY"      // IPFS submission hash
);
```

### Grading a Submission

```javascript
const tx = await assignmentSystem.gradeSubmission(
  1,                                      // assignment ID
  "0x1234567890123456789012345678901234567890", // student address
  85,                                     // grade (out of 100)
  "QmZzZzZzZzZzZzZzZzZzZzZzZzZzZzZzZ"      // IPFS feedback hash
);
```

### Claiming Rewards

```javascript
// Single reward
const tx = await assignmentSystem.claimReward(1);

// Multiple rewards
const tx = await assignmentSystem.claimMultipleRewards([1, 2, 3]);
```

## 🧪 Testing

### Unit Tests
```bash
npx hardhat test
```

### Test Coverage
```bash
npx hardhat coverage
```

### Integration Tests
- Test complete assignment workflow
- Verify reward distribution
- Check access control mechanisms
- Validate gas optimization

## ⛽ Gas Optimization

The system implements several gas optimization strategies:

- **Minimal On-Chain Storage**: Only hashes and essential metadata stored
- **Batch Operations**: Claim multiple rewards in single transaction
- **Efficient Data Structures**: Optimized mappings and structs
- **Event-Driven Architecture**: Reduce storage reads through events

### Estimated Gas Costs
- Create Assignment: ~150,000 gas
- Submit Assignment: ~80,000 gas
- Grade Submission: ~60,000 gas
- Claim Reward: ~45,000 gas

## 🔒 Security

### Security Features
- **ReentrancyGuard**: Prevents reentrancy attacks
- **Pausable**: Emergency stop functionality
- **Role-Based Access**: Instructor and Oracle permissions
- **Input Validation**: Comprehensive parameter checking

### Audit Checklist
- [ ] Reentrancy protection implemented
- [ ] Integer overflow/underflow protection
- [ ] Access control properly configured
- [ ] Emergency functions working
- [ ] Event logging comprehensive

### Best Practices
- Always use latest OpenZeppelin contracts
- Implement proper error handling
- Use events for off-chain monitoring
- Regular security audits recommended

## 🔮 Future Enhancements

### Planned Features
- **Multi-signature Grading**: Require multiple oracles for high-stakes assignments
- **Reputation System**: Track student and instructor performance
- **NFT Certificates**: Issue completion certificates as NFTs
- **DAO Governance**: Community-driven system parameters
- **Layer 2 Integration**: Deploy on Polygon/Arbitrum for lower costs

### Integration Possibilities
- **Learning Management Systems**: Moodle, Canvas integration
- **Identity Verification**: Integration with educational credentials
- **Payment Gateways**: Fiat on-ramps for reward tokens
- **Analytics Dashboard**: Comprehensive reporting tools

## 🤝 Contributing

We welcome contributions! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines
- Follow Solidity style guide
- Write comprehensive tests
- Update documentation
- Gas optimize new features

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

- **Documentation**: [Wiki](https://github.com/your-username/smart-assignment-system/wiki)
- **Issues**: [GitHub Issues](https://github.com/your-username/smart-assignment-system/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-username/smart-assignment-system/discussions)
- **Email**: your-email@example.com

## 🙏 Acknowledgments

- OpenZeppelin for security-audited smart contract libraries
- IPFS for decentralized storage solutions
- Ethereum community for blockchain infrastructure
- Educational technology pioneers for inspiration

---

**Built with ❤️ for the future of education on blockchain**

*Remember to always test thoroughly on testnets before mainnet deployment!*
