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
def load_env():
    load_dotenv()
    web3_provider = os.getenv("WEB3_PROVIDER", "http://host.docker.internal:8545")
    private_key = os.getenv("PRIVATE_KEY", "")
    account_address = os.getenv(
        "ACCOUNT_ADDRESS", "0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    )
    if not private_key:
        logger.warning(
            "PRIVATE_KEY 환경 변수가 비어 있습니다. 서명 트랜잭션이 불가할 수 있습니다."
        )
    if not account_address:
        logger.warning(
            "ACCOUNT_ADDRESS 환경 변수가 비어 있습니다. 기본값을 사용합니다."
        )
    return web3_provider, private_key, account_address


def wait_for_web3_connection(web3_provider, max_retries=20, wait_sec=3):
    logger.info(f"외부 블록체인 서버에 연결 시도 중: {web3_provider}")
    retries = 0
    while retries < max_retries:
        try:
            web3 = Web3(Web3.HTTPProvider(web3_provider))
            if web3.is_connected():
                logger.info("Web3 연결 성공!")
                return web3
            else:
                logger.warning(
                    f"Web3 연결 실패, {retries+1}/{max_retries} 재시도 중..."
                )
        except Exception as e:
            logger.warning(
                f"Web3 연결 중 오류 발생: {e}, {retries+1}/{max_retries} 재시도 중..."
            )
        retries += 1
        time.sleep(wait_sec)
    raise ConnectionError(
        f"{max_retries}번 시도 후 Web3 제공자에 연결할 수 없습니다: {web3_provider}"
    )


def compile_contract(contract_path, solc_version="0.8.17"):
    try:
        set_solc_version(solc_version)
        logger.info(f"Solidity 컴파일러 버전 설정 완료: {solc_version}")
    except Exception as e:
        logger.error(f"Solidity 컴파일러 버전 설정 실패: {e}")
        raise
    with open(contract_path, "r") as file:
        contract_source = file.read()
    try:
        compiled_sol = compile_source(
            contract_source,
            output_values=["abi", "bin"],
            solc_version=solc_version,
            optimize=True,
            optimize_runs=200,
        )
        logger.info("컨트랙트 컴파일 성공!")
    except Exception as e:
        logger.error(f"컨트랙트 컴파일 실패: {e}")
        raise
    contract_id = list(compiled_sol.keys())[0]
    contract_interface = compiled_sol[contract_id]
    return contract_interface["abi"], contract_interface["bin"]


def deploy_contract(web3, abi, bytecode, account_address, private_key):
    AddressRegistry = web3.eth.contract(abi=abi, bytecode=bytecode)
    web3.eth.default_account = account_address
    if private_key:
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
        tx_hash = AddressRegistry.constructor().transact(
            {
                "from": account_address,
                "gas": 3000000,
                "gasPrice": web3.to_wei("50", "gwei"),
            }
        )
    tx_receipt = web3.eth.wait_for_transaction_receipt(tx_hash)
    contract_address = tx_receipt.contractAddress
    logger.info(f"레지스트리 컨트랙트 배포 성공! 주소: {contract_address}")
    return contract_address


def save_registry_info(contract_address, abi, output_path):
    registry_data = {"address": contract_address, "abi": abi}
    with open(output_path, "w") as f:
        f.write(json.dumps(registry_data))
    logger.info(f"레지스트리 컨트랙트 정보가 {output_path}에 저장되었습니다.")


def main():
    logger.info("서비스 시작... 5초 후 레지스트리 컨트랙트 배포를 시작합니다.")
    time.sleep(5)
    try:
        web3_provider, private_key, account_address = load_env()
        web3 = wait_for_web3_connection(web3_provider)
        logger.info(f"사용할 계정 주소: {account_address}")
        contract_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "contracts",
            "AddressRegistry.sol",
        )
        abi, bytecode = compile_contract(contract_path)
        contract_address = deploy_contract(
            web3, abi, bytecode, account_address, private_key
        )
        registry_info_path = os.path.join(
            os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
            "registry_address.json",
        )
        save_registry_info(contract_address, abi, registry_info_path)
        logger.info(f"레지스트리 컨트랙트 배포 완료. 주소: {contract_address}")
        logger.info("모든 작업이 완료되었습니다. 서비스를 종료합니다.")
    except Exception as e:
        logger.error(f"오류 발생: {e}")
        exit(1)


if __name__ == "__main__":
    main()
