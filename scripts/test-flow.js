const { ethers } = require("hardhat");
const fs = require("fs");
const crypto = require("crypto");

async function main() {
    console.log("소프트웨어 업데이트 프레임워크 테스트 시작...");

    // 계정 가져오기
    const [owner, manufacturer, iotOwner, iotDevice] = await ethers.getSigners();

    console.log("테스트 계정:");
    console.log("- 소유자:", owner.address);
    console.log("- 제조사:", manufacturer.address);
    console.log("- IoT 사용자:", iotOwner.address);
    console.log("- IoT 디바이스:", iotDevice.address);

    // 배포된 컨트랙트 주소
    const contractAddress = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
    const SoftwareUpdateManager = await ethers.getContractFactory("SoftwareUpdateManager");
    const softwareUpdateManager = await SoftwareUpdateManager.attach(contractAddress);

    // 1. 제조사 등록
    console.log("\n1. 제조사 등록 중...");
    const tx1 = await softwareUpdateManager.registerManufacturer(manufacturer.address, "테스트제조사");
    await tx1.wait();
    console.log("제조사 등록 완료");

    // 2. 업데이트 파일 준비 (실제로는 CP-ABE로 암호화)
    console.log("\n2. 업데이트 파일 준비 중...");

    // 소프트웨어 업데이트 파일 시뮬레이션
    const softwareUpdate = "이것은 테스트 소프트웨어 업데이트입니다.";
    const updateBuffer = Buffer.from(softwareUpdate);

    // 파일 해시 생성 (실제로는 SHA-3 사용)
    const updateHash = ethers.utils.keccak256(updateBuffer);

    // 암호화 키 (CP-ABE 암호화된 키 시뮬레이션)
    const encryptedKey = ethers.utils.toUtf8Bytes("encryptedKey");

    // 제조사 서명 (ECDSA 서명 시뮬레이션)
    const signature = ethers.utils.toUtf8Bytes("signature");

    // 업데이트 가격 (0.01 ETH)
    const updatePrice = ethers.utils.parseEther("0.01");

    console.log("업데이트 정보:");
    console.log("- 해시:", updateHash);
    console.log("- 가격:", ethers.utils.formatEther(updatePrice), "ETH");

    // 3. 업데이트 등록
    console.log("\n3. 업데이트 등록 중...");
    const updateUID = "https://example.com/updates/v1.0";

    const tx2 = await softwareUpdateManager.connect(manufacturer).registerUpdate(
        updateUID,
        updateHash,
        encryptedKey,
        signature,
        updatePrice
    );
    await tx2.wait();
    console.log("업데이트 등록 완료:", updateUID);

    // 4. 업데이트 알림 전송
    console.log("\n4. 업데이트 알림 전송 중...");

    const tx3 = await softwareUpdateManager.connect(manufacturer).sendUpdateNotification(
        updateUID,
        "중요 보안 업데이트",
        true,   // 보안
        false,  // 버그 수정
        true,   // 기능
        "보안 취약점 패치",  // 보안 설명
        "",                 // 버그 수정 설명
        "새로운 기능 추가"   // 기능 설명
    );
    await tx3.wait();
    console.log("업데이트 알림 전송 완료");

    // 5. IoT 소유자가 업데이트 수락
    console.log("\n5. 업데이트 수락 중...");
    const tx4 = await softwareUpdateManager.connect(iotOwner).acceptUpdate(updateUID);
    await tx4.wait();
    console.log("업데이트 수락 완료");

    // 6. 키 전달 및 결제
    console.log("\n6. 업데이트 키 전달 및 결제 중...");
    const tx5 = await softwareUpdateManager.connect(iotOwner).deliverKeyAndPayment(updateUID, {
        value: updatePrice
    });
    await tx5.wait();
    console.log("키 전달 및 결제 완료");

    // 7. 업데이트 설치 확인
    console.log("\n7. 업데이트 설치 확인 중...");
    const tx6 = await softwareUpdateManager.connect(iotOwner).confirmUpdateInstallation(updateUID, iotDevice.address);
    await tx6.wait();
    console.log("업데이트 설치 확인 완료");

    // 8. 업데이트 상세 정보 조회
    console.log("\n8. 업데이트 상세 정보 조회 중...");
    const updateDetails = await softwareUpdateManager.getUpdateDetails(updateUID);
    console.log("업데이트 상세 정보:");
    console.log("- 해시:", updateDetails[0]);
    console.log("- 생성 시간:", updateDetails[4].toString());

    console.log("\n테스트 완료!");
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });