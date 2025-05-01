// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title SoftwareUpdateContract
 * @dev 소프트웨어 업데이트를 등록, 구매, 배포, 설치 확인을 관리하는 컨트랙트
 */
contract SoftwareUpdateContract {
    /// @dev 제조사(관리자) 주소
    address public manufacturer;
    
    /**
     * @dev 소프트웨어 업데이트 정보 구조체
     * @param uid 업데이트 고유 식별자
     * @param ipfsHash 업데이트 파일의 IPFS 해시
     * @param encryptedKey 암호화된 대칭키
     * @param hashOfUpdate 업데이트 파일의 해시값
     * @param description 업데이트 설명
     * @param price 업데이트 가격(wei)
     * @param version 업데이트 버전
     * @param isValid 유효성 여부
     */
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
    
    /**
     * @dev 업데이트 그룹 구조체 (업데이트별 권한 소유자 관리)
     * @param authorizedOwners 업데이트 접근 권한이 있는 소유자
     * @param updateInfo 업데이트 정보
     */
    struct UpdateGroup {
        mapping(address => bool) authorizedOwners;
        UpdateInfo updateInfo;
    }
    
    /// @dev uid별 업데이트 그룹 매핑
    mapping(string => UpdateGroup) private updateGroups;
    /// @dev 소유자별 구매한 업데이트 uid 목록
    mapping(address => string[]) private ownerUpdates;
    
    /// @dev 업데이트 등록 이벤트
    event UpdateRegistered(string uid, string version, string description);
    /// @dev 업데이트 전달(구매) 이벤트
    event UpdateDelivered(address owner, string uid);
    /// @dev 업데이트 설치 완료 이벤트
    event UpdateInstalled(address owner, string uid, string deviceId);
    
    /**
     * @dev 컨트랙트 배포 시 제조사(관리자) 지정
     */
    constructor() {
        manufacturer = msg.sender;
    }
    
    /**
     * @dev 오직 제조사만 호출 가능한 modifier
     */
    modifier onlyManufacturer() {
        require(msg.sender == manufacturer, "Only manufacturer can call this function");
        _;
    }
    
    /// @dev 전체 업데이트 uid 목록
    string[] private updateIds;
    
    /**
     * @dev 소프트웨어 업데이트 등록 (제조사만 가능)
     * @param uid 업데이트 고유 식별자
     * @param ipfsHash IPFS 해시
     * @param encryptedKey 암호화된 키
     * @param hashOfUpdate 파일 해시
     * @param description 설명
     * @param price 가격(wei)
     * @param version 버전
     */
    function registerUpdate(
        string memory uid,
        string memory ipfsHash,
        string memory encryptedKey,
        string memory hashOfUpdate,
        string memory description,
        uint256 price,
        string memory version,
        bytes memory /* signature */
    ) public onlyManufacturer {
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
    
    /**
     * @dev 업데이트 구매 및 권한 부여
     * @param uid 구매할 업데이트 uid
     */
    function purchaseUpdate(string memory uid) public payable {
        UpdateInfo storage update = updateGroups[uid].updateInfo;
        require(update.isValid, "Update is not valid");
        require(msg.value >= update.price, "Insufficient payment");
        
        updateGroups[uid].authorizedOwners[msg.sender] = true;
        ownerUpdates[msg.sender].push(uid);
        payable(manufacturer).transfer(msg.value);
        emit UpdateDelivered(msg.sender, uid);
    }
    
    /**
     * @dev 업데이트 정보 조회 (권한이 있으면 암호화 키 제공)
     * @param uid 조회할 업데이트 uid
     * @return ipfsHash 업데이트 파일의 IPFS 해시
     * @return encryptedKey 암호화된 대칭키 (권한이 있으면 반환)
     * @return hashOfUpdate 업데이트 파일의 해시값
     * @return description 업데이트 설명
     * @return price 업데이트 가격(wei)
     * @return version 업데이트 버전
     * @return isAuthorized 호출자의 권한 여부
     */
    function getUpdateInfo(string memory uid) public view returns (
        string memory ipfsHash,
        string memory encryptedKey,
        string memory hashOfUpdate,
        string memory description,
        uint256 price,
        string memory version,
        bool isAuthorized
    ) {
        UpdateInfo storage update = updateGroups[uid].updateInfo;
        bool authorized = updateGroups[uid].authorizedOwners[msg.sender];
        
        return (
            update.ipfsHash,
            authorized ? update.encryptedKey : "",
            update.hashOfUpdate,
            update.description,
            update.price,
            update.version,
            authorized
        );
    }
    
    /**
     * @dev 업데이트 설치 완료 확인 (권한 소유자만 가능)
     * @param uid 업데이트 uid
     * @param deviceId 설치한 디바이스 식별자
     */
    function confirmInstallation(string memory uid, string memory deviceId) public {
        require(updateGroups[uid].authorizedOwners[msg.sender], "Not authorized for this update");
        emit UpdateInstalled(msg.sender, uid, deviceId);
    }
    
    /**
     * @dev 소유자가 구매한 업데이트 uid 목록 반환
     */
    function getOwnerUpdates() public view returns (string[] memory) {
        return ownerUpdates[msg.sender];
    }
    
    /**
     * @dev 전체 등록된 업데이트 개수 반환
     */
    function getUpdateCount() public view returns (uint256) {
        return updateIds.length;
    }
    
    /**
     * @dev 인덱스로 업데이트 uid 조회
     * @param index 업데이트 인덱스
     * @return 업데이트 uid
     */
    function getUpdateIdByIndex(uint256 index) public view returns (string memory) {
        require(index < updateIds.length, "Index out of bounds");
        return updateIds[index];
    }
}