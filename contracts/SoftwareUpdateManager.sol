// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title Software Update Manager
 * @dev 제조사가 IoT 기기에 소프트웨어 업데이트를 안전하게 배포하는 스마트 컨트랙트
 */
contract SoftwareUpdateManager {
    // 상태 변수들
    address public owner;
    
    struct Update {
        string uid;               // 업데이트 고유 식별자 (url||version)
        bytes32 updateHash;       // 암호화된 업데이트 파일의 해시 값
        bytes encryptedKey;       // CP-ABE로 암호화된 키
        bytes signature;          // 제조사의 디지털 서명
        bool active;              // 업데이트 활성화 상태
        uint256 price;            // 업데이트 가격
        uint256 createdAt;        // 업데이트 생성 시간
    }
    
    // 제조사 정보
    struct Manufacturer {
        address addr;             // 제조사 주소
        string name;              // 제조사 이름
        bool active;              // 활성화 상태
        uint256 registeredAt;     // 등록 시간
    }
    
    // 업데이트 알림
    struct UpdateNotification {
        string uid;               // 업데이트 식별자
        address manufacturer;     // 제조사 주소
        string description;       // 업데이트 설명
        bool security;            // 보안 업데이트 여부
        bool bugFix;              // 버그 수정 여부
        bool feature;             // 기능 추가 여부
        string securityDesc;      // 보안 설명
        string bugFixDesc;        // 버그 수정 설명
        string featureDesc;       // 기능 설명
        uint256 notifiedAt;       // 알림 시간
    }
    
    // 매핑
    mapping(address => Manufacturer) public manufacturers;
    mapping(string => Update) public updates;
    mapping(string => UpdateNotification) public notifications;
    mapping(string => mapping(address => bool)) public updateAcceptance;
    
    // 이벤트
    event ManufacturerRegistered(address indexed manufacturer, string name);
    event UpdateRegistered(string uid, address indexed manufacturer, bytes32 updateHash);
    event NotificationSent(string uid, address indexed manufacturer);
    event UpdateAccepted(string uid, address indexed iotOwner);
    event KeyDelivered(string uid, address indexed iotOwner);
    event UpdateInstalled(string uid, address indexed iotDevice);
    
    // 생성자
    constructor() {
        owner = msg.sender;
    }
    
    // 제조사만 접근 가능한 제한자
    modifier onlyManufacturer() {
        require(manufacturers[msg.sender].active, "Not an active manufacturer");
        _;
    }
    
    // 관리자만 접근 가능한 제한자
    modifier onlyOwner() {
        require(msg.sender == owner, "Not the contract owner");
        _;
    }
    
    // 제조사 등록 함수
    function registerManufacturer(address _manufacturer, string memory _name) public onlyOwner {
        require(_manufacturer != address(0), "Invalid manufacturer address");
        require(bytes(_name).length > 0, "Name cannot be empty");
        require(!manufacturers[_manufacturer].active, "Manufacturer already registered");
        
        manufacturers[_manufacturer] = Manufacturer({
            addr: _manufacturer,
            name: _name,
            active: true,
            registeredAt: block.timestamp
        });
        
        emit ManufacturerRegistered(_manufacturer, _name);
    }
    
    // 업데이트 등록 함수
    function registerUpdate(
        string memory _uid,
        bytes32 _updateHash,
        bytes memory _encryptedKey,
        bytes memory _signature,
        uint256 _price
    ) public onlyManufacturer {
        require(bytes(_uid).length > 0, "UID cannot be empty");
        require(_updateHash != bytes32(0), "Update hash cannot be empty");
        require(_encryptedKey.length > 0, "Encrypted key cannot be empty");
        require(_signature.length > 0, "Signature cannot be empty");
        require(!updates[_uid].active, "Update already registered");
        
        updates[_uid] = Update({
            uid: _uid,
            updateHash: _updateHash,
            encryptedKey: _encryptedKey,
            signature: _signature,
            active: true,
            price: _price,
            createdAt: block.timestamp
        });
        
        emit UpdateRegistered(_uid, msg.sender, _updateHash);
    }
    
    // 업데이트 알림 전송 함수
    function sendUpdateNotification(
        string memory _uid,
        string memory _description,
        bool _security,
        bool _bugFix,
        bool _feature,
        string memory _securityDesc,
        string memory _bugFixDesc,
        string memory _featureDesc
    ) public onlyManufacturer {
        require(updates[_uid].active, "Update does not exist");
        
        notifications[_uid] = UpdateNotification({
            uid: _uid,
            manufacturer: msg.sender,
            description: _description,
            security: _security,
            bugFix: _bugFix,
            feature: _feature,
            securityDesc: _securityDesc,
            bugFixDesc: _bugFixDesc,
            featureDesc: _featureDesc,
            notifiedAt: block.timestamp
        });
        
        emit NotificationSent(_uid, msg.sender);
    }
    
    // 업데이트 수락 함수
    function acceptUpdate(string memory _uid) public {
        require(updates[_uid].active, "Update does not exist");
        require(notifications[_uid].manufacturer != address(0), "Notification not found");
        
        updateAcceptance[_uid][msg.sender] = true;
        
        emit UpdateAccepted(_uid, msg.sender);
    }
    
    // 키 전달 및 결제 함수 (atomic transaction)
    function deliverKeyAndPayment(string memory _uid) public payable {
        require(updates[_uid].active, "Update does not exist");
        require(updateAcceptance[_uid][msg.sender], "Update not accepted");
        require(msg.value >= updates[_uid].price, "Insufficient payment");
        
        // 과잉 지불된 금액 환불
        uint256 refundAmount = msg.value - updates[_uid].price;
        if (refundAmount > 0) {
            payable(msg.sender).transfer(refundAmount);
        }
        
        // 제조사에게 결제 전달
        payable(notifications[_uid].manufacturer).transfer(updates[_uid].price);
        
        // 키 전달 이벤트 발생
        emit KeyDelivered(_uid, msg.sender);
    }
    
    // 업데이트 설치 확인 함수
    function confirmUpdateInstallation(string memory _uid, address _iotDevice) public {
        require(updates[_uid].active, "Update does not exist");
        require(updateAcceptance[_uid][msg.sender], "Update not accepted by owner");
        
        emit UpdateInstalled(_uid, _iotDevice);
    }
    
    // 업데이트 상세 정보 조회 함수
    function getUpdateDetails(string memory _uid) public view returns (
        bytes32 updateHash,
        bytes memory encryptedKey,
        bytes memory signature,
        uint256 price,
        uint256 createdAt
    ) {
        Update storage update = updates[_uid];
        require(update.active, "Update does not exist");
        
        return (
            update.updateHash,
            update.encryptedKey,
            update.signature,
            update.price,
            update.createdAt
        );
    }
    
    // 업데이트 알림 상세 정보 조회 함수
    function getNotificationDetails(string memory _uid) public view returns (
        address manufacturer,
        string memory description,
        bool security,
        bool bugFix,
        bool feature,
        string memory securityDesc,
        string memory bugFixDesc,
        string memory featureDesc,
        uint256 notifiedAt
    ) {
        UpdateNotification storage notification = notifications[_uid];
        require(notification.manufacturer != address(0), "Notification not found");
        
        return (
            notification.manufacturer,
            notification.description,
            notification.security,
            notification.bugFix,
            notification.feature,
            notification.securityDesc,
            notification.bugFixDesc,
            notification.featureDesc,
            notification.notifiedAt
        );
    }
}