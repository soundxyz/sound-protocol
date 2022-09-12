import staging from "./json/staging.json";
import preview from "./json/preview.json";
import { interfaceIds } from "./interfaceIds";

const contractAddresses = {
    staging,
    preview,
} as const;

export { interfaceIds, contractAddresses };
