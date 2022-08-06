// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "openzeppelin/utils/Strings.sol";

import "../TestConfig.sol";
import "../mocks/MockMetadataModule.sol";

contract SoundEdition_metadata is TestConfig {
    event MetadataFrozen(IMetadataModule _metadataModule, string baseURI_, string _contractURI);
    event BaseURISet(string baseURI_);
    event ContractURISet(string _contractURI);
    event MetadataModuleSet(IMetadataModule _metadataModule);

    error URIQueryForNonexistentToken();
    error MetadataIsFrozen();

    function _createEdition() internal returns (MockSoundEditionV1 soundEdition) {
        // deploy new sound contract
        soundEdition = MockSoundEditionV1(
            soundCreator.createSound(
                SONG_NAME,
                SONG_SYMBOL,
                IMetadataModule(address(0)),
                BASE_URI,
                CONTRACT_URI,
                MAX_MINTABLE
            )
        );
    }

    function _createEditionWithMetadata() internal returns (MockSoundEditionV1 soundEdition) {
        MockMetadataModule metadataModule = new MockMetadataModule();

        // deploy new sound contract
        soundEdition = MockSoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, metadataModule, BASE_URI, CONTRACT_URI, MAX_MINTABLE)
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
        MockSoundEditionV1 soundEdition = _createEditionWithMetadata();

        // mint NFTs
        soundEdition.mint(2);
        uint256 tokenId = 1;

        string memory expectedTokenURI = "MOCK";
        assertEq(soundEdition.tokenURI(tokenId), expectedTokenURI);
    }

    function test_tokenURIRevertsWhenTokenIdDoesntExist() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        vm.expectRevert(URIQueryForNonexistentToken.selector);
        soundEdition.tokenURI(2);
    }

    // ================================
    // setBaseURI()
    // ================================

    function test_setBaseURIRevertsForNonOwner() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        string memory newBaseURI = "https://abc.com/";

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        soundEdition.setBaseURI(newBaseURI);
    }

    function test_setBaseURIRevertsWhenMetadataFrozen() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        // Freeze Metadata
        soundEdition.freezeMetadata();

        string memory newBaseURI = "https://abc.com/";

        vm.expectRevert(MetadataIsFrozen.selector);
        soundEdition.setBaseURI(newBaseURI);
    }

    function test_setBaseURISuccess() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        // mint NFTs
        soundEdition.mint(2);
        uint256 tokenId = 1;

        string memory newBaseURI = "https://abc.com/";
        soundEdition.setBaseURI(newBaseURI);

        string memory expectedTokenURI = string.concat(newBaseURI, Strings.toString(tokenId));
        assertEq(soundEdition.tokenURI(tokenId), expectedTokenURI);
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

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        soundEdition.setContractURI(newContractURI);
    }

    function test_setContractURIRevertsWhenMetadataFrozen() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        // Freeze Metadata
        soundEdition.freezeMetadata();

        string memory newContractURI = "https://abc.com/";

        vm.expectRevert(MetadataIsFrozen.selector);
        soundEdition.setContractURI(newContractURI);
    }

    function test_setContractURISuccess() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        string memory newContractURI = "https://abc.com/";
        soundEdition.setContractURI(newContractURI);

        assertEq(soundEdition.contractURI(), newContractURI);
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

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        soundEdition.setMetadataModule(newMetadataModule);
    }

    function test_setMetadataModuleRevertsWhenMetadataFrozen() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        // Freeze Metadata
        soundEdition.freezeMetadata();

        MockMetadataModule newMetadataModule = new MockMetadataModule();

        vm.expectRevert(MetadataIsFrozen.selector);
        soundEdition.setMetadataModule(newMetadataModule);
    }

    function test_setMetadataModuleSuccess() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        // mint NFTs
        soundEdition.mint(2);
        uint256 tokenId = 1;

        MockMetadataModule newMetadataModule = new MockMetadataModule();
        soundEdition.setMetadataModule(newMetadataModule);

        string memory expectedTokenURI = "MOCK";

        assertEq(soundEdition.tokenURI(tokenId), expectedTokenURI);
    }

    function test_setMetadataModuleEmitsEvent() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        MockMetadataModule newMetadataModule = new MockMetadataModule();

        vm.expectEmit(false, false, false, true);
        emit MetadataModuleSet(newMetadataModule);
        soundEdition.setMetadataModule(newMetadataModule);
    }

    // ================================
    // freezeMetadata()
    // ================================

    function test_freezeMetadataRevertsForNonOwner() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        soundEdition.freezeMetadata();
    }

    function test_freezeMetadataRevertsIfAlreadyFrozen() public {
        MockSoundEditionV1 soundEdition = _createEdition();
        soundEdition.freezeMetadata();

        vm.expectRevert(MetadataIsFrozen.selector);
        soundEdition.freezeMetadata();
    }

    function test_freezeMetadataSuccess() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        soundEdition.freezeMetadata();

        assertEq(soundEdition.isMetadataFrozen(), true);
    }

    function test_freezeMetadataEmitsEvent() public {
        MockSoundEditionV1 soundEdition = _createEdition();

        vm.expectEmit(false, false, false, true);
        emit MetadataFrozen(METADATA_MODULE, BASE_URI, CONTRACT_URI);
        soundEdition.freezeMetadata();
    }
}
