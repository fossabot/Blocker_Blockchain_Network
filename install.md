설치 및 실행 가이드

요약
- macOS(zsh) 환경에서 로컬 개발용으로 프로젝트를 실행하는 방법을 정리합니다.

사전 준비
- Docker Desktop(또는 Docker), Docker Compose 설치 및 실행
- Python 3.9+ 및 pip

1) 저장소 위치로 이동
```zsh
cd /Users/c/Desktop/Git/Blocker_Blockchain_Network
```

2) 블록체인 서버 실행
- 블록체인 네트워크(테스트 노드)를 먼저 실행하세요.
```zsh
cd blockchain-server
docker-compose up -d
```

3) Registry 서비스 배포
- Docker로 실행:
```zsh
cd ../registry-service
docker-compose up --build -d
```

- 또는 로컬에서 배포 스크립트 실행 (가상환경 권장):
```zsh
cd /Users/c/Desktop/Git/Blocker_Blockchain_Network/registry-service
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 deploy/deploy_registry.py
```

4) Update 서비스(SoftwareUpdateContract) 배포
- Docker로 실행:
```zsh
cd ../update_service
docker-compose up --build -d
```

- 또는 로컬에서 배포 스크립트 실행:
```zsh
cd /Users/c/Desktop/Git/Blocker_Blockchain_Network/update_service
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python3 deploy/deploy_contract.py
```

5) 배포된 SoftwareUpdateContract 주소 조회
- 제공된 스크립트로 주소를 확인할 수 있습니다.
```zsh
cd /Users/c/Desktop/Git/Blocker_Blockchain_Network/update_service
# 가상환경이 필요할 수 있음
source .venv/bin/activate
pip install -r requirements.txt
python3 deploy/get_software_update_address.py
```

6) 테스트 실행
- 도커 기반 통합테스트가 준비되어 있으면 `tests` 폴더에서 실행합니다.
```zsh
cd /Users/c/Desktop/Git/Blocker_Blockchain_Network/tests
docker-compose up --build --abort-on-container-exit
```
- 또는 로컬에서 pytest 실행(테스트 요구사항에 맞게 의존성 설치 필요):
```zsh
# 프로젝트 루트에서 가상환경 생성 후
python3 -m venv .venv
source .venv/bin/activate
pip install -r update_service/requirements.txt
pip install -r registry-service/requirements.txt
pip install pytest
pytest
```

정리 및 중지
- 각 서비스 디렉터리에서 다음 명령으로 중지/정리:
```zsh
docker-compose down
```

참고
- macOS 환경에서는 일반적으로 sudo 없이 Docker 명령을 실행합니다. 권한 문제가 있을 경우 sudo를 사용하세요.
- 네트워크 이름이나 환경변수는 로컬 환경/도커 설정에 따라 다를 수 있으니 필요 시 `docker network ls`, `docker-compose ps`로 확인하세요.

문제 발생 시 로그 확인
- Docker 컨테이너 로그:
```zsh
docker-compose logs -f
```
