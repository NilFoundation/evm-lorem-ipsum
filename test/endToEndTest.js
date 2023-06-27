const Hardhat = require("hardhat");
const { ethers, upgrades } = require("hardhat");
const { expect } = require("chai");



describe('End2end tests', function () {

  describe('Full end2end - Success', function () {
    
    it("Begin", async function () {

      let [signer1] = await Hardhat.ethers.getSigners();
      const source_chain_id = Hardhat.network.config.chainId;
      const target_chain_id = source_chain_id;
      const magicNumberForEthLightClientProofSystem = 0xAABBCCDD;
      const testSlot = 0x45;


      /* ======================= DEPLOY ROUTER ======================= */
      /*
        Router settings are not important for now
      */
      const Router = await ethers.getContractFactory("LoremIpsumRouter");
      const router = await upgrades.deployProxy(Router, [
        [1], // _sourceChainIds -- array of source chain IDs
        [signer1.address], // _lightClients -- array of addresses to lightClients
        [signer1.address], // _broadcasters -- array of addresses to broadcasters
        signer1.address, // _timelock -- address of timelock owner
        signer1.address, // _guardian -- address of guardian owner
        true // _sendingEnabled
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

      /* ======================= DEPLOY eth light client ======================= */
      const EthereumLightClient = await ethers.getContractFactory("MockEthereumLightClient");
      const ethereumLightClient = await EthereumLightClient.deploy();
      await ethereumLightClient.deployed();
      
      /* ======================= DEPLOY custom response ======================= */
      const CustomResponseHandler = await ethers.getContractFactory("MockResponseHandler");
      const customResponseHandler = await CustomResponseHandler.deploy();
      await customResponseHandler.deployed();
      
      /* ======================= DEPLOY custom request handler ======================= */
      const CustomRequestHandler = await ethers.getContractFactory("MockRequestHandler");
      const customRequestHandler = await CustomRequestHandler.deploy(ethereumLightClient.address);
      await customRequestHandler.deployed();
      
      /* ======================= DEPLOY eth light client handler ======================= */
      const EthereumLightClientHandler = await ethers.getContractFactory("MockEthereumLightClientHandler");
      const ethereumLightClientHandler = await EthereumLightClientHandler.deploy();
      await ethereumLightClientHandler.deployed();

      /* ======================= Set Oracle ======================= */
      await transitionManager.setOracle(oracle.address);

      /* ======================= Set proof Handler ======================= */
      await transitionManager.setVerifierHandler(source_chain_id, magicNumberForEthLightClientProofSystem, ethereumLightClientHandler.address);

      /* ======================= Set Resonse Handler ======================= */
      await oracle.setCustomResponseHandler(source_chain_id, customRequestHandler.address, customResponseHandler.address);

      let test_light_client_state = await ethereumLightClient.makeTestState(testSlot);

      /* ======================= Send cross request ======================= */
      let utf8Encode = new TextEncoder();
      let response = await oracle.commitRequest (
        target_chain_id, // _destinationChainId
        customRequestHandler.address, // _targetContract
        test_light_client_state, // _targetData
        0, // _nonce -- if 0 - autoincrement
        utf8Encode.encode("someStrongZKProof"), // Proof
        magicNumberForEthLightClientProofSystem // _proofsRequestType
        )

        /* read send request event logs*/
        logs_out = await response.wait()
        events = logs_out.events
        
        /*
          If executeMessage fails -- revert will be raised
          If execution is not aborted -- update of the internal state of 
          light client successful 
        */
        await router.executeMessage(
          Uint8Array.from(Buffer.from(events[0].data.slice(2), 'hex')).slice(64), 
          transitionManager.address)
        
    });
  })
});