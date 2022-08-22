// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IMetadataModule } from "@core/interfaces/IMetadataModule.sol";

interface ISoundEditionAdminActions {
    /**
     *  @dev Sets metadata module
     */
    function setMetadataModule(IMetadataModule metadataModule) external;

    /**
     *  @dev Sets global base URI
     */
    function setBaseURI(string memory baseURI) external;

    /**
     *   @dev Sets contract URI
     */
    function setContractURI(string memory contractURI) external;

    /**
     *   @dev Freezes metadata by preventing any more changes to base URI
     */
    function freezeMetadata() external;

    /**
     * @dev Sets funding recipient address
     */
    function setFundingRecipient(address fundingRecipient) external;

    /**
     * @dev Sets royalty amount in bps (basis points)
     */
    function setRoyalty(uint16 royaltyBPS) external;

    /**
     *   @dev Reduces the maximum mintable quantity.
     */
    function reduceEditionMaxMintable(uint32 newMax) external;

    /**
     * @dev sets randomnessLockedAfterMinted in case of insufficient sales, to finalize goldenEgg
     */
    function setMintRandomnessLock(uint32 randomnessLockedAfterMinted) external;

    /**
     * @dev sets randomnessLockedTimestamp
     */
    function setRandomnessLockedTimestamp(uint32 randomnessLockedTimestamp_) external;
}
