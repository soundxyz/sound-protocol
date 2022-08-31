// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { Test } from "forge-std/Test.sol";
import { ERC1967Proxy } from "openzeppelin/proxy/ERC1967/ERC1967Proxy.sol";

import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundFeeRegistryV1 } from "@core/SoundFeeRegistryV1.sol";
import { IMetadataModule } from "@core/interfaces/IMetadataModule.sol";
import { MockSoundEditionV1 } from "./mocks/MockSoundEditionV1.sol";

contract TestConfig is Test {
    // Artist contract creation vars
    string constant SONG_NAME = "Never Gonna Give You Up";
    string constant SONG_SYMBOL = "NEVER";
    IMetadataModule constant METADATA_MODULE = IMetadataModule(address(390720730));
    string constant BASE_URI = "https://example.com/metadata/";
    string constant CONTRACT_URI = "https://example.com/storefront/";
    address constant FUNDING_RECIPIENT = address(99);
    uint16 constant ROYALTY_BPS = 100;
    address public constant ARTIST_ADMIN = address(8888888888);
    uint32 constant EDITION_MAX_MINTABLE = type(uint32).max;
    uint32 constant RANDOMNESS_LOCKED_TIMESTAMP = 200;
    address constant SOUND_FEE_ADDRESS = address(2222222222);
    uint16 constant PLATFORM_FEE_BPS = 200;
    uint256 constant MAX_BPS = 10_000;

    SoundCreatorV1 soundCreator;
    SoundFeeRegistryV1 feeRegistry;

    // Set up called before each test
    function setUp() public virtual {
        // Deploy implementations
        SoundFeeRegistryV1 feeRegistryImp = new SoundFeeRegistryV1();
        SoundCreatorV1 soundCreatorImp = new SoundCreatorV1();
        MockSoundEditionV1 editionImplementation = new MockSoundEditionV1();

        // Deploy & initialize registry proxy
        ERC1967Proxy registryProxy = new ERC1967Proxy(address(feeRegistryImp), bytes(""));
        feeRegistry = SoundFeeRegistryV1(address(registryProxy));
        feeRegistry.initialize(SOUND_FEE_ADDRESS, PLATFORM_FEE_BPS);

        // Deploy & initialize creator proxy
        ERC1967Proxy creatorProxy = new ERC1967Proxy(address(soundCreatorImp), bytes(""));
        soundCreator = SoundCreatorV1(address(creatorProxy));
        soundCreator.initialize(address(editionImplementation));
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

    function createGenericEdition() public returns (SoundEditionV1) {
        return
            SoundEditionV1(
                soundCreator.createSound(
                    SONG_NAME,
                    SONG_SYMBOL,
                    METADATA_MODULE,
                    BASE_URI,
                    CONTRACT_URI,
                    FUNDING_RECIPIENT,
                    ROYALTY_BPS,
                    EDITION_MAX_MINTABLE,
                    EDITION_MAX_MINTABLE,
                    RANDOMNESS_LOCKED_TIMESTAMP
                )
            );
    }
}
