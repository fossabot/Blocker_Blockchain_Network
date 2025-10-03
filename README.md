# Blocker Blockchain

## Overview
This repository implements a blockchain-based software update and address registry system used for developing and testing secure on-chain update distribution. It contains a local test blockchain network, services for registering contract addresses, and scripts to deploy and interact with software update smart contracts.

### Blockchain Network Flow
1. Start the local blockchain test network (`blockchain-server`) which runs one or more test nodes and exposes JSON-RPC and WebSocket endpoints for local development and testing.
2. The `registry-service` deploys or registers the AddressRegistry contract and maintains known contract addresses on-chain.
3. Deployment scripts in `update_service` deploy the SoftwareUpdateContract and register its address with the registry when required.
4. Services and test clients subscribe to contract events over WebSocket to detect deployments and state changes in real time.
5. Integration tests interact with the same local network and services to validate contract behavior and service orchestration.

## Development Environment
- Recommended OS: macOS (zsh) or Linux
- Required tools: Docker, Docker Compose, Python 3.9+ and pip
- Smart contract compilation: solc (py-solc-x recommended)
- Tests: pytest

## Technology Stack
- ![Blockchain](https://img.shields.io/badge/Blockchain-121D33?style=flat&logo=blockchaindotcom&logoColor=white) [![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2FHSU-Blocker%2FBlocker_Blockchain_Network.svg?type=shield)](https://app.fossa.com/projects/git%2Bgithub.com%2FHSU-Blocker%2FBlocker_Blockchain_Network?ref=badge_shield)
 Local test network for contract development and testing
- ![Smart Contract](https://img.shields.io/badge/Smart_Contract-2C3E50?style=flat&logo=ethereum&logoColor=white)  Solidity contracts for registry and update logic
- ![Web3](https://img.shields.io/badge/Web3-F16822?style=flat&logo=web3dotjs&logoColor=white)  Web3.py for blockchain interaction
- ![WebSocket](https://img.shields.io/badge/WebSocket-008080?style=flat&logo=socketdotio&logoColor=white)  Real-time event subscriptions from nodes
- ![Flask](https://img.shields.io/badge/Flask-000000?style=flat&logo=flask&logoColor=white)  Optional backend services used by registry/update services
- Docker / Docker Compose for containerized local development and orchestration

## Installation
See `install.md` for detailed installation and run instructions. The repository includes Docker Compose configurations for local development and integrated tests.

## Repository Structure
```
CODE_OF_CONDUCT.md
install.md
LICENSE
README.md
blockchain-server/
	docker-compose.yml
	Dockerfile
registry-service/
	docker-compose.yml
	Dockerfile
	registry_address.json
	requirements.txt
	contracts/
		AddressRegistry.sol
	deploy/
		deploy_registry.py
tests/
	docker-compose.yml
	Dockerfile
	registry/
		test_address_registry.py
	update/
		test_software_update.py
update_service/
	contract_address.json
	docker-compose.yml
	Dockerfile
	requirements.txt
	contracts/
		SoftwareUpdateContract.sol
	deploy/
		deploy_contract.py
		get_software_update_address.py
```

## License
This project is licensed under the MIT License. See `LICENSE` for details.

---

Contributions and questions are welcome via Issues and Pull Requests.

[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2FHSU-Blocker%2FBlocker_Blockchain_Network.svg?type=large)](https://app.fossa.com/projects/git%2Bgithub.com%2FHSU-Blocker%2FBlocker_Blockchain_Network?ref=badge_large)