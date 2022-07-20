// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "../TestConfig.sol";
import "../mocks/MockMetadataModule.sol";

contract SoundNft_metadata is TestConfig {
    event MetadataFrozen(
        IMetadataModule _metadataModule,
        string baseURI_,
        string _contractURI
    );
    event BaseURISet(string baseURI_);
    event ContractURISet(string _contractURI);
    event MetadataModuleSet(IMetadataModule _metadataModule);

    error URIQueryForNonexistentToken();
    error MetadataIsFrozen();

    // Generates tokenURI using baseURI if no metadata module is selected
    function test_baseURIWhenNoMetadataModule() public {
        // deploy new sound contract
        MockSoundNftV1 soundNft = MockSoundNftV1(
            soundCreator.createSoundNft(
                SONG_NAME,
                SONG_SYMBOL,
                IMetadataModule(address(0)),
                BASE_URI,
                CONTRACT_URI
            )
        );

        // mint NFTs
        soundNft.mint(2);
        uint256 tokenId = 1;

        string memory expectedTokenURI = string.concat(
            BASE_URI,
            _toString(tokenId)
        );
        assertEq(soundNft.tokenURI(tokenId), expectedTokenURI);
    }

    // Should successfully return contract URI for the collection
    function test_contractURI() public {
        // deploy new sound contract
        MockSoundNftV1 soundNft = MockSoundNftV1(
            soundCreator.createSoundNft(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI
            )
        );

        assertEq(soundNft.contractURI(), CONTRACT_URI);
    }

    // Generate tokenURI using the metadata module
    function test_metadataModule() public {
        MockMetadataModule metadataModule = new MockMetadataModule();

        // deploy new sound contract
        MockSoundNftV1 soundNft = MockSoundNftV1(
            soundCreator.createSoundNft(
                SONG_NAME,
                SONG_SYMBOL,
                metadataModule,
                BASE_URI,
                CONTRACT_URI
            )
        );

        // mint NFTs
        soundNft.mint(2);
        uint256 tokenId = 1;

        string memory expectedTokenURI = "MOCK";
        assertEq(soundNft.tokenURI(tokenId), expectedTokenURI);
    }

    function test_tokenURIRevertsWhenTokenIdDoesntExist() public {
        // deploy new sound contract
        MockSoundNftV1 soundNft = MockSoundNftV1(
            soundCreator.createSoundNft(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI
            )
        );

        vm.expectRevert(URIQueryForNonexistentToken.selector);
        soundNft.tokenURI(2);
    }

    function test_setBaseURIRevertsForNonOwner() public {
        // deploy new sound contract
        MockSoundNftV1 soundNft = MockSoundNftV1(
            soundCreator.createSoundNft(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI
            )
        );

        string memory newBaseURI = "https://abc.com/";

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        soundNft.setBaseURI(newBaseURI);
    }

    function test_setBaseURIRevertsWhenMetadataFrozen() public {
        // deploy new sound contract
        MockSoundNftV1 soundNft = MockSoundNftV1(
            soundCreator.createSoundNft(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI
            )
        );
        // Freeze Metadata
        soundNft.freezeMetadata();

        string memory newBaseURI = "https://abc.com/";

        vm.expectRevert(MetadataIsFrozen.selector);
        soundNft.setBaseURI(newBaseURI);
    }

    function test_setBaseURISuccess() public {
        // deploy new sound contract
        MockSoundNftV1 soundNft = MockSoundNftV1(
            soundCreator.createSoundNft(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI
            )
        );
        // mint NFTs
        soundNft.mint(2);
        uint256 tokenId = 1;

        string memory newBaseURI = "https://abc.com/";
        soundNft.setBaseURI(newBaseURI);

        string memory expectedTokenURI = string.concat(
            newBaseURI,
            _toString(tokenId)
        );
        assertEq(soundNft.tokenURI(tokenId), expectedTokenURI);
    }

    function test_setBaseURIEmitsEvent() public {
        // deploy new sound contract
        MockSoundNftV1 soundNft = MockSoundNftV1(
            soundCreator.createSoundNft(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI
            )
        );

        string memory newBaseURI = "https://abc.com/";

        vm.expectEmit(false, false, false, true);
        emit BaseURISet(newBaseURI);
        soundNft.setBaseURI(newBaseURI);
    }

    function test_setContractURIRevertsForNonOwner() public {
        // deploy new sound contract
        MockSoundNftV1 soundNft = MockSoundNftV1(
            soundCreator.createSoundNft(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI
            )
        );

        string memory newContractURI = "https://abc.com/";

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        soundNft.setContractURI(newContractURI);
    }

    function test_setContractURIRevertsWhenMetadataFrozen() public {
        // deploy new sound contract
        MockSoundNftV1 soundNft = MockSoundNftV1(
            soundCreator.createSoundNft(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI
            )
        );
        // Freeze Metadata
        soundNft.freezeMetadata();

        string memory newContractURI = "https://abc.com/";

        vm.expectRevert(MetadataIsFrozen.selector);
        soundNft.setContractURI(newContractURI);
    }

    function test_setContractURISuccess() public {
        // deploy new sound contract
        MockSoundNftV1 soundNft = MockSoundNftV1(
            soundCreator.createSoundNft(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI
            )
        );

        string memory newContractURI = "https://abc.com/";
        soundNft.setContractURI(newContractURI);

        assertEq(soundNft.contractURI(), newContractURI);
    }

    function test_setContractURIEmitsEvent() public {
        // deploy new sound contract
        MockSoundNftV1 soundNft = MockSoundNftV1(
            soundCreator.createSoundNft(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI
            )
        );

        string memory newContractURI = "https://abc.com/";

        vm.expectEmit(false, false, false, true);
        emit ContractURISet(newContractURI);
        soundNft.setContractURI(newContractURI);
    }

    function test_setMetadataModuleRevertsForNonOwner() public {
        // deploy new sound contract
        MockSoundNftV1 soundNft = MockSoundNftV1(
            soundCreator.createSoundNft(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI
            )
        );

        MockMetadataModule newMetadataModule = new MockMetadataModule();

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        soundNft.setMetadataModule(newMetadataModule);
    }

    function test_setMetadataModuleRevertsWhenMetadataFrozen() public {
        // deploy new sound contract
        MockSoundNftV1 soundNft = MockSoundNftV1(
            soundCreator.createSoundNft(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI
            )
        );
        // Freeze Metadata
        soundNft.freezeMetadata();

        MockMetadataModule newMetadataModule = new MockMetadataModule();

        vm.expectRevert(MetadataIsFrozen.selector);
        soundNft.setMetadataModule(newMetadataModule);
    }

    function test_setMetadataModuleSuccess() public {
        // deploy new sound contract
        MockSoundNftV1 soundNft = MockSoundNftV1(
            soundCreator.createSoundNft(
                SONG_NAME,
                SONG_SYMBOL,
                IMetadataModule(address(0)),
                BASE_URI,
                CONTRACT_URI
            )
        );
        // mint NFTs
        soundNft.mint(2);
        uint256 tokenId = 1;

        MockMetadataModule newMetadataModule = new MockMetadataModule();
        soundNft.setMetadataModule(newMetadataModule);

        string memory expectedTokenURI = "MOCK";
        assertEq(soundNft.tokenURI(tokenId), expectedTokenURI);
    }

    function test_setMetadataModuleEmitsEvent() public {
        // deploy new sound contract
        MockSoundNftV1 soundNft = MockSoundNftV1(
            soundCreator.createSoundNft(
                SONG_NAME,
                SONG_SYMBOL,
                IMetadataModule(address(0)),
                BASE_URI,
                CONTRACT_URI
            )
        );

        MockMetadataModule newMetadataModule = new MockMetadataModule();

        vm.expectEmit(false, false, false, true);
        emit MetadataModuleSet(newMetadataModule);
        soundNft.setMetadataModule(newMetadataModule);
    }

    function test_freezeMetadataRevertsForNonOwner() public {
        // deploy new sound contract
        MockSoundNftV1 soundNft = MockSoundNftV1(
            soundCreator.createSoundNft(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI
            )
        );

        address caller = getRandomAccount(1);
        vm.prank(caller);
        vm.expectRevert("Ownable: caller is not the owner");
        soundNft.freezeMetadata();
    }

    function test_freezeMetadataRevertsIfAlreadyFrozen() public {
        // deploy new sound contract
        MockSoundNftV1 soundNft = MockSoundNftV1(
            soundCreator.createSoundNft(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI
            )
        );
        soundNft.freezeMetadata();

        vm.expectRevert(MetadataIsFrozen.selector);
        soundNft.freezeMetadata();
    }

    function test_freezeMetadataSuccess() public {
        // deploy new sound contract
        MockSoundNftV1 soundNft = MockSoundNftV1(
            soundCreator.createSoundNft(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI
            )
        );

        soundNft.freezeMetadata();

        assertEq(soundNft.isMetadataFrozen(), true);
    }

    function test_freezeMetadataEmitsEvent() public {
        // deploy new sound contract
        MockSoundNftV1 soundNft = MockSoundNftV1(
            soundCreator.createSoundNft(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI
            )
        );

        vm.expectEmit(false, false, false, true);
        emit MetadataFrozen(METADATA_MODULE, BASE_URI, CONTRACT_URI);
        soundNft.freezeMetadata();
    }
}
