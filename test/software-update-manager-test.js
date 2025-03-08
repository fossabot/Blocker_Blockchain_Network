const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("SoftwareUpdateManager", function () {
    let softwareUpdateManager;
    let owner;
    let manufacturer;
    let iotOwner;
    let iotDevice;
    let addrs;

    // 테스트용 상수
    const MANUFACTURER_NAME = "TestManufacturer";
    const UPDATE_UID = "https://example.com/updates/v1.0";
    const UPDATE_HASH = ethers.utils.keccak256(ethers.utils.toUtf8Bytes("testUpdate"));
    const ENCRYPTED_KEY = ethers.utils.toUtf8Bytes("encryptedKey");
    const SIGNATURE = ethers.utils.toUtf8Bytes("signature");
    const UPDATE_PRICE = ethers.utils.parseEther("0.01");
    const UPDATE_DESCRIPTION = "Test Update";

    beforeEach(async function () {
        // 컨트랙트 배포
        const SoftwareUpdateManager = await ethers.getContractFactory("SoftwareUpdateManager");
        [owner, manufacturer, iotOwner, iotDevice, ...addrs] = await ethers.getSigners();
        softwareUpdateManager = await SoftwareUpdateManager.deploy();
        await softwareUpdateManager.deployed();

        // 제조사 등록
        await softwareUpdateManager.registerManufacturer(manufacturer.address, MANUFACTURER_NAME);
    });

    describe("Manufacturer Registration", function () {
        it("Should register a manufacturer correctly", async function () {
            const manufacturerInfo = await softwareUpdateManager.manufacturers(manufacturer.address);
            expect(manufacturerInfo.name).to.equal(MANUFACTURER_NAME);
            expect(manufacturerInfo.active).to.be.true;
        });

        it("Should fail if not owner tries to register a manufacturer", async function () {
            await expect(
                softwareUpdateManager.connect(manufacturer).registerManufacturer(addrs[0].address, "InvalidManufacturer")
            ).to.be.revertedWith("Not the contract owner");
        });
    });

    describe("Update Registration", function () {
        it("Should register an update correctly", async function () {
            await softwareUpdateManager.connect(manufacturer).registerUpdate(
                UPDATE_UID,
                UPDATE_HASH,
                ENCRYPTED_KEY,
                SIGNATURE,
                UPDATE_PRICE
            );

            const updateInfo = await softwareUpdateManager.updates(UPDATE_UID);
            expect(updateInfo.uid).to.equal(UPDATE_UID);
            expect(updateInfo.updateHash).to.equal(UPDATE_HASH);
            expect(updateInfo.active).to.be.true;
            expect(updateInfo.price).to.equal(UPDATE_PRICE);
        });

        it("Should fail if non-manufacturer tries to register an update", async function () {
            await expect(
                softwareUpdateManager.connect(iotOwner).registerUpdate(
                    UPDATE_UID,
                    UPDATE_HASH,
                    ENCRYPTED_KEY,
                    SIGNATURE,
                    UPDATE_PRICE
                )
            ).to.be.revertedWith("Not an active manufacturer");
        });
    });

    describe("Update Notification", function () {
        beforeEach(async function () {
            await softwareUpdateManager.connect(manufacturer).registerUpdate(
                UPDATE_UID,
                UPDATE_HASH,
                ENCRYPTED_KEY,
                SIGNATURE,
                UPDATE_PRICE
            );
        });

        it("Should send notification correctly", async function () {
            await softwareUpdateManager.connect(manufacturer).sendUpdateNotification(
                UPDATE_UID,
                UPDATE_DESCRIPTION,
                true, // security
                false, // bugFix
                true, // feature
                "Security fix", // securityDesc
                "", // bugFixDesc
                "New feature" // featureDesc
            );

            const notificationInfo = await softwareUpdateManager.notifications(UPDATE_UID);
            expect(notificationInfo.description).to.equal(UPDATE_DESCRIPTION);
            expect(notificationInfo.manufacturer).to.equal(manufacturer.address);
            expect(notificationInfo.security).to.be.true;
            expect(notificationInfo.bugFix).to.be.false;
            expect(notificationInfo.feature).to.be.true;
        });
    });

    describe("Update Acceptance and Key Delivery", function () {
        beforeEach(async function () {
            await softwareUpdateManager.connect(manufacturer).registerUpdate(
                UPDATE_UID,
                UPDATE_HASH,
                ENCRYPTED_KEY,
                SIGNATURE,
                UPDATE_PRICE
            );
            await softwareUpdateManager.connect(manufacturer).sendUpdateNotification(
                UPDATE_UID,
                UPDATE_DESCRIPTION,
                true,
                false,
                true,
                "Security fix",
                "",
                "New feature"
            );
        });

        it("Should accept update correctly", async function () {
            await softwareUpdateManager.connect(iotOwner).acceptUpdate(UPDATE_UID);
            const accepted = await softwareUpdateManager.updateAcceptance(UPDATE_UID, iotOwner.address);
            expect(accepted).to.be.true;
        });

        it("Should deliver key and process payment correctly", async function () {
            await softwareUpdateManager.connect(iotOwner).acceptUpdate(UPDATE_UID);

            const manufacturerBalanceBefore = await ethers.provider.getBalance(manufacturer.address);

            await expect(
                softwareUpdateManager.connect(iotOwner).deliverKeyAndPayment(UPDATE_UID, {
                    value: UPDATE_PRICE
                })
            ).to.emit(softwareUpdateManager, "KeyDelivered")
                .withArgs(UPDATE_UID, iotOwner.address);

            const manufacturerBalanceAfter = await ethers.provider.getBalance(manufacturer.address);
            expect(manufacturerBalanceAfter.sub(manufacturerBalanceBefore)).to.equal(UPDATE_PRICE);
        });

        it("Should confirm update installation", async function () {
            await softwareUpdateManager.connect(iotOwner).acceptUpdate(UPDATE_UID);
            await softwareUpdateManager.connect(iotOwner).deliverKeyAndPayment(UPDATE_UID, {
                value: UPDATE_PRICE
            });

            await expect(
                softwareUpdateManager.connect(iotOwner).confirmUpdateInstallation(UPDATE_UID, iotDevice.address)
            ).to.emit(softwareUpdateManager, "UpdateInstalled")
                .withArgs(UPDATE_UID, iotDevice.address);
        });
    });
});