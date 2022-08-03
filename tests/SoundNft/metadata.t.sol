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

    // Generates tokenURI using baseURI if no metadata module is selected
    function test_baseURIWhenNoMetadataModule() public {
        // deploy new sound contract
        MockSoundEditionV1 soundEdition = MockSoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, IMetadataModule(address(0)), BASE_URI, CONTRACT_URI)
        );

        // mint NFTs
        soundEdition.mint(2);
        uint256 tokenId = 1;

        string memory expectedTokenURI = string.concat(BASE_URI, Strings.toString(tokenId));
        assertEq(soundEdition.tokenURI(tokenId), expectedTokenURI);
    }

    // Should successfully return contract URI for the collection
    function test_contractURI() public {
        // deploy new sound contract
        MockSoundEditionV1 soundEdition = MockSoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        assertEq(soundEdition.contractURI(), CONTRACT_URI);
    }

    // Generate tokenURI using the metadata module
    function test_metadataModule() public {
        MockMetadataModule metadataModule = new MockMetadataModule();

        // deploy new sound contract
        MockSoundEditionV1 soundEdition = MockSoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, metadataModule, BASE_URI, CONTRACT_URI)
        );

        // mint NFTs
        soundEdition.mint(2);
        uint256 tokenId = 1;

        string memory expectedTokenURI = "MOCK";
        assertEq(soundEdition.tokenURI(tokenId), expectedTokenURI);
    }

    function test_tokenURIRevertsWhenTokenIdDoesntExist() public {
        // deploy new sound contract
        MockSoundEditionV1 soundEdition = MockSoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        vm.expectRevert(URIQueryForNonexistentToken.selector);
        soundEdition.tokenURI(2);
    }

    function test_setBaseURIRevertsForNonOwner() public {
        // deploy new sound contract
        MockSoundEditionV1 soundEdition = MockSoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        string memory newBaseURI = "https://abc.com/";

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        soundEdition.setBaseURI(newBaseURI);
    }

    function test_setBaseURIRevertsWhenMetadataFrozen() public {
        // deploy new sound contract
        MockSoundEditionV1 soundEdition = MockSoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );
        // Freeze Metadata
        soundEdition.freezeMetadata();

        string memory newBaseURI = "https://abc.com/";

        vm.expectRevert(MetadataIsFrozen.selector);
        soundEdition.setBaseURI(newBaseURI);
    }

    function test_setBaseURISuccess() public {
        // deploy new sound contract
        MockSoundEditionV1 soundEdition = MockSoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );
        // mint NFTs
        soundEdition.mint(2);
        uint256 tokenId = 1;

        string memory newBaseURI = "https://abc.com/";
        soundEdition.setBaseURI(newBaseURI);

        string memory expectedTokenURI = string.concat(newBaseURI, Strings.toString(tokenId));
        assertEq(soundEdition.tokenURI(tokenId), expectedTokenURI);
    }

    function test_setBaseURIEmitsEvent() public {
        // deploy new sound contract
        MockSoundEditionV1 soundEdition = MockSoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        string memory newBaseURI = "https://abc.com/";

        vm.expectEmit(false, false, false, true);
        emit BaseURISet(newBaseURI);
        soundEdition.setBaseURI(newBaseURI);
    }

    function test_setContractURIRevertsForNonOwner() public {
        // deploy new sound contract
        MockSoundEditionV1 soundEdition = MockSoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        string memory newContractURI = "https://abc.com/";

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        soundEdition.setContractURI(newContractURI);
    }

    function test_setContractURIRevertsWhenMetadataFrozen() public {
        // deploy new sound contract
        MockSoundEditionV1 soundEdition = MockSoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );
        // Freeze Metadata
        soundEdition.freezeMetadata();

        string memory newContractURI = "https://abc.com/";

        vm.expectRevert(MetadataIsFrozen.selector);
        soundEdition.setContractURI(newContractURI);
    }

    function test_setContractURISuccess() public {
        // deploy new sound contract
        MockSoundEditionV1 soundEdition = MockSoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        string memory newContractURI = "https://abc.com/";
        soundEdition.setContractURI(newContractURI);

        assertEq(soundEdition.contractURI(), newContractURI);
    }

    function test_setContractURIEmitsEvent() public {
        // deploy new sound contract
        MockSoundEditionV1 soundEdition = MockSoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        string memory newContractURI = "https://abc.com/";

        vm.expectEmit(false, false, false, true);
        emit ContractURISet(newContractURI);
        soundEdition.setContractURI(newContractURI);
    }

    function test_setMetadataModuleRevertsForNonOwner() public {
        // deploy new sound contract
        MockSoundEditionV1 soundEdition = MockSoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        MockMetadataModule newMetadataModule = new MockMetadataModule();

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        soundEdition.setMetadataModule(newMetadataModule);
    }

    function test_setMetadataModuleRevertsWhenMetadataFrozen() public {
        // deploy new sound contract
        MockSoundEditionV1 soundEdition = MockSoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );
        // Freeze Metadata
        soundEdition.freezeMetadata();

        MockMetadataModule newMetadataModule = new MockMetadataModule();

        vm.expectRevert(MetadataIsFrozen.selector);
        soundEdition.setMetadataModule(newMetadataModule);
    }

    function test_setMetadataModuleSuccess() public {
        // deploy new sound contract
        MockSoundEditionV1 soundEdition = MockSoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, IMetadataModule(address(0)), BASE_URI, CONTRACT_URI)
        );
        // mint NFTs
        soundEdition.mint(2);
        uint256 tokenId = 1;

        MockMetadataModule newMetadataModule = new MockMetadataModule();
        soundEdition.setMetadataModule(newMetadataModule);

        string memory expectedTokenURI = "MOCK";

        assertEq(soundEdition.tokenURI(tokenId), expectedTokenURI);
    }

    function test_setMetadataModuleEmitsEvent() public {
        // deploy new sound contract
        MockSoundEditionV1 soundEdition = MockSoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, IMetadataModule(address(0)), BASE_URI, CONTRACT_URI)
        );

        MockMetadataModule newMetadataModule = new MockMetadataModule();

        vm.expectEmit(false, false, false, true);
        emit MetadataModuleSet(newMetadataModule);
        soundEdition.setMetadataModule(newMetadataModule);
    }

    function test_freezeMetadataRevertsForNonOwner() public {
        // deploy new sound contract
        MockSoundEditionV1 soundEdition = MockSoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        soundEdition.freezeMetadata();
    }

    function test_freezeMetadataRevertsIfAlreadyFrozen() public {
        // deploy new sound contract
        MockSoundEditionV1 soundEdition = MockSoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );
        soundEdition.freezeMetadata();

        vm.expectRevert(MetadataIsFrozen.selector);
        soundEdition.freezeMetadata();
    }

    function test_freezeMetadataSuccess() public {
        // deploy new sound contract
        MockSoundEditionV1 soundEdition = MockSoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        soundEdition.freezeMetadata();

        assertEq(soundEdition.isMetadataFrozen(), true);
    }

    function test_freezeMetadataEmitsEvent() public {
        // deploy new sound contract
        MockSoundEditionV1 soundEdition = MockSoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI)
        );

        vm.expectEmit(false, false, false, true);
        emit MetadataFrozen(METADATA_MODULE, BASE_URI, CONTRACT_URI);
        soundEdition.freezeMetadata();
    }
}
