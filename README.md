# Blocker Blockchain 모듈 설명

이 문서는 `blockchain` 폴더 내 각 하위 디렉터리 및 주요 파일의 역할을 설명합니다.

---

## 1. blockchain-server/
- 블록체인 네트워크 서버 관련 설정 및 실행 환경을 담당합니다.
- 주요 파일:
  - `docker-compose.yml`: 블록체인 서버 인프라 구성을 위한 Docker Compose 설정 파일.

## 2. registry-service/
- 스마트 컨트랙트 주소 레지스트리 관리 서비스입니다.
- 주요 파일 및 디렉터리:
  - `contracts/AddressRegistry.sol`: 여러 스마트 컨트랙트의 주소를 중앙에서 관리하는 레지스트리 스마트 컨트랙트.
  - `deploy/deploy_registry.py`: AddressRegistry 컨트랙트 배포 및 주소/ABI 저장 스크립트.
  - `registry_address.txt`: 배포된 레지스트리 컨트랙트의 주소와 ABI 정보 저장.
  - `requirements.txt`, `Dockerfile`, `docker-compose.yml`: 서비스 실행 환경 및 의존성 관리.

## 3. update_service/
- 소프트웨어 업데이트 관리용 스마트 컨트랙트 및 배포 스크립트만 포함합니다.
- 주요 파일 및 디렉터리:
  - `contracts/SoftwareUpdateContract.sol`: 소프트웨어 업데이트 등록, 구매, 설치 확인 등을 관리하는 스마트 컨트랙트.
  - `deploy/deploy_contract.py`: SoftwareUpdateContract 배포 및 레지스트리 등록 스크립트.
  - `contract_address.txt`: 배포된 SoftwareUpdateContract의 주소와 ABI 정보 저장.

---

## 상세 기능 및 함수 설명

### registry-service/contracts/AddressRegistry.sol
- **setContractAddress(string name, address addr)**  
  지정한 이름(name)으로 컨트랙트 주소(addr)를 등록하거나 갱신합니다. 오직 admin만 호출 가능하며, 등록/갱신 시 이벤트가 발생합니다.
- **getContractAddress(string name)**  
  이름(name)으로 등록된 컨트랙트 주소를 반환합니다. 등록되지 않은 경우 예외를 발생시킵니다.

---

### update_service/contracts/SoftwareUpdateContract.sol
- **registerUpdate(...)**  
  제조사만 호출 가능. 소프트웨어 업데이트 정보를 등록하며, 서명(signature)도 함께 받습니다. 등록 시 이벤트 발생. (컨트랙트 내부에서 서명 검증은 하지 않음)
- **purchaseUpdate(string uid)**  
  소유자가 업데이트를 구매할 때 호출. 결제와 동시에 접근 권한이 부여되고, 이벤트가 발생합니다.
- **getUpdateInfo(string uid)**  
  업데이트의 상세 정보를 반환합니다. 호출자가 권한이 있으면 암호화된 키도 반환합니다.
- **confirmInstallation(string uid, string deviceId)**  
  소유자가 업데이트 설치를 완료했음을 기록합니다. 권한이 있는 소유자만 호출 가능.
- **getOwnerUpdates()**  
  호출자(소유자)가 구매한 모든 업데이트의 uid 목록을 반환합니다.
- **getUpdateCount(), getUpdateIdByIndex(uint256 index)**  
  전체 등록된 업데이트 개수와, 인덱스로 uid를 조회할 수 있습니다.

---

### update_service/deploy/deploy_contract.py
- **deploy_contract()**  
  SoftwareUpdateContract.sol을 컴파일하고, 블록체인에 배포합니다. 배포 후 컨트랙트 주소와 ABI를 contract_address.txt에 저장하고, registry-service의 AddressRegistry 컨트랙트에 이 주소를 등록합니다. 예외 발생 시 로깅 후 예외를 다시 던집니다.
- **update_registry(web3, account_address, private_key, contract_address)**  
  registry_address.txt에서 레지스트리 컨트랙트 주소와 ABI를 읽어와 setContractAddress("SoftwareUpdateContract", contract_address)를 호출해 주소를 등록합니다. 트랜잭션 성공 여부를 반환합니다.

---

## 전체 요약
- **registry-service**: 여러 스마트 컨트랙트의 주소를 중앙에서 관리하는 레지스트리 컨트랙트 및 배포/관리 도구 제공.
- **update_service**: 소프트웨어 업데이트의 등록, 구매, 설치 확인 등 전체 라이프사이클을 관리하는 스마트 컨트랙트와 배포 스크립트만 제공.
- 각 서비스는 독립적으로 컨테이너화되어 블록체인 네트워크와 연동됩니다.

이 구조를 통해 블록체인 기반 소프트웨어 업데이트 및 관리 시스템을 효율적으로 구현할 수 있습니다.

---
