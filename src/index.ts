import ids from "./json/interfaceIds.json";
import staging from "./json/staging.json";
import preview from "./json/preview.json";

// TODO: figure out how we can generate this file. Importing the JSON
// is not ideal because typescript just shows them as `string`. We need
// interfaceIds as constants for the SDK to know which minter to select from.

const contractAddresses = {
    staging,
    preview,
} as const;

const interfaceIds = {
    ISoundEditionV1: "0x183e0a77",
    IMinterModule: "0x37c74bd8",
    IFixedPriceSignatureMinter: "0x110099e0",
    IMerkleDropMinter: "0x84b6980c",
    IRangeEditionMinter: "0xc73d6ffa",
} as const;

export { interfaceIds, contractAddresses };
