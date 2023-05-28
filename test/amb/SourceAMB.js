const Hardhat = require("hardhat");
const { expect } = require("chai");

describe("SendMessage", function () {
    let addr1;
    let sourceAMB;

    beforeEach(async function () {
        [addr1] = await Hardhat.ethers.getSigners();

        const SourceAMB = await Hardhat.ethers.getContractFactory("MockSourceAMB");
        sourceAMB = await SourceAMB.deploy(true);
        await sourceAMB.deployed();
        sender = await Hardhat.ethers.getContractAt("ILoremIpsumSender", sourceAMB.address);
  });

  it("Should emit SentMessage for send", async function () {
        // uint32 destinationChainId, bytes32 destinationAddress, bytes calldata data
        let destinationChainId = 20;
        let data = 0x0000000;
        let destinationAddress = await addr1.getAddress();
        let destinationAddressAsBytes = Hardhat.ethers.utils.defaultAbiCoder.encode(["address"], [destinationAddress]);

        const tx_with_addr = await sender["send(uint32,address,bytes)"](destinationChainId, destinationAddress, data, {gasLimit: 30_500_000});
        await expect(tx_with_addr).to.emit(sourceAMB, "SentMessage");

        const tx_with_bytes = await sender["send(uint32,bytes32,bytes)"](destinationChainId, destinationAddressAsBytes, data, {gasLimit: 30_500_000});
        await expect(tx_with_bytes).to.emit(sender, "SentMessage");

        expect(sender.nonce == 2)
  });
});