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
        bytes encryptedKey;
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
    mapping(address => mapping(string => uint256)) private escrowedPayments; // [구매자][업데이트ID] => 락업 금액
    mapping(address => mapping(string => bool)) private isInstalled; // [구매자][업데이트ID] => 설치 완료 여부
    mapping(address => mapping(string => bool)) private isRefunded; // [구매자][업데이트ID] => 환불 여부
    mapping(string => address[]) private updateBuyers; // 업데이트별 구매자 목록
    
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
        bytes memory encryptedKey,
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
    
    function purchaseUpdate(string memory uid) public payable {
        UpdateInfo storage update = updateGroups[uid].updateInfo;
        require(update.isValid, "Update is not valid");
        require(msg.value >= update.price, "Insufficient payment");
        require(escrowedPayments[msg.sender][uid] == 0, "Already purchased");
        ownerUpdates[msg.sender].push(uid);
        escrowedPayments[msg.sender][uid] = msg.value;
        updateBuyers[uid].push(msg.sender);
        emit UpdateDelivered(msg.sender, uid);
    }
    
    function getUpdateInfo(string memory uid) public view returns (
        string memory ipfsHash,
        bytes memory encryptedKey,
        string memory hashOfUpdate,
        string memory description,
        uint256 price,
        string memory version,
        bool isValid
    ) {
        UpdateInfo storage update = updateGroups[uid].updateInfo;
        return (
            update.ipfsHash,
            update.encryptedKey,
            update.hashOfUpdate,
            update.description,
            update.price,
            update.version,
            update.isValid
        );
    }
    
    function confirmInstallation(string memory uid, string memory deviceId) public {
        require(escrowedPayments[msg.sender][uid] > 0, "No escrowed payment");
        require(!isInstalled[msg.sender][uid], "Already installed");
        isInstalled[msg.sender][uid] = true;
        uint256 payment = escrowedPayments[msg.sender][uid];
        escrowedPayments[msg.sender][uid] = 0;
        payable(manufacturer).transfer(payment);
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
        require(bytes(update.uid).length != 0, "Update does not exist");
        require(update.isValid, "Update is already invalid");
        update.isValid = false;
        // 구매자 환불 처리
        address[] memory buyers = updateBuyers[uid];
        for (uint256 j = 0; j < buyers.length; j++) {
            address buyer = buyers[j];
            if (escrowedPayments[buyer][uid] > 0 && !isRefunded[buyer][uid] && !isInstalled[buyer][uid]) {
                uint256 refundAmount = escrowedPayments[buyer][uid];
                escrowedPayments[buyer][uid] = 0;
                isRefunded[buyer][uid] = true;
                payable(buyer).transfer(refundAmount);
            }
        }
    }

    // 구매자가 직접 환불을 요청할 수 있는 함수(업데이트가 취소된 경우만)
    function refundOnCancel(string memory uid) public {
        UpdateInfo storage update = updateGroups[uid].updateInfo;
        require(!update.isValid, "Update is not cancelled");
        require(escrowedPayments[msg.sender][uid] > 0, "No escrowed payment");
        require(!isInstalled[msg.sender][uid], "Already installed");
        require(!isRefunded[msg.sender][uid], "Already refunded");
        uint256 refundAmount = escrowedPayments[msg.sender][uid];
        escrowedPayments[msg.sender][uid] = 0;
        isRefunded[msg.sender][uid] = true;
        payable(msg.sender).transfer(refundAmount);
    }

    // 구매자가 CP-ABE 속성 미일치 등으로 설치 불가 시 환불 요청 함수
    function refundOnNotMatch(string memory uid) public {
        UpdateInfo storage update = updateGroups[uid].updateInfo;
        require(update.isValid, "Update is not valid (already cancelled)");
        require(escrowedPayments[msg.sender][uid] > 0, "No escrowed payment");
        require(!isInstalled[msg.sender][uid], "Already installed");
        require(!isRefunded[msg.sender][uid], "Already refunded");
        uint256 refundAmount = escrowedPayments[msg.sender][uid];
        escrowedPayments[msg.sender][uid] = 0;
        isRefunded[msg.sender][uid] = true;
        payable(msg.sender).transfer(refundAmount);
    }

    // 모든 구매자 주소를 반환(업데이트별)
    function getAllOwners(string memory uid) public view returns (address[] memory) {
        return updateBuyers[uid];
    }
    // 구매자가 아직 설치하지 않았고 환불도 받지 않은 업데이트 목록을 상세 정보 배열로 반환
    function getPendingUpdatesForOwner() public view returns (
        string[] memory uids,
        string[] memory ipfsHashes,
        bytes[] memory encryptedKeys,
        string[] memory hashOfUpdates,
        string[] memory descriptions,
        uint256[] memory prices,
        string[] memory versions,
        bool[] memory isValids
    ) {
        string[] storage allUpdates = ownerUpdates[msg.sender];
        uint256 count = 0;
        for (uint256 i = 0; i < allUpdates.length; i++) {
            string memory uid = allUpdates[i];
            if (!isInstalled[msg.sender][uid] && !isRefunded[msg.sender][uid]) {
                count++;
            }
        }
        uids = new string[](count);
        ipfsHashes = new string[](count);
        encryptedKeys = new bytes[](count);
        hashOfUpdates = new string[](count);
        descriptions = new string[](count);
        prices = new uint256[](count);
        versions = new string[](count);
        isValids = new bool[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < allUpdates.length; i++) {
            string memory uid = allUpdates[i];
            if (!isInstalled[msg.sender][uid] && !isRefunded[msg.sender][uid]) {
                UpdateInfo storage update = updateGroups[uid].updateInfo;
                uids[idx] = update.uid;
                ipfsHashes[idx] = update.ipfsHash;
                encryptedKeys[idx] = update.encryptedKey;
                hashOfUpdates[idx] = update.hashOfUpdate;
                descriptions[idx] = update.description;
                prices[idx] = update.price;
                versions[idx] = update.version;
                isValids[idx] = update.isValid;
                idx++;
            }
        }
    }
}