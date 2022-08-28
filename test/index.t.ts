import { expect } from "chai";
import hre from "hardhat";

// sanity check for hardhat's artifacts folder (compiled solidity)

describe("SoundCreatorV1", function () {
    it("Should deploy creator", async function () {
        const SoundCreatorV1 = await hre.ethers.getContractFactory("SoundCreatorV1");
        const impAddr = "0x0000000000000000000000000000000000000001";
        const soundCreator = await SoundCreatorV1.deploy();
        await soundCreator.initialize(impAddr);

        const soundEditionImplementation = await soundCreator.soundEditionImplementation();

        expect(soundEditionImplementation).to.equal(impAddr);
    });
});
