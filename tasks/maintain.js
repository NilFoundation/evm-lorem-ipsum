const fs = require('fs');
const { getVerifierParams } = require("../test/utils.js");
const { expect } = require("chai");
const { task } = require("hardhat/config");


task("deployLightClient", "Deploys the EthereumLightClient contract")
    .setAction(async (taskArgs, {ethers}) => {
        const jsonString = fs.readFileSync('test/data/deploy.json', 'utf-8');
        const settings = JSON.parse(jsonString);

        console.log("Deploying EthereumLightClient...");
        const EthereumLightClient = await ethers.getContractFactory("EthereumLightClient");
        const ethereumLightClient = await EthereumLightClient.deploy(
            // settings.zkLightClients[0].deploy.placeholderVerifier,
            // settings.zkLightClients[0].deploy.step,
            "0xe7f1725e7734ce288f8367e1bb143e90bb3f0512",
            "0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0",
            settings.zkLightClients[0].deploy.rotate,
            settings.zkLightClients[0].deploy.genesisValidatorsRoot,
            settings.zkLightClients[0].deploy.genesisTime,
            settings.zkLightClients[0].deploy.secondsPerSlot,
            settings.zkLightClients[0].deploy.slotsPerPeriod,
            settings.zkLightClients[0].deploy.syncCommitteePeriod,
            settings.zkLightClients[0].deploy.syncCommitteePoseidon,
            settings.zkLightClients[0].deploy.sourceChainId,
            settings.zkLightClients[0].deploy.finalityThreshold
        );
        await ethereumLightClient.deployed();
        console.log("EthereumLightClient deployed at:", ethereumLightClient.address);
    });

task("setVerifier", "Sets the step verifier for EthereumLightClient")
    .addParam("clientAddress", "The address of the EthereumLightClient")
    .addParam("verifierAddress", "The address of the verifier")
    .setAction(async (taskArgs, {ethers}) => {
        const ethereumLightClient = await ethers.getContractAt(
            "EthereumLightClient", taskArgs.clientAddress);
        const accounts = await ethers.getSigners();
        
        console.log("Setting verifier...");
        const tx = await ethereumLightClient.connect(accounts[0])
            .setVerifier(taskArgs.verifierAddress);
        await tx.wait();
        
        const verifier = await ethereumLightClient.getVerifier();
        console.log("Verifier set to:", verifier);
    });

task("setGate", "Sets the step gate for EthereumLightClient")
    .addParam("clientAddress", "The address of the EthereumLightClient")
    .addParam("gateAddress", "The address of the gate argument")
    .setAction(async (taskArgs, {ethers}) => {
        const ethereumLightClient = await ethers.getContractAt(
            "EthereumLightClient", taskArgs.clientAddress);
        const accounts = await ethers.getSigners();
        
        console.log("Setting verifier with address:", taskArgs.gateAddress);
        const tx = await ethereumLightClient.connect(accounts[0])
            .setStepGate(taskArgs.gateAddress);
        await tx.wait();

        const gate = await ethereumLightClient.getStepGate();
        console.log("Gate set to:", gate);
    });

task("callStep", "Calls the step function on EthereumLightClient")
    .addParam("clientAddress", "The address of the EthereumLightClient")
    .setAction(async (taskArgs, {ethers}) => {
        const ethereumLightClient = await ethers.getContractAt(
            "EthereumLightClient", taskArgs.clientAddress);
        const accounts = await ethers.getSigners();

        // Get the verifier params
        const configPath = "../test/data/unified_addition/lambda2.json";
        const proofPath = "../test/data/unified_addition/lambda2.data";
        const publicInputPath = "../test/data/unified_addition/public_input.json";
        const params = getVerifierParams(configPath, proofPath, publicInputPath);

        const update = {
            attestedSlot: 256,
            finalizedSlot: 456,
            participation: 789,
            finalizedHeaderRoot: '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
            executionStateRoot: '0xfedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
            proof: params.proof,
            init_params: params.init_params,
            columns_rotations: params.columns_rotations,
        };
        console.log(update.init_params);

        // Call the step function
        const tx = await ethereumLightClient.connect(accounts[0]).step(update);
        await tx.wait();
        await expect(tx).to.emit(ethereumLightClient, 'HeadUpdate');
        // console.log("Step function called successfully");
    });

