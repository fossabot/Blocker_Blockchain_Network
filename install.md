Installation and Run Guide

Summary
- This document describes how to run the project locally for development on macOS (using zsh).

Prerequisites
- Docker Desktop (or Docker) and Docker Compose installed and running
- Python 3.9+ and pip

1) Change to the repository directory
```zsh
cd /Users/c/Desktop/Git/Blocker_Blockchain_Network
```

2) Start the blockchain server
- Start the test blockchain network first.
```zsh
cd blockchain-server
docker-compose up -d
```

3) Deploy the registry service
- Using Docker:
```zsh
cd ../registry-service
docker-compose up --build -d
```

- Or run the deployment script locally (recommended inside a virtual environment):
```zsh
cd /Users/c/Desktop/Git/Blocker_Blockchain_Network/registry-service
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 deploy/deploy_registry.py
```

4) Deploy the Update service (SoftwareUpdateContract)
- Using Docker:
```zsh
cd ../update_service
docker-compose up --build -d
```

- Or run the deployment script locally:
```zsh
cd /Users/c/Desktop/Git/Blocker_Blockchain_Network/update_service
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 deploy/deploy_contract.py
```

5) Retrieve the deployed SoftwareUpdateContract address
- Use the provided script to print the deployed contract address:
```zsh
cd /Users/c/Desktop/Git/Blocker_Blockchain_Network/update_service
# Activate the virtual environment if needed
source .venv/bin/activate
pip install -r requirements.txt
python3 deploy/get_software_update_address.py
```

6) Run tests
- If a Docker-based integration test configuration is available, run tests from the `tests` folder:
```zsh
cd /Users/c/Desktop/Git/Blocker_Blockchain_Network/tests
docker-compose up --build --abort-on-container-exit
```

- Or run pytest locally (install required dependencies for each service first):
```zsh
# From the project root, create and activate a virtual environment
python3 -m venv .venv
source .venv/bin/activate
pip install -r update_service/requirements.txt
pip install -r registry-service/requirements.txt
pip install pytest
pytest
```

Stopping and cleanup
- To stop and remove containers for a service, run in each service directory:
```zsh
docker-compose down
```

Notes
- On macOS you normally run Docker commands without sudo. If you encounter permission issues, try using sudo.
- Network names or environment variables may vary depending on your local Docker configuration. Use `docker network ls` and `docker-compose ps` to inspect the environment if needed.

Troubleshooting / Logs
- View container logs to diagnose issues:
```zsh
docker-compose logs -f
```
