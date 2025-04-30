// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title AddressRegistry
 * @dev 스마트 컨트랙트 주소를 중앙에서 관리하는 레지스트리 컨트랙트
 */
contract AddressRegistry {
    address public admin;
    mapping(string => address) public contracts;
    
    event ContractAddressUpdated(string name, address indexed addr, uint256 timestamp);
    
    constructor() {
        admin = msg.sender;
    }
    
    modifier onlyAdmin() {
        require(msg.sender == admin, "Only admin can call this function");
        _;
    }
    
    /**
     * @dev 컨트랙트 주소를 등록하거나 업데이트합니다
     * @param name 컨트랙트 이름 (예: "SoftwareUpdateContract")
     * @param addr 컨트랙트 주소
     */
    function setContractAddress(string memory name, address addr) public onlyAdmin {
        require(addr != address(0), "Invalid contract address");
        contracts[name] = addr;
        emit ContractAddressUpdated(name, addr, block.timestamp);
    }
    
    /**
     * @dev 컨트랙트 주소를 조회합니다
     * @param name 컨트랙트 이름
     * @return 컨트랙트 주소
     */
    function getContractAddress(string memory name) public view returns (address) {
        address contractAddress = contracts[name];
        require(contractAddress != address(0), "Contract address not found");
        return contractAddress;
    }
    
    /**
     * @dev 관리자 권한을 다른 주소로 이전합니다
     * @param newAdmin 새 관리자 주소
     */
    function transferAdmin(address newAdmin) public onlyAdmin {
        require(newAdmin != address(0), "Invalid admin address");
        admin = newAdmin;
    }
}