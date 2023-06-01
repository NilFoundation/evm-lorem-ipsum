const Hardhat = require("hardhat");
const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");



describe("LoremIpsumRouter", function () {

    beforeEach(async function () {


  });
  
  it("Should emit SentMessage for send", async function () {
    let [signer1] = await Hardhat.ethers.getSigners();

    const Router = await ethers.getContractFactory("LoremIpsumRouter");
    const router = await upgrades.deployProxy(Router, [
    [33],
   [signer1.address],
   [signer1.address],
    signer1.address,
    signer1.address,
    true

    ], {
        unsafeAllow: ["constructor"]
    })
    await router.deployed();

    let a = await router["send(uint32,address,bytes)"](33, router.address, router.address, {gasLimit: 30_500_000});
    console.log(await a.wait())
  });
});