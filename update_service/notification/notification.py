import os
import json
import logging
import time
from web3 import Web3
from dotenv import load_dotenv
from crypto.ecdsa.ecdsa import ECDSATools

# 로깅 설정
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# .env 파일 로드
load_dotenv()

root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../"))
MANUFACTURER_KEY_FOLDER = os.path.join(
    root_dir, "manufacturer/backend/keys"
)  # SKd 저장 폴더


class BlockchainNotifier:
    """블록체인 이벤트 관리 및 알림 클래스"""

    def __init__(self):
        """초기화"""
        # Web3 연결 설정
        self.web3_provider = os.getenv("WEB3_PROVIDER", "http://ganache:8545")
        self.account_address = os.getenv("ACCOUNT_ADDRESS", "")
        self.private_key = os.getenv("PRIVATE_KEY", "")

        # Web3 연결
        self.web3 = Web3(Web3.HTTPProvider(self.web3_provider))

        # 연결 확인
        try:
            if not self.web3.is_connected():
                raise ConnectionError(
                    f"Web3 제공자에 연결할 수 없습니다: {self.web3_provider}"
                )
            logger.info(f"Web3 연결 성공: {self.web3_provider}")
        except Exception as e:
            logger.error(f"Web3 연결 실패: {e}")
            raise

        # 컨트랙트 로드
        self._load_contract()

    def _load_contract(self):
        """스마트 컨트랙트 로드 (AddressRegistry를 통해 SoftwareUpdateContract 주소 동적 조회)"""
        try:
            # 1. AddressRegistry 정보 로드
            registry_path = os.path.join(
                root_dir, "registry-service/registry_address.txt"
            )
            if not os.path.exists(registry_path):
                raise FileNotFoundError(
                    f"레지스트리 주소 파일을 찾을 수 없습니다: {registry_path}"
                )
            with open(registry_path, "r") as f:
                registry_data = json.loads(f.read())
            registry_address = registry_data["address"]
            registry_abi = registry_data["abi"]

            # 2. AddressRegistry 컨트랙트 인스턴스 생성
            registry_contract = self.web3.eth.contract(
                address=registry_address, abi=registry_abi
            )

            # 3. SoftwareUpdateContract 주소 동적 조회
            update_contract_address = registry_contract.functions.getContractAddress(
                "SoftwareUpdateContract"
            ).call()
            if not update_contract_address or int(update_contract_address, 16) == 0:
                raise Exception(
                    "레지스트리에서 SoftwareUpdateContract 주소를 찾을 수 없습니다."
                )

            # 4. SoftwareUpdateContract ABI 로드 (contract_address.txt에서 ABI만 사용)
            contract_info_path = os.path.join(
                root_dir, "update_service/contract_address.txt"
            )
            if not os.path.exists(contract_info_path):
                raise FileNotFoundError(
                    f"컨트랙트 ABI 파일을 찾을 수 없습니다: {contract_info_path}"
                )
            with open(contract_info_path, "r") as f:
                contract_data = json.loads(f.read())
            contract_abi = contract_data["abi"]

            # 5. SoftwareUpdateContract 인스턴스 생성
            self.contract = self.web3.eth.contract(
                address=update_contract_address, abi=contract_abi
            )
            logger.info(f"스마트 컨트랙트 로드 완료 - 주소: {update_contract_address}")
        except Exception as e:
            logger.error(f"스마트 컨트랙트 로드 실패: {e}")
            raise Exception(f"스마트 컨트랙트 로드에 실패했습니다: {e}")

    def register_update(
        self,
        uid,
        ipfs_hash,
        encrypted_key,
        hash_of_update,
        description,
        price,
        version,
        signature,
    ):
        """새 업데이트 등록 (필수 서명 포함)"""
        try:
            if not signature:
                logger.error("서명이 제공되지 않았습니다")
                raise Exception("서명이 필요합니다")

            try:
                ecdsa_public_key_path = os.path.join(
                    MANUFACTURER_KEY_FOLDER, "ecdsa_public_key.pem"
                )
                manufacturer_public_key = ECDSATools.load_public_key(
                    ecdsa_public_key_path
                )
                if not manufacturer_public_key:
                    logger.error("제조사 공개키가 설정되지 않았습니다")
                    raise Exception("제조사 공개키 설정이 필요합니다")

                message = f"{uid}:{ipfs_hash}:{encrypted_key}:{hash_of_update}"
                logger.debug(f"서명 검증을 위한 메시지: {message[:50]}...")

                if not ECDSATools.verify_signature(
                    message, signature, manufacturer_public_key
                ):
                    logger.error("서명 검증 실패: 유효하지 않은 서명입니다")
                    raise Exception("서명 검증 실패")
                else:
                    logger.info("서명 검증 성공")

            except Exception as e:
                logger.error(f"서명 검증 중 오류: {e}")
                raise Exception(f"서명 검증 실패: {e}")

            logger.info(f"검증된 서명 signature: {signature}")
            logger.info(f"검증된 서명 타입: {type(signature)}")

            function = self.contract.functions.registerUpdate(
                uid,
                ipfs_hash,
                encrypted_key,
                hash_of_update,
                description,
                price,
                version,
                signature,
            )

            txn = function.build_transaction(
                {
                    "chainId": self.web3.eth.chain_id,
                    "gas": 2000000,
                    "gasPrice": self.web3.eth.gas_price,
                    "nonce": self.web3.eth.get_transaction_count(self.account_address),
                }
            )

            signed_txn = self.web3.eth.account.sign_transaction(
                txn, private_key=self.private_key
            )

            tx_hash = self.web3.eth.send_raw_transaction(signed_txn.raw_transaction)

            logger.info(f"업데이트 등록 트랜잭션 전송 완료 - 해시: {tx_hash.hex()}")

            tx_receipt = self.web3.eth.wait_for_transaction_receipt(
                tx_hash, timeout=120
            )
            logger.info(f"트랜잭션 상태: {tx_receipt.status}")

            if tx_receipt.status == 1:
                logger.info(
                    f"업데이트 '{uid}' 등록 완료 - 블록: {tx_receipt.blockNumber}"
                )
            else:
                logger.error(f"업데이트 등록 실패 - 트랜잭션 상태: {tx_receipt.status}")

            return tx_hash.hex()

        except Exception as e:
            logger.error(f"업데이트 등록 실패: {e}")
            raise

    def get_update_details(self, uid):
        """업데이트 세부 정보 조회"""
        try:
            logger.info(f"업데이트 세부 정보 조회: {uid}")
            if not uid:
                logger.warning("UID가 비어있습니다")
                return {
                    "uid": "unknown",
                    "ipfsHash": "",
                    "encryptedKey": "",
                    "hashOfUpdate": "",
                    "description": "세부 정보 없음",
                    "price": 0,
                    "version": "0.0.0",
                    "isAuthorized": False,
                }

            max_retries = 3
            last_error = None

            for attempt in range(max_retries):
                try:
                    update_info = self.contract.functions.getUpdateInfo(uid).call()

                    if not update_info or len(update_info) < 7:
                        logger.warning(f"업데이트 정보 불완전: {update_info}")
                        time.sleep(1)
                        continue

                    update = {
                        "uid": uid,
                        "ipfsHash": update_info[0],
                        "encryptedKey": update_info[1],
                        "hashOfUpdate": update_info[2],
                        "description": update_info[3],
                        "price": update_info[4],
                        "version": update_info[5],
                        "isAuthorized": update_info[6],
                    }

                    logger.info(
                        f"업데이트 정보 조회 성공 - UID: {uid}, 버전: {update['version']}"
                    )
                    return update
                except Exception as retry_error:
                    logger.warning(
                        f"시도 {attempt+1}/{max_retries} 실패: {retry_error}"
                    )
                    last_error = retry_error
                    time.sleep(1)

            logger.error(f"모든 시도 실패: {last_error}")
            raise last_error
        except Exception as e:
            logger.error(f"업데이트 세부 정보 조회 실패: {e}")
            return {
                "uid": uid,
                "ipfsHash": "",
                "encryptedKey": "",
                "hashOfUpdate": "",
                "description": f"조회 실패: {str(e)[:50]}",
                "price": 0,
                "version": "오류",
                "isAuthorized": False,
            }
