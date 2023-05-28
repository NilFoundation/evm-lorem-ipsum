const Hardhat = require("hardhat");
const fs = require('fs');
const { expect } = require("chai");
const { inputFile } = require("hardhat/internal/core/params/argumentTypes");
const { Console } = require("console");

const fixtures_path = require("path").join(__dirname, "../fixtures/");

function parseJsonFile(filePath) {
    try {
        const jsonData = fs.readFileSync(filePath, 'utf-8');
        let data = JSON.parse(jsonData);
        // Transform array elements to bytes[]
        data.accountProof = data.accountProof.map(item => Hardhat.ethers.utils.arrayify(item));
        data.storageProof = data.storageProof.map(item => Hardhat.ethers.utils.arrayify(item));

        return data;
    } catch (error) {
        console.error('Error parsing JSON file:', error);
        return null;
    }
}

describe("ExecuteMessage", function () {
    let addr1;
    let reciever;
    let protocolState;
    let data;
    const inputFile = fixtures_path + "message1.json";

    beforeEach(async function () {
        data = parseJsonFile(inputFile);

        let [signer1] = await Hardhat.ethers.getSigners();

        addr1 = await signer1.getAddress();

        const MockProtocolState = await Hardhat.ethers.getContractFactory("MockProtocolState");
        protocolState = await MockProtocolState.deploy();
        await protocolState.deployed();
        const protocolStateAddr = protocolState.address;

        const TargetAMB = await Hardhat.ethers.getContractFactory("MockTargetAMB");
        let targetAMB = await TargetAMB.deploy([5], [protocolStateAddr], [Hardhat.ethers.utils.getAddress(data.sourceAMBAddress)]);
        await targetAMB.deployed();
        reciever = await Hardhat.ethers.getContractAt("ILoremIpsumReceiver", targetAMB.address);
    });

    it("Should emit ExecutedMessage", async function () {
        const slot = data.blockNumber;
        const messageBytes = data.message;
        const accountProof = data.accountProof;
        const storageProof = data.storageProof;

        await protocolState.addSlot(slot, data.stateRoot, 1, data.stateRoot);
        await protocolState.setHead(slot);

        const tx_with_bytes = await reciever.executeMessage(slot, messageBytes, accountProof, storageProof);

        await expect(tx_with_bytes).to.emit(reciever, "ExecutedMessage");
    });
});