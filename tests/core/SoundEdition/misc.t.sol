// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { IAccessControlEnumerableUpgradeable } from "openzeppelin-upgradeable/access/IAccessControlEnumerableUpgradeable.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";

import { IMetadataModule } from "@core/interfaces/IMetadataModule.sol";

import { TestConfig } from "../../TestConfig.sol";

/**
 * @dev Miscellaneous tests for SoundEdition
 */
contract SoundEdition_misc is TestConfig {
    event SoundEditionInitialized(
        address indexed edition_,
        string name_,
        string symbol_,
        address metadataModule_,
        string baseURI_,
        string contractURI_,
        address fundingRecipient_,
        uint16 royaltyBPS_,
        uint32 editionMaxMintableLower_,
        uint32 editionMaxMintableUpper_,
        uint32 editionCutoffTime_,
        uint8 flags_
    );

    function test_createSoundEmitsEvent() public {
        vm.expectEmit(true, true, true, true);

        (address soundEditionAddress, ) = soundCreator.soundEditionAddress(address(this), bytes32(_salt + 1));

        emit SoundEditionInitialized(
            soundEditionAddress,
            SONG_NAME,
            SONG_SYMBOL,
            METADATA_MODULE,
            BASE_URI,
            CONTRACT_URI,
            FUNDING_RECIPIENT,
            ROYALTY_BPS,
            EDITION_MAX_MINTABLE,
            EDITION_MAX_MINTABLE,
            EDITION_CUTOFF_TIME,
            FLAGS
        );

        SoundEditionV1(
            createSound(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                FUNDING_RECIPIENT,
                ROYALTY_BPS,
                EDITION_MAX_MINTABLE,
                EDITION_MAX_MINTABLE,
                EDITION_CUTOFF_TIME,
                FLAGS
            )
        );
    }

    function test_supportsInterface() public {
        SoundEditionV1 edition = createGenericEdition();
        bool supportsEditionIface = edition.supportsInterface(type(ISoundEditionV1).interfaceId);
        assertTrue(supportsEditionIface);
        bool supports165 = edition.supportsInterface(type(IERC165).interfaceId);
        assertTrue(supports165);
    }
}
