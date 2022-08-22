// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { IERC721AUpgradeable } from "chiru-labs/ERC721A-Upgradeable/IERC721AUpgradeable.sol";
import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { SoundCreatorV1 } from "@core/SoundCreatorV1.sol";
import { TestConfig } from "../TestConfig.sol";
import { MockMinter } from "../mocks/MockMinter.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";

contract MintControllerBaseTests is TestConfig {
    event MintConfigCreated(
        address indexed edition,
        address indexed creator,
        uint256 mintId,
        uint32 startTime,
        uint32 endTime
    );

    MockMinter public minter;

    uint32 constant START_TIME = 0;
    uint32 constant END_TIME = type(uint32).max;

    constructor() {
        minter = new MockMinter();
    }

    function _createEdition(uint32 editionMaxMintable) internal returns (SoundEditionV1 edition) {
        edition = SoundEditionV1(
            soundCreator.createSound(
                SONG_NAME,
                SONG_SYMBOL,
                METADATA_MODULE,
                BASE_URI,
                CONTRACT_URI,
                FUNDING_RECIPIENT,
                ROYALTY_BPS,
                editionMaxMintable,
                editionMaxMintable,
                RANDOMNESS_LOCKED_TIMESTAMP
            )
        );

        edition.grantRole(edition.MINTER_ROLE(), address(minter));
    }

    function test_createEditionMintRevertsIfCallerNotEditionOwnerOrAdmin() external {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);
        address attacker = getFundedAccount(1);

        vm.expectRevert(IMinterModule.Unauthorized.selector);
        vm.prank(attacker);
        minter.createEditionMint(address(edition), START_TIME, END_TIME);
    }

    function test_createEditionMintViaOwner() external {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint256 mintId = 0;

        address owner = address(this);

        vm.expectEmit(false, false, false, true);
        emit MintConfigCreated(address(edition), owner, mintId, START_TIME, END_TIME);

        minter.createEditionMint(address(edition), START_TIME, END_TIME);
    }

    function test_createEditionMintViaAdmin() external {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint256 mintId = 0;
        address admin = address(1037037);

        edition.grantRole(edition.ADMIN_ROLE(), admin);

        vm.expectEmit(false, false, false, true);
        emit MintConfigCreated(address(edition), admin, mintId, START_TIME, END_TIME);

        vm.prank(admin);
        minter.createEditionMint(address(edition), START_TIME, END_TIME);
    }

    function test_mintRevertsForWrongEtherValue() public {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);

        uint256 price = 1;
        vm.expectRevert(abi.encodeWithSelector(IMinterModule.WrongEtherValue.selector, price * 2 - 1, price * 2));
        minter.mint{ value: price * 2 - 1 }(address(edition), mintId, 2, price);

        minter.mint{ value: price * 2 }(address(edition), mintId, 2, price);
    }

    function test_mintRevertsWhenPaused() public {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);

        minter.setEditionMintPaused(address(edition), mintId, true);

        uint256 price = 1;
        vm.expectRevert(IMinterModule.MintPaused.selector);

        minter.mint{ value: price * 2 }(address(edition), mintId, 2, price);

        minter.setEditionMintPaused(address(edition), mintId, false);

        minter.mint{ value: price * 2 }(address(edition), mintId, 2, price);
    }

    function test_mintRevertsWithZeroQuantity() public {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);

        vm.expectRevert(IERC721AUpgradeable.MintZeroQuantity.selector);

        minter.mint{ value: 0 }(address(edition), mintId, 0, 0);
    }

    function test_createEditionMintMultipleTimes() external {
        SoundEditionV1 edition = _createEdition(EDITION_MAX_MINTABLE);

        for (uint256 i; i < 3; ++i) {
            uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);
            assertEq(mintId, i);
        }
    }

    function test_cantMintPastEditionMaxMintable() external {
        uint32 maxSupply = 5000;
        SoundEditionV1 edition1 = _createEdition(maxSupply);

        uint256 mintId1 = minter.createEditionMint(address(edition1), START_TIME, END_TIME);

        // Mint all of the supply except for 1 token
        minter.mint(address(edition1), mintId1, maxSupply - 1, 0);

        // try minting 2 more - should fail and tell us there is only 1 available
        vm.expectRevert(abi.encodeWithSelector(ISoundEditionEventsAndErrors.ExceedsEditionAvailableSupply.selector, 1));
        minter.mint(address(edition1), mintId1, 2, 0);

        // try minting 1 more - should succeed
        minter.mint(address(edition1), mintId1, 1, 0);
    }

    function test_setTimeRange(address nonController) public {
        vm.assume(nonController != address(this));

        SoundEditionV1 edition = _createEdition(1);

        uint256 mintId = minter.createEditionMint(address(edition), START_TIME, END_TIME);

        MockMinter.BaseData memory baseData = minter.baseMintData(address(edition), mintId);

        // Check initial values are correct
        assertEq(baseData.startTime, 0);
        assertEq(baseData.endTime, type(uint32).max);

        // Set new values
        minter.setTimeRange(address(edition), mintId, 123, 456);

        baseData = minter.baseMintData(address(edition), mintId);

        // Check new values
        assertEq(baseData.startTime, 123);
        assertEq(baseData.endTime, 456);

        // Ensure only controller can set time range
        vm.prank(nonController);
        vm.expectRevert(IMinterModule.Unauthorized.selector);
        minter.setTimeRange(address(edition), mintId, 456, 789);
    }
}
