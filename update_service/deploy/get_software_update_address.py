from web3 import Web3
import json
import os

# Ganache 또는 실제 네트워크 주소로 변경
w3 = Web3(Web3.HTTPProvider("http://blockchain-server_ganache_1:8545"))

# 레지스트리 컨트랙트 정보 로드
registry_path = "/app/registry-service/registry_address.json"
with open(registry_path) as f:
    reg = json.load(f)

registry = w3.eth.contract(address=reg["address"], abi=reg["abi"])

# SoftwareUpdateContract 주소 조회
try:
    software_update_addr = registry.functions.getContractAddress("SoftwareUpdateContract").call()
    print("SoftwareUpdateContract address:", software_update_addr)
except Exception as e:
    print("오류 발생:", e)
