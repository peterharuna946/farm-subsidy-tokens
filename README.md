# Farm Subsidy Tokens 🌾

A transparent blockchain-based system for distributing agricultural subsidies and aid tokens to farmers using smart contracts on the Stacks blockchain.

## Overview

Farm Subsidy Tokens revolutionizes agricultural aid distribution by leveraging blockchain technology to ensure transparency, accountability, and efficient distribution of farm subsidies. The system allows authorized distributors to register farmers and distribute subsidy tokens based on eligibility criteria, while maintaining a complete audit trail of all transactions.

## How It Works

1. **Farmer Registration**: Authorized officials register qualified farmers with their land size, crop type, and location details
2. **Eligibility Assessment**: Smart contracts automatically verify farmer eligibility based on predefined criteria
3. **Token Distribution**: Subsidies are distributed as tokens directly to eligible farmers' wallets
4. **Transparent Tracking**: All transactions are recorded on-chain for complete transparency and auditability
5. **Utilization Monitoring**: Track how subsidy tokens are used by farmers

## Key Features

### 🔒 Transparent Distribution
- All subsidy distributions are recorded on the blockchain
- Public verification of fund allocation and usage
- Immutable audit trail for regulatory compliance
- Real-time tracking of subsidy distribution status

### 👨‍🌾 Farmer Management
- Comprehensive farmer registration system
- Land size and crop type verification
- Location-based eligibility criteria
- Farmer profile management and updates

### 💰 Token-Based Subsidies
- Standardized subsidy token distribution
- Flexible subsidy amounts based on farm characteristics
- Multi-criteria eligibility assessment
- Automated calculation of subsidy entitlements

### 📊 Analytics & Reporting
- Distribution statistics and farmer demographics
- Geographic distribution mapping
- Subsidy utilization tracking
- Performance metrics and impact assessment

## Smart Contracts

### 1. Subsidy Distribution Contract
- Manages the core subsidy token distribution logic
- Handles farmer eligibility verification
- Controls token minting and distribution processes
- Maintains distribution history and statistics

### 2. Farmer Registry Contract
- Manages farmer registration and profile data
- Stores farmer credentials and farm characteristics
- Handles farmer verification and status updates
- Provides farmer lookup and validation services

## Subsidy Criteria

### Eligibility Requirements
- **Land Size**: Minimum 1 acre, maximum 1000 acres
- **Crop Types**: Support for various agricultural crops
- **Geographic Location**: Location-based eligibility verification
- **Registration Status**: Must be registered with valid credentials

### Subsidy Calculation
- Base subsidy amount determined by land size
- Crop type multipliers for specialized farming
- Location-based adjustments for regional needs
- Maximum subsidy limits to ensure fair distribution

## Usage Example

```clarity
;; Register a new farmer
(contract-call? .farmer-registry register-farmer
  "John Doe"
  u50      ;; 50 acres
  "Wheat"  ;; crop type
  "Nebraska") ;; location

;; Distribute subsidy to eligible farmer
(contract-call? .subsidy-distribution distribute-subsidy
  'ST1FARMER123... ;; farmer address
  u5000)           ;; subsidy amount in tokens
```

## Benefits

### For Farmers
- **Direct Access**: Receive subsidies directly without intermediaries
- **Transparency**: See exactly when and how much aid is distributed
- **Efficiency**: Faster distribution compared to traditional systems
- **Verification**: Proof of eligibility and subsidy receipt on blockchain

### For Governments/NGOs
- **Reduced Corruption**: Immutable records prevent fund misappropriation
- **Cost Efficiency**: Lower administrative overhead and processing costs
- **Real-time Monitoring**: Instant visibility into distribution progress
- **Impact Measurement**: Data-driven insights on program effectiveness

### For Society
- **Accountability**: Public verification of aid distribution
- **Food Security**: Support for agricultural productivity
- **Economic Development**: Strengthening rural farming communities
- **Environmental Impact**: Encouraging sustainable farming practices

## Security Features

- Multi-signature authorization for large distributions
- Farmer identity verification and validation
- Subsidy amount limits and controls
- Emergency pause functionality for contract security
- Comprehensive access control mechanisms

## Getting Started

1. Clone this repository
2. Install Clarinet: https://docs.hiro.so/clarinet
3. Run tests: `clarinet test`
4. Deploy to testnet: `clarinet deploy --testnet`

## Testing

The project includes comprehensive test suites covering:
- Farmer registration and profile management
- Subsidy eligibility verification and calculation
- Token distribution mechanisms and limits
- Error handling and edge case scenarios
- Security features and access controls

## Contributing

1. Fork the repository
2. Create a feature branch
3. Implement changes with proper testing
4. Submit a pull request with detailed description

## License

MIT License - See LICENSE file for details

## Disclaimer

This is experimental software designed for agricultural aid distribution. Always conduct thorough testing before deploying to mainnet. Ensure compliance with local regulations and agricultural policies.
