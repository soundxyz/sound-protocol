import ids from "./json/interfaceIds.json";
import staging from "./json/staging.json";
import preview from "./json/preview.json";

const contractAddresses = {
    staging,
    preview,
};

// Need to do this so the typescript declaration file is generated correctly.
const interfaceIds = { ...ids };

export { interfaceIds, contractAddresses };
