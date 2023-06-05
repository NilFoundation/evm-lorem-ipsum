const Hardhat = require("hardhat");
const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");



describe("End to end test", function () {

  it("Begin", async function () {
    const source_chain_id = 0x64;
    const target_chain_id = 0x64;
    let [signer1] = await Hardhat.ethers.getSigners();
    signer_address = await signer1.getAddress();

    /* ======================= DEPLOY ROUTER ======================= */
    /*
      Router settings are not important for now
    */
    const Router = await ethers.getContractFactory("LoremIpsumRouter");
    const router = await upgrades.deployProxy(Router, [
      [1],
      [signer1.address],
      [signer1.address],
      signer1.address ,
      signer1.address ,
      true
    ], {
        unsafeAllow: ["constructor"]
    })
    await router.deployed();

    /* ======================= DEPLOY Transition manager ======================= */
    const TransitionManager = await ethers.getContractFactory("LoremIpsumTransitionsManager");
    const transitionManager = await TransitionManager.deploy(router.address);
    await transitionManager.deployed();

    /* ======================= DEPLOY Oracle ======================= */
    const Oracle = await ethers.getContractFactory("LoremIpsumOracle");
    const oracle = await Oracle.deploy(source_chain_id, transitionManager.address);
    await oracle.deployed();

    /* ======================= DEPLOY custom response ======================= */
    const CustomResponseHandler = await ethers.getContractFactory("MockResponseHandler");
    const customResponseHandler = await CustomResponseHandler.deploy();
    await customResponseHandler.deployed();
    
    /* ======================= DEPLOY custom request handler ======================= */
    const CustomRequestHandler = await ethers.getContractFactory("MockRequestHandler");
    const customRequestHandler = await CustomRequestHandler.deploy();
    await customRequestHandler.deployed();

    /* ======================= Set Oracle ======================= */
    await transitionManager.setOracle(oracle.address);

    /* ======================= Set Resonse Handler ======================= */
    await oracle.setCustomResponseHandler(source_chain_id, customRequestHandler.address, customResponseHandler.address);


    /* ======================= Send cross request ======================= */
    let response = await oracle.commitRequest(
      target_chain_id, // _destinationChainId
      customRequestHandler.address, // _targetContract
      [], // _targetData
      0x31224, // _nonce
      3 // _proofsRequest -> 0b11
      )

        /* read send request event logs*/
      logs_out = await response.wait()
      events = logs_out.events
      // some specific magic to "clean" data
      new_out = await router.executeMessage(
        Uint8Array.from(Buffer.from(events[0].data.slice(2), 'hex')).slice(64), 
        transitionManager.address)
      
      response_logs = await new_out.wait()
      // Final check
      expect(byteArrayToInteger(Buffer.from(response_logs.events[0].data.slice(2), 'hex'))).to.equal(0x12345);
  });

  function byteArrayToInteger(byteArray) {
    var result = 0;
    
    for (var i = 0; i < byteArray.length; i++) {
      result = (result << 8) + byteArray[i];
    }
    
    return result;
  }
});