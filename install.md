Installation and Run Guide

Summary
- This document describes how to run the project locally for development on macOS (using zsh).

Prerequisites
- Docker Desktop (or Docker) and Docker Compose installed and running
- Python 3.9+ and pip

1) Change to the repository directory
```zsh
cd "$(git rev-parse --show-toplevel)"
```

2) Start the blockchain server
- Start the test blockchain network first.
```zsh
cd blockchain-server
docker-compose up -d
```

3) Deploy the registry service
```zsh
cd ../registry-service
docker-compose up --build -d
for id in $(docker-compose ps -q); do
  if [ -n "$id" ]; then
    echo "Waiting for container $id to stop..."
    docker wait "$id"
  else
    echo "No containers found for this compose project. Use 'docker-compose ps' to inspect."
  fi
done
```
Wait for registry-service containers to stop and block until they exit

1) Deploy the Update service (SoftwareUpdateContract)
```zsh
cd ../update_service
docker-compose up --build -d
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