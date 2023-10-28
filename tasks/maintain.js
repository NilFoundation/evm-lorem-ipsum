const fs = require('fs');
const { getVerifierParams } = require("../test/utils.js");
const { expect } = require("chai");
const { task } = require("hardhat/config");
const losslessJSON = require('lossless-json');

function bigintReviver(key, value) {
    if (value && value.isLosslessNumber) {
      return BigInt(value.value);
    }
    return value;
  }

task("deployLightClient", "Deploys the EthereumLightClient contract")
    .setAction(async (taskArgs, {ethers}) => {
        const jsonString = fs.readFileSync('test/data/deploy.json', 'utf-8');
        const settings = JSON.parse(jsonString);

        console.log("Deploying EthereumLightClient...");
        const EthereumLightClient = await ethers.getContractFactory("EthereumLightClient");
        const ethereumLightClient = await EthereumLightClient.deploy(
            settings.zkLightClients[0].deploy.placeholderVerifier,
            settings.zkLightClients[0].deploy.step,
            // "0xe7f1725e7734ce288f8367e1bb143e90bb3f0512",
            // "0x9fe46736679d2d9a65f0992f2272de9f3c7fa6e0",
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

        const jsonString = fs.readFileSync('test/data/update.json', 'utf-8');
        update = losslessJSON.parse(jsonString, bigintReviver);

        // Spoil the proof
        // update.proof = update.proof.slice(0, -1) + '0';

        // Call the step function
        const tx = await ethereumLightClient.connect(accounts[0]).step(update);
        await tx.wait();
        await expect(tx).to.emit(ethereumLightClient, 'HeadUpdate');
        console.log("Step function called successfully");
    });
