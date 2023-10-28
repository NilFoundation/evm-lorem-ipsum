const { expect } = require("chai");
const { ethers } = require("hardhat");
const { deployments } = require("hardhat");
const fs = require('fs');
const { getVerifierParams } = require("./utils.js");

describe('Proof Validation Tests', function () {
    let ethereumLightClient, accounts;

    before(async function () {
        accounts = await ethers.getSigners();
        await deployments.fixture(['verifierAndGatesFixture']);
        const placeholderVerifier = await ethers.getContract('PlaceholderVerifier');
        const unifiedAdditionGate = await ethers.getContract('UnifiedAdditionGate');
        const settings = JSON.parse(fs.readFileSync('./test/data/deploy.json', 'utf-8'));
        const EthereumLightClient = await ethers.getContractFactory("EthereumLightClient");

        ethereumLightClient = await EthereumLightClient.deploy(
            placeholderVerifier.address,
            unifiedAdditionGate.address,
            settings.zkLightClients[0].deploy.rotate,
            settings.zkLightClients[0].deploy.genesisValidatorsRoot,
            settings.zkLightClients[0].deploy.genesisTime,
            settings.zkLightClients[0].deploy.secondsPerSlot,
            settings.zkLightClients[0].deploy.slotsPerPeriod,
            // settings.zkLightClients[0].deploy.syncCommitteePeriod,
            123,
            settings.zkLightClients[0].deploy.syncCommitteePoseidon,
            settings.zkLightClients[0].deploy.sourceChainId,
            settings.zkLightClients[0].deploy.finalityThreshold
        );
        await ethereumLightClient.deployed();
    });

    describe('Unified Addition Proof Verification', function () {
        const configPath = "./data/unified_addition/lambda2.json";
        const proofPath = "./data/unified_addition/lambda2.data";
        const publicInputPath = "./data/unified_addition/public_input.json";
        const params = getVerifierParams(configPath, proofPath, publicInputPath);

        it("Should verify a correct proof", async function () {
            const update = {
                attestedSlot: 123 * 16,
                finalizedSlot: 456,
                participation: 789,
                finalizedHeaderRoot: '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
                executionStateRoot: '0xfedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
                proof: params.proof,
                init_params: params.init_params,
                columns_rotations: params.columns_rotations,
            };
            
            const tx = await ethereumLightClient.connect(accounts[0]).step(update);
            await tx.wait();
            await expect(tx).to.emit(ethereumLightClient, 'HeadUpdate');
        });

        it("Should reject an incorrect proof", async function () {
            let update = {
                attestedSlot: 123 * 16,
                finalizedSlot: 456,
                participation: 789,
                finalizedHeaderRoot: '0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
                executionStateRoot: '0xfedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210',
                proof: params.proof,
                init_params: params.init_params,
                columns_rotations: params.columns_rotations,
            };

            update.proof = update.proof.slice(0, -1) + '0';
            await expect(ethereumLightClient.connect(accounts[0]).step(update))
                .to.be.revertedWith("Step proof verification failed");
        });
    });
});
