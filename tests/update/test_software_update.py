import pytest
from web3 import Web3
import json
import os


@pytest.fixture(scope="module")
def w3():
    return Web3(Web3.HTTPProvider("http://ganache:8545"))


@pytest.fixture(scope="module")
def contract(w3):
    # SoftwareUpdateContract.sol 파일을 읽지 않고, ABI/주소만 json에서 로드
    with open("/update_service/contract_address.json") as f:
        data = json.load(f)
    abi = data["abi"]
    address = data["address"]
    return w3.eth.contract(address=address, abi=abi)


def test_manufacturer_is_deployer(contract, w3):
    manufacturer = contract.functions.manufacturer().call()
    assert manufacturer == w3.eth.accounts[0]


def test_register_update_and_query(contract, w3):
    manufacturer = w3.eth.accounts[0]
    user = w3.eth.accounts[1]
    uid = "update-001"
    ipfs = "QmTestHash"
    encrypted_key = "encKey"
    hash_of_update = "hash123"
    desc = "테스트 업데이트"
    price = 1000
    version = "1.0.0"
    # 제조사가 registerUpdate 호출
    tx_hash = contract.functions.registerUpdate(
        uid, ipfs, encrypted_key, hash_of_update, desc, price, version, b""
    ).transact({"from": manufacturer})
    w3.eth.wait_for_transaction_receipt(tx_hash)
    # getUpdateCount, getUpdateIdByIndex로 확인
    count = contract.functions.getUpdateCount().call()
    assert count > 0
    found_uid = contract.functions.getUpdateIdByIndex(0).call()
    assert found_uid == uid
    # 비제조사가 registerUpdate 호출 시 revert
    try:
        contract.functions.registerUpdate(
            "fail", ipfs, encrypted_key, hash_of_update, desc, price, version, b""
        ).transact({"from": user})
        assert False, "비제조사 호출이 revert되어야 함"
    except Exception:
        pass


def test_purchase_and_get_update_info(contract, w3):
    manufacturer = w3.eth.accounts[0]
    user = w3.eth.accounts[1]
    uid = "update-unique-001"
    ipfs = "QmTestHash2"
    encrypted_key = "encKey2"
    hash_of_update = "hash456"
    desc = "테스트 업데이트2"
    price = 2000
    version = "2.0.0"
    # 새로운 업데이트 등록
    tx_hash = contract.functions.registerUpdate(
        uid, ipfs, encrypted_key, hash_of_update, desc, price, version, b""
    ).transact({"from": manufacturer})
    w3.eth.wait_for_transaction_receipt(tx_hash)
    # 구매 전 권한 없음
    info = contract.functions.getUpdateInfo(uid).call({"from": user})
    assert info[-1] is False  # isAuthorized
    # 구매
    tx_hash = contract.functions.purchaseUpdate(uid).transact(
        {"from": user, "value": price}
    )
    w3.eth.wait_for_transaction_receipt(tx_hash)
    # 구매 후 권한 있음
    info = contract.functions.getUpdateInfo(uid).call({"from": user})
    assert info[-1] is True
    # 금액 부족시 revert
    try:
        contract.functions.purchaseUpdate(uid).transact({"from": user, "value": 1})
        assert False, "금액 부족시 revert되어야 함"
    except Exception:
        pass


def test_confirm_installation_and_owner_updates(contract, w3):
    user = w3.eth.accounts[1]
    uid = "update-001"
    device_id = "device-abc"
    # 권한 없는 계정이 confirmInstallation 호출 시 revert
    try:
        contract.functions.confirmInstallation(uid, device_id).transact(
            {"from": w3.eth.accounts[2]}
        )
        assert False, "권한 없는 계정이 호출시 revert되어야 함"
    except Exception:
        pass
    # 권한 있는 계정이 호출
    tx_hash = contract.functions.confirmInstallation(uid, device_id).transact(
        {"from": user}
    )
    w3.eth.wait_for_transaction_receipt(tx_hash)
    # getOwnerUpdates로 구매한 업데이트 목록 확인
    updates = contract.functions.getOwnerUpdates().call({"from": user})
    assert uid in updates
