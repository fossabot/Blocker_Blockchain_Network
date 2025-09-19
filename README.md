# Blocker Blockchain

### 1. 서비스 개요
- 블록체인 기반 소프트웨어 업데이트 및 주소 레지스트리 관리 시스템입니다.
- 주요 구성요소:
  - 블록체인 네트워크 서버: 테스트용 블록체인 노드 및 네트워크 구성
  - registry-service: 스마트 컨트랙트 주소를 중앙에서 관리하는 레지스트리 서비스
  - update_service: 소프트웨어 업데이트 등록·구매·설치 확인을 담당하는 스마트 컨트랙트 및 배포 스크립트

### 2. 개발 환경
- 권장 운영체제: macOS / Linux
- 필수 도구: Docker, Docker Compose, Python 3.9+, pip
- 스마트 컨트랙트 컴파일: solc (py-solc-x를 통해 설치/사용 권장)
- 테스트: pytest

### 3. 사용 기술
- Solidity: 스마트 컨트랙트 구현
- Web3.py: 파이썬에서 이더리움 노드와 상호작용
- Python: 배포 스크립트 및 서비스 구현
- Docker / Docker Compose: 서비스 컨테이너화 및 로컬 네트워크 구성
- pytest: 단위/통합 테스트

### 4. 폴더 구조
- `blockchain-server/` : 블록체인 노드 및 네트워크 관련 설정 (Dockerfile, docker-compose.yml)
- `registry-service/` : AddressRegistry 스마트 컨트랙트 및 배포/서비스 코드
  - `contracts/AddressRegistry.sol` 등
  - `deploy/` 배포 스크립트
- `update_service/` : SoftwareUpdateContract 스마트 컨트랙트 및 배포 스크립트
  - `contracts/SoftwareUpdateContract.sol` 등
  - `deploy/` 배포 관련 스크립트
- `registry/`, `tests/`, `update/` : 각종 테스트 및 테스트용 구성

실행 방법은 `install.md` 파일을 참고하세요.