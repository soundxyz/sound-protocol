// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { Test } from "forge-std/Test.sol";

import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundFeeRegistry } from "@core/SoundFeeRegistry.sol";
import { IMetadataModule } from "@core/interfaces/IMetadataModule.sol";
import { MockSoundEditionV1 } from "./mocks/MockSoundEditionV1.sol";

contract TestConfig is Test {
    // From ISoundEditionVI.
    uint8 public constant METADATA_IS_FROZEN_FLAG = 1 << 0;
    uint8 public constant MINT_RANDOMNESS_ENABLED_FLAG = 1 << 1;

    // Artist contract creation vars
    string constant SONG_NAME = "Never Gonna Give You Up";
    string constant SONG_SYMBOL = "NEVER";
    address constant METADATA_MODULE = address(390720730);
    string constant BASE_URI = "https://example.com/metadata/";
    string constant CONTRACT_URI = "https://example.com/storefront/";
    address constant FUNDING_RECIPIENT = address(99);
    uint16 constant ROYALTY_BPS = 100;
    address public constant ARTIST_ADMIN = address(8888888888);
    uint32 constant EDITION_MAX_MINTABLE = type(uint32).max;
    uint32 constant EDITION_CUTOFF_TIME = 200;
    uint8 constant FLAGS = MINT_RANDOMNESS_ENABLED_FLAG;
    address constant SOUND_FEE_ADDRESS = address(2222222222);
    uint16 constant PLATFORM_FEE_BPS = 200;
    uint256 constant MAX_BPS = 10_000;

    uint256 internal _salt;

    SoundCreatorV1 soundCreator;
    SoundFeeRegistry feeRegistry;

    // Set up called before each test
    function setUp() public virtual {
        feeRegistry = new SoundFeeRegistry(SOUND_FEE_ADDRESS, PLATFORM_FEE_BPS);

        // Deploy SoundEdition implementation
        MockSoundEditionV1 soundEditionImplementation = new MockSoundEditionV1();

        soundCreator = new SoundCreatorV1(address(soundEditionImplementation));
    }

    /**
     * @dev Returns an address funded with ETH
     * @param num Number used to generate the address (more convenient than passing address(num))
     */
    function getFundedAccount(uint256 num) public returns (address) {
        address addr = vm.addr(num);
        // Fund with some ETH
        vm.deal(addr, 1e19);

        return addr;
    }

    function createSound(
        string memory name,
        string memory symbol,
        address metadataModule,
        string memory baseURI,
        string memory contractURI,
        address fundingRecipient,
        uint16 royaltyBPS,
        uint32 editionMaxMintableLower,
        uint32 editionMaxMintableUpper,
        uint32 editionClosingTime,
        uint8 flags
    ) public returns (address) {
        bytes memory initData = abi.encodeWithSelector(
            SoundEditionV1.initialize.selector,
            name,
            symbol,
            metadataModule,
            baseURI,
            contractURI,
            fundingRecipient,
            royaltyBPS,
            editionMaxMintableLower,
            editionMaxMintableUpper,
            editionClosingTime,
            flags
        );

        address[] memory contracts;
        bytes[] memory data;

        soundCreator.createSoundAndMints(bytes32(++_salt), initData, contracts, data);
        (address addr, ) = soundCreator.soundEditionAddress(address(this), bytes32(_salt));
        return payable(addr);
    }

    function createGenericEdition() public returns (SoundEditionV1) {
        return
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
}
