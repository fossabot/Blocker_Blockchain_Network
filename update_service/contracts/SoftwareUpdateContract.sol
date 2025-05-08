// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SoftwareUpdateContract
 * @dev 소프트웨어 업데이트를 등록, 구매, 배포, 설치 확인을 관리하는 컨트랙트 (권한 부여 기능 제거됨)
 */
contract SoftwareUpdateContract {
    /// @dev 제조사(관리자) 주소
    address public manufacturer;
    
    struct UpdateInfo {
        string uid;
        string ipfsHash;
        string encryptedKey;
        string hashOfUpdate;
        string description;
        uint256 price;
        string version;
        bool isValid;
    }
    
    struct UpdateGroup {
        // 권한 부여 관련 코드 제거
        UpdateInfo updateInfo;
    }
    
    mapping(string => UpdateGroup) private updateGroups;
    mapping(address => string[]) private ownerUpdates;
    
    event UpdateRegistered(string uid, string version, string description);
    event UpdateDelivered(address owner, string uid);
    event UpdateInstalled(address owner, string uid, string deviceId);
    
    constructor() {
        manufacturer = msg.sender;
    }
    
    modifier onlyManufacturer() {
        require(msg.sender == manufacturer, "Only manufacturer can call this function");
        _;
    }
    
    string[] private updateIds;
    
    function registerUpdate(
        string memory uid,
        string memory ipfsHash,
        string memory encryptedKey,
        string memory hashOfUpdate,
        string memory description,
        uint256 price,
        string memory version,
        bytes memory signature
    ) public {
        bytes32 messageHash = keccak256(abi.encodePacked(uid, ipfsHash, encryptedKey, hashOfUpdate, description, price, version));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        address signer = recoverSigner(ethSignedMessageHash, signature);
        require(signer == manufacturer, "Signature verification failed");
        require(msg.sender == manufacturer, "Only manufacturer can call this function");
        UpdateInfo memory newUpdate = UpdateInfo({
            uid: uid,
            ipfsHash: ipfsHash,
            encryptedKey: encryptedKey,
            hashOfUpdate: hashOfUpdate,
            description: description,
            price: price,
            version: version,
            isValid: true
        });
        updateGroups[uid].updateInfo = newUpdate;
        updateIds.push(uid);
        emit UpdateRegistered(uid, version, description);
    }

    function recoverSigner(bytes32 ethSignedMessageHash, bytes memory signature) internal pure returns (address) {
        require(signature.length == 65, "invalid signature length");
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }
        if (v < 27) v += 27;
        require(v == 27 || v == 28, "invalid v value");
        return ecrecover(ethSignedMessageHash, v, r, s);
    }
    
    // 권한 부여 없이 구매만 기록
    function purchaseUpdate(string memory uid) public payable {
        UpdateInfo storage update = updateGroups[uid].updateInfo;
        require(update.isValid, "Update is not valid");
        require(msg.value >= update.price, "Insufficient payment");
        ownerUpdates[msg.sender].push(uid);
        payable(manufacturer).transfer(msg.value);
        emit UpdateDelivered(msg.sender, uid);
    }
    
    // 권한 확인 및 암호화키 제공 없이 정보만 반환
    function getUpdateInfo(string memory uid) public view returns (
        string memory ipfsHash,
        string memory encryptedKey,
        string memory hashOfUpdate,
        string memory description,
        uint256 price,
        string memory version
    ) {
        UpdateInfo storage update = updateGroups[uid].updateInfo;
        return (
            update.ipfsHash,
            update.encryptedKey,
            update.hashOfUpdate,
            update.description,
            update.price,
            update.version
        );
    }
    
    // 설치 확인 시 권한 체크 제거
    function confirmInstallation(string memory uid, string memory deviceId) public {
        emit UpdateInstalled(msg.sender, uid, deviceId);
    }
    
    function getOwnerUpdates() public view returns (string[] memory) {
        return ownerUpdates[msg.sender];
    }
    
    function getUpdateCount() public view returns (uint256) {
        return updateIds.length;
    }
    
    function getUpdateIdByIndex(uint256 index) public view returns (string memory) {
        require(index < updateIds.length, "Index out of bounds");
        return updateIds[index];
    }

    function cancelUpdate(string memory uid) public onlyManufacturer {
        UpdateInfo storage update = updateGroups[uid].updateInfo;
        require(update.isValid, "Update is already invalid");
        update.isValid = false;
    }
}