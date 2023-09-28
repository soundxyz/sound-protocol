pragma solidity ^0.8.16;

import { IERC721AUpgradeable, ISoundEditionV2, SoundEditionV2 } from "@core/SoundEditionV2.sol";
import { ISoundMetadata, SoundMetadata } from "@modules/SoundMetadata.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { LibString } from "solady/utils/LibString.sol";
import "../TestConfigV2.sol";

contract SoundMetadataTests is TestConfigV2 {
    using LibString for *;

    SoundEditionV2 edition;
    SoundMetadata soundMetadata;

    uint32 DEFAULT_NUMBER_UP_TO;

    function setUp() public virtual override {
        super.setUp();
        soundMetadata = new SoundMetadata();
        ISoundEditionV2.EditionInitialization memory init = genericEditionInitialization();
        init.tierCreations = new ISoundEditionV2.TierCreation[](3);
        init.tierCreations[0].tier = 0;
        init.tierCreations[1].tier = 1;
        init.tierCreations[1].maxMintableLower = _tierMaxMintable(1);
        init.tierCreations[1].maxMintableUpper = _tierMaxMintable(1);
        init.tierCreations[1].mintRandomnessEnabled = true;
        init.tierCreations[2].tier = 2;
        init.tierCreations[2].maxMintableLower = _tierMaxMintable(2);
        init.tierCreations[2].maxMintableUpper = _tierMaxMintable(2);
        init.tierCreations[2].mintRandomnessEnabled = true;
        init.metadataModule = address(soundMetadata);
        edition = createSoundEdition(init);
        DEFAULT_NUMBER_UP_TO = soundMetadata.DEFAULT_NUMBER_UP_TO();
    }

    function test_defaultMetadataConfig() public {
        assertEq(soundMetadata.useTierTokenIdIndex(address(edition)), true);
        assertEq(soundMetadata.numberedUpTo(address(edition)), DEFAULT_NUMBER_UP_TO);
        for (uint256 tier; tier < 3; ++tier) {
            assertEq(soundMetadata.baseURI(address(edition), uint8(tier)), "");
        }
    }

    function test_setAndGetMetadataConfig(uint256) public {
        for (uint256 q; q != 5; ++q) {
            bool useTierTokenIdIndex = _random() % 2 == 0;
            soundMetadata.setUseTierTokenIdIndex(address(edition), useTierTokenIdIndex);
            assertEq(soundMetadata.useTierTokenIdIndex(address(edition)), useTierTokenIdIndex);

            uint32 upTo = uint32(_bound(_random(), 0, DEFAULT_NUMBER_UP_TO * 2));
            uint32 expectedUpTo = upTo == 0 ? DEFAULT_NUMBER_UP_TO : upTo;
            soundMetadata.setNumberedUpTo(address(edition), upTo);
            assertEq(soundMetadata.numberedUpTo(address(edition)), expectedUpTo);

            uint8 tier = uint8(_random() % 3);
            string memory baseURI = _randomBaseURI();
            soundMetadata.setBaseURI(address(edition), tier, baseURI);
            assertEq(soundMetadata.baseURI(address(edition), tier), baseURI);
        }
    }

    function _randomBaseURI() internal returns (string memory s) {
        uint256 r = _random() % 3;
        if (r == 0) {
            s = "ar://".concat(string(Base64.encode(abi.encode(1 | _random()), true, true))).concat("/");
        } else if (r == 1) {
            s = _random().toString().concat("...");
        }
    }

    function _tierMaxMintable(uint8 tier) internal pure returns (uint32) {
        if (tier == 1) return 5;
        if (tier == 2) return 10;
        return type(uint32).max;
    }

    function test_metadataWithBaseURIOverride(uint256) public {
        uint8 tier = uint8(1 + (_random() % 2));
        string memory baseURI = _randomBaseURI();
        soundMetadata.setBaseURI(address(edition), tier, baseURI);

        _mintTierWithSpacing(tier, _tierMaxMintable(tier));
        uint256 goldenEggTokenId = soundMetadata.goldenEggTokenId(address(edition), tier);
        assertTrue(goldenEggTokenId != 0);

        uint256[] memory tierTokenIds = edition.tierTokenIds(tier);
        assertEq(tierTokenIds.length, _tierMaxMintable(tier));
        uint256 nonGoldenEggTokenId;
        uint256 index;
        do {
            index = _random() % tierTokenIds.length;
            nonGoldenEggTokenId = tierTokenIds[index];
        } while (nonGoldenEggTokenId == goldenEggTokenId);

        if (bytes(baseURI).length != 0) {
            assertEq(edition.tokenURI(goldenEggTokenId), baseURI.concat("goldenEgg"));
            assertEq(edition.tokenURI(nonGoldenEggTokenId), baseURI.concat((index + 1).toString()));
            if (_random() % 2 == 0) {
                soundMetadata.setUseTierTokenIdIndex(address(edition), false);
                assertEq(edition.tokenURI(nonGoldenEggTokenId), baseURI.concat(nonGoldenEggTokenId.toString()));
            }
            if (_random() % 2 == 0) {
                soundMetadata.setUseTierTokenIdIndex(address(edition), true);
                assertEq(edition.tokenURI(nonGoldenEggTokenId), baseURI.concat((index + 1).toString()));
            }
        } else {
            assertEq(edition.tokenURI(goldenEggTokenId), "");
            assertEq(edition.tokenURI(nonGoldenEggTokenId), "");
            string memory editionBaseURI = _randomBaseURI();
            edition.setBaseURI(editionBaseURI);
            if (bytes(editionBaseURI).length != 0) {
                assertEq(
                    edition.tokenURI(goldenEggTokenId),
                    editionBaseURI.concat("goldenEgg").concat("_").concat(tier.toString())
                );
                assertEq(
                    edition.tokenURI(nonGoldenEggTokenId),
                    editionBaseURI.concat((index + 1).toString()).concat("_").concat(tier.toString())
                );
                if (_random() % 2 == 0) {
                    soundMetadata.setUseTierTokenIdIndex(address(edition), false);
                    assertEq(
                        edition.tokenURI(nonGoldenEggTokenId),
                        editionBaseURI.concat(nonGoldenEggTokenId.toString()).concat("_").concat(tier.toString())
                    );
                }
                if (_random() % 2 == 0) {
                    soundMetadata.setUseTierTokenIdIndex(address(edition), true);
                    assertEq(
                        edition.tokenURI(nonGoldenEggTokenId),
                        editionBaseURI.concat((index + 1).toString()).concat("_").concat(tier.toString())
                    );
                }
                if (_random() % 2 == 0 && index > 0 && tierTokenIds[index] != goldenEggTokenId) {
                    soundMetadata.setNumberedUpTo(address(edition), uint32(index));
                    assertEq(
                        edition.tokenURI(nonGoldenEggTokenId),
                        editionBaseURI.concat("0_").concat(tier.toString())
                    );
                    soundMetadata.setUseTierTokenIdIndex(address(edition), false);
                    soundMetadata.setNumberedUpTo(address(edition), uint32(nonGoldenEggTokenId));
                    assertEq(
                        edition.tokenURI(nonGoldenEggTokenId),
                        editionBaseURI.concat(nonGoldenEggTokenId.toString()).concat("_").concat(tier.toString())
                    );
                    soundMetadata.setUseTierTokenIdIndex(address(edition), false);
                    soundMetadata.setNumberedUpTo(address(edition), uint32(nonGoldenEggTokenId - 1));
                    assertEq(
                        edition.tokenURI(nonGoldenEggTokenId),
                        editionBaseURI.concat("0_").concat(tier.toString())
                    );
                    soundMetadata.setUseTierTokenIdIndex(address(edition), true);
                    soundMetadata.setNumberedUpTo(address(edition), uint32(index + 1));
                    assertEq(
                        edition.tokenURI(nonGoldenEggTokenId),
                        editionBaseURI.concat((index + 1).toString()).concat("_").concat(tier.toString())
                    );
                }
            } else {
                assertEq(edition.tokenURI(goldenEggTokenId), "");
                assertEq(edition.tokenURI(nonGoldenEggTokenId), "");
            }
        }
    }

    function _mintTierWithSpacing(uint8 tier, uint256 n) internal {
        uint256 remainder = n;
        while (remainder != 0) {
            if (_random() % 2 == 0) {
                uint256 q = _bound(_random(), 1, remainder);
                edition.mint(tier, address(this), q);
                remainder -= q;
            } else {
                edition.mint(0, address(this), 1 + (_random() % 3));
            }
        }
    }
}
