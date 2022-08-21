// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IMetadataModule } from "@core/interfaces/IMetadataModule.sol";

interface ISoundEditionEventsAndErrors {
    event MetadataModuleSet(IMetadataModule metadataModule);
    event BaseURISet(string baseURI);
    event ContractURISet(string contractURI);
    event MetadataFrozen(IMetadataModule metadataModule, string baseURI, string contractURI);
    event FundingRecipientSet(address fundingRecipient);
    event RoyaltySet(uint16 royaltyBPS);
    event EditionMaxMintableSet(uint32 newMax);

    error MetadataIsFrozen();
    error InvalidRoyaltyBPS();
    error InvalidRandomnessLock();
    error Unauthorized();
    error EditionMaxMintableReached();
    error InvalidAmount();
    error InvalidFundingRecipient();
    error MaximumHasAlreadyBeenReached();
}
