// 스마트 컨트랙트 배포 스크립트
const { ethers } = require("hardhat");

async function main() {
    console.log("Deploying SoftwareUpdateManager...");

    // 배포용 계정 가져오기
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());

    // 스마트 컨트랙트 배포
    const SoftwareUpdateManager = await ethers.getContractFactory("SoftwareUpdateManager");
    const softwareUpdateManager = await SoftwareUpdateManager.deploy();
    await softwareUpdateManager.deployed();

    console.log("SoftwareUpdateManager deployed to:", softwareUpdateManager.address);
}

// 메인 함수 실행
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });