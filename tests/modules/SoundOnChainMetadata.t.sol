pragma solidity ^0.8.16;

import { IERC721AUpgradeable, ISoundEditionV2, SoundEditionV2 } from "@core/SoundEditionV2.sol";
import { ISoundOnChainMetadata, SoundOnChainMetadata } from "@modules/SoundOnChainMetadata.sol";
import { LibZip } from "solady/utils/LibZip.sol";
import { Base64 } from "solady/utils/Base64.sol";
import { LibString } from "solady/utils/LibString.sol";
import { DynamicBufferLib } from "solady/utils/DynamicBufferLib.sol";
import { JSONParserLib } from "solady/utils/JSONParserLib.sol";
import "../TestConfigV2.sol";

contract SoundOnChainMetadataTests is TestConfigV2 {
    using JSONParserLib for JSONParserLib.Item;
    using DynamicBufferLib for DynamicBufferLib.DynamicBuffer;

    event LogString(string s);

    SoundEditionV2 edition;
    SoundOnChainMetadata mm; // Short for metadata module.

    function setUp() public virtual override {
        super.setUp();
        mm = new SoundOnChainMetadata();
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
        init.metadataModule = address(mm);
        edition = createSoundEdition(init);
    }

    function test_createAndGetTemplate(string memory t) public {
        vm.assume(bytes(t).length < 0xfffe);
        string memory templateId = mm.createTemplate(t);
        assertEq(mm.getTemplate(templateId), t);
    }

    function test_createAndGetTemplate() public {
        test_createAndGetTemplate("Lorem Ipsum");
    }

    function test_tokenURI() public {
        string memory baseTemplateId = mm.createTemplate('{"name":[[["title"]," #",["sn"]," (",["id"],")"]]}');
        string memory tier2TemplateId = mm.createTemplate('{"name":[[["title"]," - Tier 2"]]}');
        string memory goldenEggTemplateId = mm.createTemplate('{"name":[[["title"]," - Golden Egg"]]}');
        DynamicBufferLib.DynamicBuffer memory buffer;
        buffer.p("{");
        buffer.p('"b":{"t":"', bytes(baseTemplateId), '","v":{"title":"HEHE"}},');
        buffer.p('"2":{"t":"', bytes(tier2TemplateId), '","v":{"title":"T2"}},');
        buffer.p('"g":{"t":"', bytes(goldenEggTemplateId), '"}');
        buffer.p("}");
        mm.setValues(address(edition), string(buffer.data));

        _mintTierWithSpacing(1, _tierMaxMintable(1));

        string memory result;
        result = mm.rawTokenJSON(address(edition), 111, 3, 1, true);
        assertEq(result, '{"name":"HEHE - Golden Egg"}');
        result = mm.rawTokenJSON(address(edition), 111, 3, 1, false);
        assertEq(result, '{"name":"HEHE #3 (111)"}');
        result = mm.rawTokenJSON(address(edition), 111, 3, 2, false);
        assertEq(result, '{"name":"T2 - Tier 2"}');

        uint256 tier1GoldenEggId = edition.mintRandomnessOneOfOne(1);
        assertTrue(tier1GoldenEggId != 0);
        result = edition.tokenURI(tier1GoldenEggId);
        result = string(Base64.decode(LibString.slice(result, 29)));
        assertEq(result, '{"name":"HEHE - Golden Egg"}');

        uint256[] memory tierTokenIds = edition.tierTokenIds(1);
        for (uint256 i; i != tierTokenIds.length; ++i) {
            if (tierTokenIds[i] == tier1GoldenEggId) continue;
            result = edition.tokenURI(tierTokenIds[i]);
            result = string(Base64.decode(LibString.slice(result, 29)));
            buffer.clear();
            buffer.p('{"name":"HEHE #', bytes(LibString.toString(i + 1)));
            buffer.p(" (", bytes(LibString.toString(tierTokenIds[i])), ')"}');
            assertEq(result, string(buffer.data));
        }
    }

    function test_setValuesCompresset() public {
        string
            memory valuesString = '{"0":{"values":{"artworkURI":"tier0ArtworkURI"}},"1":{"values":{"artworkURI":"tier1ArtworkURI"}},"base":{"template":23467,"values":{"animationURI":"","artist":"Daniel Allan","artworkMime":"image/gif","artworkURI":"ar://J5NZ-e2NUcQj1OuuhpTjAKtdW_nqwnwo5FypF_a6dE4","description":"Criteria is an 8-track project between Daniel Allan and Reo Cragun.\n\nA fusion of electronic music and hip-hop - Criteria brings together the best of both worlds and is meant to bring web3 music to a wider audience.\n\nThe collection consists of 2500 editions with activations across Sound, Bonfire, OnCyber, Spinamp and Arpeggi.","duration":105,"genre":"Pop","losslessAudio":"","mime":"audio/wave","title":"Criteria","trackNumber":1,"version":"sound-edition-20220930"}},"goldenEgg":{"template":1112,"values":{"artworkURI":"goldenEggArtworkURI"}}}';
        bytes memory valuesStringCompressed = LibZip.flzCompress(bytes(valuesString));
        mm.setValuesCompressed(address(edition), valuesStringCompressed);
        assertEq(mm.getValues(address(edition)), valuesString);
        mm.setValues(address(edition), valuesString);
        assertEq(mm.getValues(address(edition)), valuesString);
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

    function _tierMaxMintable(uint8 tier) internal pure returns (uint32) {
        if (tier == 1) return 5;
        if (tier == 2) return 10;
        return type(uint32).max;
    }

    function test_base64IsValidJSONString(bytes9 b) public {
        string memory s = Base64.encode(abi.encodePacked(b));
        assertEq(JSONParserLib.decodeString(LibString.escapeJSON(s, true)), s);
    }
}
