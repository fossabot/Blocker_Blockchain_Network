import os
import json
import logging
from web3 import Web3
from solcx import compile_source, install_solc, set_solc_version
from dotenv import load_dotenv

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# .env 파일 로드
load_dotenv()


def deploy_contract():
    """스마트 컨트랙트 컴파일 및 배포"""
    try:
        # Web3 연결 설정
        web3_provider = os.getenv("WEB3_PROVIDER", "http://ganache:8545")
        private_key = os.getenv("PRIVATE_KEY", "")
        account_address = os.getenv("ACCOUNT_ADDRESS", "your-account-address-here")

        web3 = Web3(Web3.HTTPProvider(web3_provider))

        # Web3.py 6.0.0 호환성: isConnected() → is_connected()
        if not web3.is_connected():
            raise ConnectionError(f"Web3 제공자에 연결할 수 없습니다: {web3_provider}")

        logger.info(f"Web3 연결 성공: {web3_provider}")
        logger.info(f"사용할 계정 주소: {account_address}")

        # solc 설치 및 버전 설정
        install_solc("0.8.17")
        set_solc_version("0.8.17")

        # 컨트랙트 소스 파일 읽기
        contract_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "contracts",
            "SoftwareUpdateContract.sol",
        )

        with open(contract_path, "r") as file:
            contract_source = file.read()

        # 컨트랙트 컴파일 - 오류 발생한 via_ir 매개변수 제거하고 최적화 설정만 사용
        compiled_sol = compile_source(
            contract_source,
            output_values=["abi", "bin"],
            solc_version="0.8.17",
            optimize=True,  # 옵티마이저 활성화
            optimize_runs=200,  # 최적화 실행 횟수
        )

        # 컴파일된 컨트랙트 정보 추출
        contract_id = list(compiled_sol.keys())[0]  # 수정됨: 튜플 인덱싱 방식 변경
        contract_interface = compiled_sol[contract_id]

        # 수정: contract_interface에서 올바르게 값을 추출
        contract_abi = contract_interface["abi"]
        contract_bytecode = contract_interface["bin"]

        # 컨트랙트 객체 생성
        SoftwareUpdateContract = web3.eth.contract(
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
                # Web3.py 6.0.0 호환성: toWei() → to_wei()
                "gasPrice": web3.to_wei("50", "gwei"),
                # Web3.py 6.0.0 호환성: getTransactionCount() → get_transaction_count()
                "nonce": web3.eth.get_transaction_count(account_address),
            }

            tx = SoftwareUpdateContract.constructor().build_transaction(tx_params)
            signed_tx = web3.eth.account.sign_transaction(tx, private_key)
            # Web3.py 6.0.0 호환성: sendRawTransaction() → send_raw_transaction()
            tx_hash = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
        else:
            # 비밀키가 없으면 일반 트랜잭션 사용
            tx_hash = SoftwareUpdateContract.constructor().transact(
                {
                    "from": account_address,
                    "gas": 3000000,
                    # Web3.py 6.0.0 호환성: toWei() → to_wei()
                    "gasPrice": web3.to_wei("50", "gwei"),
                }
            )

        # 트랜잭션 영수증 대기
        # Web3.py 6.0.0 호환성: waitForTransactionReceipt() → wait_for_transaction_receipt()
        tx_receipt = web3.eth.wait_for_transaction_receipt(tx_hash)
        contract_address = tx_receipt.contractAddress

        logger.info(f"컨트랙트 배포 성공! 주소: {contract_address}")

        # 컨트랙트 주소 저장
        contract_data = {"address": contract_address, "abi": contract_abi}

        # 파일에 저장 (확장자 .json으로 변경)
        contract_info_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "contract_address.json",
        )

        with open(contract_info_path, "w") as f:
            f.write(json.dumps(contract_data))

        logger.info(f"컨트랙트 정보가 {contract_info_path}에 저장되었습니다.")

        # 레지스트리에 컨트랙트 주소 등록
        update_registry(web3, account_address, private_key, contract_address)

        return contract_address, contract_abi

    except Exception as e:
        logger.error(f"오류 발생: {str(e)}")
        raise


def update_registry(web3, account_address, private_key, contract_address):
    """레지스트리 컨트랙트에 소프트웨어 업데이트 컨트랙트 주소 등록"""
    try:
        # 레지스트리 주소 및 ABI 로드
        registry_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "registry_address.json",
        )

        if not os.path.exists(registry_path):
            logger.warning(
                "레지스트리 컨트랙트 주소 파일이 없습니다. 레지스트리 컨트랙트를 먼저 배포하세요."
            )
            return False

        with open(registry_path, "r") as f:
            registry_data = json.loads(f.read())

        registry_address = registry_data["address"]
        registry_abi = registry_data["abi"]

        # 레지스트리 컨트랙트 인스턴스 생성
        registry_contract = web3.eth.contract(
            address=registry_address, abi=registry_abi
        )

        # 소프트웨어 업데이트 컨트랙트 주소 등록 트랜잭션 생성
        if private_key:
            tx_params = {
                "from": account_address,
                "gas": 100000,
                "gasPrice": web3.to_wei("50", "gwei"),
                "nonce": web3.eth.get_transaction_count(account_address),
            }

            tx = registry_contract.functions.setContractAddress(
                "SoftwareUpdateContract", contract_address
            ).build_transaction(tx_params)
            signed_tx = web3.eth.account.sign_transaction(tx, private_key)
            tx_hash = web3.eth.send_raw_transaction(signed_tx.raw_transaction)
        else:
            tx_hash = registry_contract.functions.setContractAddress(
                "SoftwareUpdateContract", contract_address
            ).transact(
                {
                    "from": account_address,
                    "gas": 100000,
                    "gasPrice": web3.to_wei("50", "gwei"),
                }
            )

        # 트랜잭션 영수증 대기
        tx_receipt = web3.eth.wait_for_transaction_receipt(tx_hash)

        if tx_receipt.status == 1:
            logger.info(f"레지스트리 업데이트 성공! 트랜잭션 해시: {tx_hash.hex()}")
            return True
        else:
            logger.error("레지스트리 업데이트 실패")
            return False

    except Exception as e:
        logger.error(f"레지스트리 업데이트 중 오류 발생: {str(e)}")
        return False


if __name__ == "__main__":
    deploy_contract()
