import { expect } from "chai";
import { ethers } from "hardhat";
import { time } from "@nomicfoundation/hardhat-network-helpers";

describe("Bond Token Contract", function () {
    let Bond: any;
    let KYC: any;
    let CSR: any;
    let Documents: any;
    let StableCoin: any;
    let owner: any;
    let addr1: any;
    let addr2: any;
    let regulator: any;
    let registrar: any;
    let kycProvider: any;

    beforeEach(async function () {
        [owner, addr1, addr2, regulator, registrar, kycProvider] = await ethers.getSigners();

        // Deploy mock contracts for KYC, CSR, Documents, and ERC20 stable coin
        const KYCContract = await ethers.getContractFactory("KycContract");
        KYC = await KYCContract.deploy();

        const CSRContract = await ethers.getContractFactory("CSRContract");
        CSR = await CSRContract.deploy();

        const DocumentsContract = await ethers.getContractFactory("DocumentContract");
        Documents = await DocumentsContract.deploy();

        const StableCoinContract = await ethers.getContractFactory("StableCoin");
        StableCoin = await StableCoinContract.deploy("StableCoin", "EUR");

        // Deploy Bond contract
        const BondContract = await ethers.getContractFactory("Bond");
        Bond = await BondContract.deploy();

        // Set other contracts in Bond contract
        await Bond.setKycContract(KYC.target);
        await Bond.setCSRContract(CSR.target);
        await Bond.setDocumentsContract(Documents.target);
        await Bond.setStableCoinContract(StableCoin.target);

        it("Should set the right owner", async function () {
            expect(await Bond.owner()).to.equal(await owner.address);
        });

        it("Should initialize with correct values", async function () {
            expect(await Bond.issuerAddress()).to.equal(await owner.address);
            expect(await Bond.regulator()).to.equal(ethers.ZeroAddress);
        });

        // Set registrar and regulator in CSR contract
        await CSR.setRegistrar(registrar.address);
        await CSR.setRegulator(regulator.address);
        await CSR.setKycContract(KYC.target);
        await CSR.setBondTokenContract(Bond.target);

        // Set KYC provider
        await KYC.setKycProvider(kycProvider.address);
        await KYC.setCSRContract(CSR.target);
        await KYC.setBondTokenContract(Bond.target);
    });

    describe("Minting", function () {
        it("Should mint a token and emit TokenMinted event", async function () {
            await setCSRData(CSR, registrar, regulator, owner);
            
            // Mint token in Bond contract
            await Bond.mintToken(1);

            // Check that the TokenMinted event was emitted
            await expect(Bond.mintToken(1))
                .to.emit(Bond, "TokenMinted");
        });
    });

    describe("Buying Tokens with ETH", function () {
        it("Should allow buying tokens with ETH", async function () {

            await setCSRData(CSR, registrar, regulator, owner);

            // Mint token in Bond Contract
            await Bond.mintToken(1);

            await KYC.connect(kycProvider).setKycCompleted(addr1.address, 0);

            await Bond.connect(addr1).buyTokensETHER(1, 10, { value: ethers.parseEther("10") });

            let balance = await Bond.balanceOf(addr1.address, 1);
            expect(balance).to.equal(10);
        });

        it("Should reject buying tokens with incorrect ETH amount", async function () {
            await setCSRData(CSR, registrar, regulator, owner);
            
            // Mint token in Bond Contract
            await Bond.mintToken(1);

            await KYC.connect(kycProvider).setKycCompleted(addr1.address, 0);

            const incorrectAmount = ethers.parseEther("0.5"); // Incorrect ETH amount
            await expect(Bond.connect(addr1).buyTokensETHER(1, 10, { value: incorrectAmount })).to.be.revertedWith("Check msg.value");
        });
    });

    describe("Paying Coupons", function () {
        it("Should pay coupons and emit CouponPaid event", async function () {
            await setCSRData(CSR, registrar, regulator, owner);
            
            // Mint token in Bond Contract
            await Bond.mintToken(1);

            let expectedBalanceAfter = await ethers.provider.getBalance(addr1.address) + ethers.parseEther("1");

            await Bond.payCoupon(1, addr1.address, { value: ethers.parseEther("1")});

            expect(await ethers.provider.getBalance(addr1.address)).to.be.closeTo(expectedBalanceAfter, ethers.parseEther("0.01"));
            await expect(Bond.payCoupon(1, addr1.address, { value: ethers.parseEther("1") }))
                .to.emit(Bond, "CouponPaid");
        });
    });

    describe("Token Transfer", function () {
        it("Should transfer tokens and emit TokenTransfered event", async function () {
            await setCSRData(CSR, registrar, regulator, owner);
            
            // Mint token in Bond Contract
            await Bond.mintToken(1);

            await KYC.connect(kycProvider).setKycCompleted(addr1, 0);

            await Bond.safeTransferFrom(owner.address, addr1.address, 1, 10, "0x");

            expect(await Bond.balanceOf(addr1.address, 1)).to.equal(10);
            await expect(Bond.safeTransferFrom(owner.address, addr1.address, 1, 10, "0x"))
                .to.emit(Bond, "TokenTransfered");
        });
    });

    describe("Forced Transfer Requests", function () {
        it("Should allow regulators to request forced transfer and emit RequestForcedTransfer event", async function () {
            await setCSRData(CSR, registrar, regulator, owner);
            
            // Mint token in Bond Contract
            await Bond.mintToken(1);
            
            await Bond.setRegulator(regulator.address);

            await expect(Bond.connect(regulator).requestForcedTransfer(1, addr1.address, 5))
                .to.emit(Bond, "RequestForcedTransfer")
                .withArgs(0, 1, addr1.address, 5);

            const regulatoryRequest = await Bond.RegulatoryRequests(0);

            expect(regulatoryRequest.tokenID).to.equal(1);
            expect(regulatoryRequest.investor).to.equal(addr1.address);
            expect(regulatoryRequest.amount).to.equal(5);
            expect(regulatoryRequest.executed).to.equal(false);
        });

        it("Should execute forced transfer and emit ForcedTokenTransfered event", async function () {
            await setCSRData(CSR, registrar, regulator, owner);
            
            // Mint token in Bond Contract
            await Bond.mintToken(1);
            
            await Bond.setRegulator(regulator.address);

            await KYC.connect(kycProvider).setKycCompleted(addr1, 0);

            await Bond.safeTransferFrom(owner.address, addr1.address, 1, 10, "0x");

            await Bond.connect(regulator).requestForcedTransfer(1, addr1.address, 5);

            await expect(Bond.connect(regulator).forcedTransfer(0))
                .to.emit(Bond, "ForcedTokenTransfered");

            expect(await Bond.balanceOf(addr1.address, 1)).to.equal(5);
        });

        it("Should not allow duplicate forced transfer execution", async function () {
            await setCSRData(CSR, registrar, regulator, owner);
            
            // Mint token in Bond Contract
            await Bond.mintToken(1);
            
            await Bond.setRegulator(regulator.address);

            await KYC.connect(kycProvider).setKycCompleted(addr1, 0);

            await Bond.safeTransferFrom(owner.address, addr1.address, 1, 10, "0x");

            await Bond.connect(regulator).requestForcedTransfer(1, addr1.address, 5);

            await Bond.connect(regulator).forcedTransfer(0);

            await expect(Bond.connect(regulator).forcedTransfer(0)).to.be.revertedWith("Request already executed");
        });
    });

    describe("Redemption Buy-Back", function () {
        it("Should not redeem tokens before maturity", async function () {
            await setCSRData(CSR, registrar, regulator, owner);
            
            // Mint token in Bond Contract
            await Bond.mintToken(1);
            
            //await CSR.setTokenData(1, 1000, 1, 1, 1, 1, 1, Math.floor(Date.now() / 1000) + 3600, Math.floor(Date.now() / 1000) + 7200); // Mock CSR data
            await KYC.connect(kycProvider).setKycCompleted(addr1, 0);

            await Bond.safeTransferFrom(owner.address, addr1.address, 1, 10, "0x");

            await expect(Bond.redemptionBuyBack(addr1.address, 1)).to.be.revertedWith("Bond not matured yet");
        });
        
        it("Should redeem and buy back tokens after maturity", async function () {
            await setCSRData(CSR, registrar, regulator, owner);
            
            // Mint token in Bond Contract
            await Bond.mintToken(1);

            await KYC.connect(kycProvider).setKycCompleted(addr1, 0);

            await Bond.safeTransferFrom(owner.address, addr1.address, 1, 10, "0x");

            const currentBlockTimestamp = (await ethers.provider.getBlock('latest'))!.timestamp;
            
            const newTimestamp = currentBlockTimestamp + (86400 * 366);  // 1 year and 1 day in the future
            await ethers.provider.send("evm_mine", [newTimestamp]);
        
            await Bond.connect(addr1).redemptionBuyBack(addr1.address, 1);

            expect(await Bond.balanceOf(addr1.address, 1)).to.equal(0);
            expect(await Bond.BuyBack(1, addr1.address)).to.equal(10);
        });
    });
});

async function setCSRData(CSR: any, registrar: any, regulator: any, owner: any) {
    let inOneDay = Math.floor(Date.now() / 1000) + (86400 * 1);
    let inOneYear = Math.floor(Date.now() / 1000) + (86400 * 365);

    await CSR.connect(registrar).setTokenData(owner.address, 1, 1000, 1, 1, 1, "TestIssuer", "NewEntry");
    await CSR.connect(registrar).setDates(1, inOneDay, inOneYear)
    await CSR.connect(registrar).setDataComplete(1);
    await CSR.connect(regulator).setRegulatoryApproval(1);
}
