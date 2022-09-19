// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { Strings } from "openzeppelin/utils/Strings.sol";
import { IERC721AUpgradeable } from "chiru-labs/ERC721A-Upgradeable/IERC721AUpgradeable.sol";
import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { IMetadataModule } from "@core/interfaces/IMetadataModule.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { MockSoundEditionV1 } from "../../mocks/MockSoundEditionV1.sol";
import { MockMetadataModule } from "../../mocks/MockMetadataModule.sol";
import { TestConfig } from "../../TestConfig.sol";

contract SoundEdition_metadata is TestConfig {
    event MetadataFrozen(IMetadataModule _metadataModule, string baseURI_, string _contractURI);
    event BaseURISet(string baseURI_);
    event ContractURISet(string _contractURI);
    event MetadataModuleSet(address _metadataModule);

    function _createEdition() internal returns (MockSoundEditionV1 soundEdition) {
        // deploy new sound contract
        soundEdition = MockSoundEditionV1(
            createSound(
                SONG_NAME,
                SONG_SYMBOL,
                address(0),
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

    function _createEditionWithMetadata()
        internal
        returns (MockSoundEditionV1 soundEdition, MockMetadataModule metadataModule)
    {
        metadataModule = new MockMetadataModule();

        // deploy new sound contract
        soundEdition = MockSoundEditionV1(
            createSound(
                SONG_NAME,
                SONG_SYMBOL,
                address(metadataModule),
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

    // Generates tokenURI using baseURI if no metadata module is selected
    function test_baseURIWhenNoMetadataModule() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        // mint NFTs
        soundEdition.mint(2);
        uint256 tokenId = 1;

        string memory expectedTokenURI = string.concat(BASE_URI, Strings.toString(tokenId));
        assertEq(soundEdition.tokenURI(tokenId), expectedTokenURI);
    }

    // Should successfully return contract URI for the collection
    function test_contractURI() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        assertEq(soundEdition.contractURI(), CONTRACT_URI);
    }

    // Generate tokenURI using the metadata module
    function test_metadataModule() public {
        (MockSoundEditionV1 soundEdition, ) = _createEditionWithMetadata();

        // mint NFTs
        soundEdition.mint(2);
        uint256 tokenId = 1;

        string memory expectedTokenURI = "MOCK";
        assertEq(soundEdition.tokenURI(tokenId), expectedTokenURI);
    }

    function test_tokenURIRevertsWhenTokenIdDoesntExist() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        vm.expectRevert(IERC721AUpgradeable.URIQueryForNonexistentToken.selector);
        soundEdition.tokenURI(2);
    }

    // ================================
    // setBaseURI()
    // ================================

    function test_setBaseURIRevertsForNonOwner() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        string memory newBaseURI = "https://abc.com/";

        address caller = getFundedAccount(1);
        vm.prank(caller);
        vm.expectRevert(OwnableRoles.Unauthorized.selector);
        soundEdition.setBaseURI(newBaseURI);
    }

    function test_setBaseURIRevertsWhenMetadataFrozen() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        // Freeze Metadata
        soundEdition.freezeMetadata();

        string memory newBaseURI = "https://abc.com/";

        vm.expectRevert(ISoundEditionV1.MetadataIsFrozen.selector);
        soundEdition.setBaseURI(newBaseURI);
    }

    function test_setBaseURISuccess() public {
        string memory newBaseURI = "https://abc.com/";
        uint256 tokenId = 1;
        string memory expectedTokenURI = string.concat(newBaseURI, Strings.toString(tokenId));

        /**
         * Test owner can set base URI
         */
        MockSoundEditionV1 soundEdition1 = _createEdition();

        soundEdition1.mint(2);
        soundEdition1.setBaseURI(newBaseURI);

        assertEq(soundEdition1.tokenURI(tokenId), expectedTokenURI);

        /**
         * Test admin can set base URI
         */
        MockSoundEditionV1 soundEdition2 = _createEdition();

        soundEdition2.grantRoles(ARTIST_ADMIN, soundEdition2.ADMIN_ROLE());
        soundEdition2.mint(2);

        vm.prank(ARTIST_ADMIN);
        soundEdition2.setBaseURI(newBaseURI);

        assertEq(soundEdition2.tokenURI(tokenId), expectedTokenURI);
    }

    function test_setBaseURIEmitsEvent() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        string memory newBaseURI = "https://abc.com/";

        vm.expectEmit(false, false, false, true);
        emit BaseURISet(newBaseURI);
        soundEdition.setBaseURI(newBaseURI);
    }

    // ================================
    // setContractURI()
    // ================================

    function test_setContractURIRevertsForNonOwner() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        string memory newContractURI = "https://abc.com/";

        address caller = getFundedAccount(1);
        vm.prank(caller);
        vm.expectRevert(OwnableRoles.Unauthorized.selector);
        soundEdition.setContractURI(newContractURI);
    }

    function test_setContractURIRevertsWhenMetadataFrozen() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        // Freeze Metadata
        soundEdition.freezeMetadata();

        string memory newContractURI = "https://abc.com/";

        vm.expectRevert(ISoundEditionV1.MetadataIsFrozen.selector);
        soundEdition.setContractURI(newContractURI);
    }

    function test_setContractURISuccess() public {
        string memory newContractURI = "https://abc.com/";

        /**
         * Test owner can set contract URI
         */
        MockSoundEditionV1 soundEdition1 = _createEdition();

        soundEdition1.setContractURI(newContractURI);

        assertEq(soundEdition1.contractURI(), newContractURI);

        /**
         * Test admin can set contract URI
         */
        MockSoundEditionV1 soundEdition2 = _createEdition();

        soundEdition2.grantRoles(ARTIST_ADMIN, soundEdition2.ADMIN_ROLE());

        vm.prank(ARTIST_ADMIN);
        soundEdition2.setContractURI(newContractURI);

        assertEq(soundEdition2.contractURI(), newContractURI);
    }

    function test_setContractURIEmitsEvent() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        string memory newContractURI = "https://abc.com/";

        vm.expectEmit(false, false, false, true);
        emit ContractURISet(newContractURI);
        soundEdition.setContractURI(newContractURI);
    }

    // ================================
    // setMetadataModule()
    // ================================

    function test_setMetadataModuleRevertsForNonOwner() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        MockMetadataModule newMetadataModule = new MockMetadataModule();

        address caller = getFundedAccount(1);
        vm.prank(caller);
        vm.expectRevert(OwnableRoles.Unauthorized.selector);
        soundEdition.setMetadataModule(address(newMetadataModule));
    }

    function test_setMetadataModuleRevertsWhenMetadataFrozen() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        // Freeze Metadata
        soundEdition.freezeMetadata();

        MockMetadataModule newMetadataModule = new MockMetadataModule();

        vm.expectRevert(ISoundEditionV1.MetadataIsFrozen.selector);
        soundEdition.setMetadataModule(address(newMetadataModule));
    }

    function test_setMetadataModuleSuccess() public {
        string memory expectedTokenURI = "MOCK";
        uint256 tokenId = 1;

        /**
         * Test owner can set metadata module
         */
        MockSoundEditionV1 soundEdition1 = _createEdition();

        // mint NFTs
        soundEdition1.mint(2);

        MockMetadataModule newMetadataModule = new MockMetadataModule();
        soundEdition1.setMetadataModule(address(newMetadataModule));

        assertEq(soundEdition1.tokenURI(tokenId), expectedTokenURI);

        /**
         * Test admin can set metadata module
         */
        MockSoundEditionV1 soundEdition2 = _createEdition();

        soundEdition2.grantRoles(ARTIST_ADMIN, soundEdition2.ADMIN_ROLE());

        soundEdition2.mint(2);

        vm.prank(ARTIST_ADMIN);
        soundEdition2.setMetadataModule(address(newMetadataModule));

        assertEq(soundEdition2.tokenURI(tokenId), expectedTokenURI);
    }

    function test_setMetadataModuleEmitsEvent() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        MockMetadataModule newMetadataModule = new MockMetadataModule();

        vm.expectEmit(false, false, false, true);
        emit MetadataModuleSet(address(newMetadataModule));
        soundEdition.setMetadataModule(address(newMetadataModule));
    }

    // ================================
    // freezeMetadata()
    // ================================

    function test_freezeMetadataRevertsForNonOwner() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        address caller = getFundedAccount(1);
        vm.prank(caller);
        vm.expectRevert(OwnableRoles.Unauthorized.selector);
        soundEdition.freezeMetadata();
    }

    function test_freezeMetadataRevertsIfAlreadyFrozen() public {
        MockSoundEditionV1 soundEdition = _createEdition();
        soundEdition.freezeMetadata();

        vm.expectRevert(ISoundEditionV1.MetadataIsFrozen.selector);
        soundEdition.freezeMetadata();
    }

    function test_freezeMetadataSuccess() public {
        /**
         * Test owner can freeze metadata
         */
        MockSoundEditionV1 soundEdition1 = _createEdition();

        soundEdition1.freezeMetadata();

        assertEq(soundEdition1.isMetadataFrozen(), true);

        /**
         * Test admin can freeze metadata
         */
        MockSoundEditionV1 soundEdition2 = _createEdition();

        soundEdition2.grantRoles(ARTIST_ADMIN, soundEdition2.ADMIN_ROLE());

        vm.prank(ARTIST_ADMIN);
        soundEdition2.freezeMetadata();

        assertEq(soundEdition2.isMetadataFrozen(), true);
    }

    function test_freezeMetadataEmitsEvent() public {
        (MockSoundEditionV1 soundEdition, IMetadataModule metadataModule) = _createEditionWithMetadata();

        vm.expectEmit(false, false, false, true);
        emit MetadataFrozen(metadataModule, BASE_URI, CONTRACT_URI);
        soundEdition.freezeMetadata();
    }
}
