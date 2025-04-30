import os
import json
import logging
import time
from web3 import Web3
from solcx import compile_source, set_solc_version
from dotenv import load_dotenv

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# .env 파일 로드
load_dotenv()


def deploy_registry_contract():
    """레지스트리 스마트 컨트랙트 컴파일 및 배포"""
    try:
        # Web3 연결 설정 - 환경 변수에서 읽거나 기본값 사용
        web3_provider = os.getenv("WEB3_PROVIDER", "http://host.docker.internal:8545")
        private_key = os.getenv("PRIVATE_KEY", "")
        account_address = os.getenv(
            "ACCOUNT_ADDRESS", "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
        )

        # Ganache에 연결될 때까지 기다리기
        connected = False
        retries = 0
        max_retries = 20  # 최대 재시도 횟수 증가

        logger.info(f"외부 블록체인 서버에 연결 시도 중: {web3_provider}")

        while not connected and retries < max_retries:
            try:
                web3 = Web3(Web3.HTTPProvider(web3_provider))
                connected = web3.is_connected()
                if connected:
                    logger.info("Web3 연결 성공!")
                else:
                    logger.warning(
                        f"Web3 연결 실패, {retries+1}/{max_retries} 재시도 중..."
                    )
                    retries += 1
                    time.sleep(3)  # 대기 시간 증가
            except Exception as e:
                logger.warning(
                    f"Web3 연결 중 오류 발생: {e}, {retries+1}/{max_retries} 재시도 중..."
                )
                retries += 1
                time.sleep(3)  # 대기 시간 증가

        if not connected:
            raise ConnectionError(
                f"{max_retries}번 시도 후 Web3 제공자에 연결할 수 없습니다: {web3_provider}"
            )

        logger.info(f"Web3 연결 성공: {web3_provider}")
        logger.info(f"사용할 계정 주소: {account_address}")

        # solc 버전 설정 (Dockerfile에서 이미 설치했음)
        try:
            set_solc_version("0.8.17")
            logger.info("Solidity 컴파일러 버전 설정 완료: 0.8.17")
        except Exception as e:
            logger.error(f"Solidity 컴파일러 버전 설정 실패: {e}")
            raise

        # 컨트랙트 소스 파일 읽기
        contract_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "contracts",
            "AddressRegistry.sol",
        )

        with open(contract_path, "r") as file:
            contract_source = file.read()

        # 컨트랙트 컴파일
        try:
            compiled_sol = compile_source(
                contract_source,
                output_values=["abi", "bin"],
                solc_version="0.8.17",
                optimize=True,
                optimize_runs=200,
            )
            logger.info("컨트랙트 컴파일 성공!")
        except Exception as e:
            logger.error(f"컨트랙트 컴파일 실패: {e}")
            raise

        # 컴파일된 컨트랙트 정보 추출
        contract_id = list(compiled_sol.keys())[0]
        contract_interface = compiled_sol[contract_id]

        contract_abi = contract_interface["abi"]
        contract_bytecode = contract_interface["bin"]

        # 컨트랙트 객체 생성
        AddressRegistry = web3.eth.contract(
            abi=contract_abi, bytecode=contract_bytecode
        )

        # 계정 설정
        web3.eth.default_account = account_address

        # 컨트랙트 배포 트랜잭션 생성
        if private_key:
            # 비밀키가 있으면 서명된 트랜잭션 사용
            tx_params = {
                "from": account_address,
                "gas": 3000000,
                "gasPrice": web3.to_wei("50", "gwei"),
                "nonce": web3.eth.get_transaction_count(account_address),
            }

            tx = AddressRegistry.constructor().build_transaction(tx_params)
            signed_tx = web3.eth.account.sign_transaction(tx, private_key)
            tx_hash = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
        else:
            # 비밀키가 없으면 일반 트랜잭션 사용
            tx_hash = AddressRegistry.constructor().transact(
                {
                    "from": account_address,
                    "gas": 3000000,
                    "gasPrice": web3.to_wei("50", "gwei"),
                }
            )

        # 트랜잭션 영수증 대기
        tx_receipt = web3.eth.wait_for_transaction_receipt(tx_hash)
        contract_address = tx_receipt.contractAddress

        logger.info(f"레지스트리 컨트랙트 배포 성공! 주소: {contract_address}")

        # 컨트랙트 주소 저장
        registry_data = {"address": contract_address, "abi": contract_abi}

        # 파일에 저장
        registry_info_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "registry_address.txt",
        )

        with open(registry_info_path, "w") as f:
            f.write(json.dumps(registry_data))

        logger.info(
            f"레지스트리 컨트랙트 정보가 {registry_info_path}에 저장되었습니다."
        )

        return contract_address, contract_abi

    except Exception as e:
        logger.error(f"오류 발생: {str(e)}")
        raise


if __name__ == "__main__":
    # Docker 컨테이너 간 네트워크 연결이 안정화될 시간 부여
    logger.info("서비스 시작... 5초 후 레지스트리 컨트랙트 배포를 시작합니다.")
    time.sleep(5)
    try:
        contract_address, contract_abi = deploy_registry_contract()
        logger.info(f"레지스트리 컨트랙트 배포 완료. 주소: {contract_address}")
        logger.info("모든 작업이 완료되었습니다. 서비스를 종료합니다.")
    except Exception as e:
        logger.error(f"오류 발생: {e}")
        exit(1)
