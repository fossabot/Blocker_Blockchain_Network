// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract SoftwareUpdateContract {
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
        mapping(address => bool) authorizedOwners;
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
    
    function purchaseUpdate(string memory uid) public payable {
        UpdateInfo storage update = updateGroups[uid].updateInfo;
        require(update.isValid, "Update is not valid");
        require(msg.value >= update.price, "Insufficient payment");
        
        updateGroups[uid].authorizedOwners[msg.sender] = true;
        ownerUpdates[msg.sender].push(uid);
        payable(manufacturer).transfer(msg.value);
        emit UpdateDelivered(msg.sender, uid);
    }
    
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
    
    function confirmInstallation(string memory uid, string memory deviceId) public {
        require(updateGroups[uid].authorizedOwners[msg.sender], "Not authorized for this update");
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
}