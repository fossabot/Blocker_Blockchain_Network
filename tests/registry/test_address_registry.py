import pytest
from web3 import Web3
import json
import os


@pytest.fixture(scope="module")
def w3():
    return Web3(Web3.HTTPProvider("http://ganache:8545"))


@pytest.fixture(scope="module")
def contract(w3):
    # AddressRegistry.sol 파일을 읽지 않고, ABI/주소만 json에서 로드
    with open("/registry-service/registry_address.json") as f:
        data = json.load(f)
    abi = data["abi"]
    address = data["address"]
    return w3.eth.contract(address=address, abi=abi)


def test_admin_is_deployer(contract, w3):
    # 배포자 계정이 admin인지 확인
    admin = contract.functions.admin().call()
    assert admin == w3.eth.accounts[0]


def test_set_and_get_contract_address(contract, w3):
    admin = w3.eth.accounts[0]
    user = w3.eth.accounts[1]
    # admin이 setContractAddress 호출
    tx_hash = contract.functions.setContractAddress("TestContract", user).transact(
        {"from": admin}
    )
    w3.eth.wait_for_transaction_receipt(tx_hash)
    # 정상적으로 등록됐는지 확인
    addr = contract.functions.getContractAddress("TestContract").call()
    assert addr == user
    # admin이 아닌 계정이 setContractAddress 호출 시 revert
    try:
        contract.functions.setContractAddress("Fail", user).transact({"from": user})
        assert False, "비관리자 호출이 revert되어야 함"
    except Exception:
        pass
    # 없는 이름 조회시 revert
    try:
        contract.functions.getContractAddress("NotExist").call({"from": admin})
        assert False, "없는 이름 조회시 revert되어야 함"
    except Exception:
        pass
