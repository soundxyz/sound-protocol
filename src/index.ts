import { interfaceIds } from "./interfaceIds";

const CONTRACT_ADDRESSES = {
    soundFeeRegistry: "0x8f921211c9771baeb648ac7becb322a540298a4b",
    goldenEggMetadata: "0x3ca50e8da8c3d359fc934aea0161f5346ccb62a1",
    fixedPriceSignatureMinter: "0xc8ae7e42e834bc11c906d01726e55571a0620158",
    merkleDropMinter: "0xda4b6fbb85918700e5ee91f6ce3cc2148af02912",
    rangeEditionMinter: "0x4552f8b70a72a8ea1084bf7b7ba50f10f2f9daa7",
    editionMaxMinter: "0x5e5d50ea70c9a1b6ed64506f121b094156b8fd20",
    soundEditionV1: "0x8cfbfae570d673864cd61e1e4543eb7874ca35c2",
    soundCreatorV1: "0xaef3e8c8723d9c31863be8de54df2668ef7c4b89",
} as const;

const contractAddresses = {
    goerli: CONTRACT_ADDRESSES,
    mainnet: CONTRACT_ADDRESSES,
} as const;

export { interfaceIds, contractAddresses };
