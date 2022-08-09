// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import "openzeppelin/utils/Strings.sol";

import "../TestConfig.sol";
import "../../contracts/modules/Minters/FixedPricePublicSaleMinter.sol";

contract SoundEdition_masterMaxMintable is TestConfig {
    uint256 constant PRICE = 1;

    uint32 constant START_TIME = 0;

    uint32 constant END_TIME = type(uint32).max;

    event MasterMaxMintableLocked(uint32 masterMaxMintable);

    function _createEdition(uint32 maxMintable, uint32 masterMaxMintable)
        internal
        returns (SoundEditionV1 edition, FixedPricePublicSaleMinter minter)
    {
        minter = new FixedPricePublicSaleMinter();

        edition = SoundEditionV1(
            soundCreator.createSound(SONG_NAME, SONG_SYMBOL, METADATA_MODULE, BASE_URI, CONTRACT_URI, masterMaxMintable)
        );

        edition.grantRole(edition.MINTER_ROLE(), address(minter));

        minter.createEditionMint(address(edition), PRICE, START_TIME, END_TIME, maxMintable, type(uint32).max);
    }

    function test_mintAboveMasterMaxMintableOrMaxMintableReverts(
        uint32 maxMintable,
        uint32 masterMaxMintable,
        uint32 quantity
    ) public {
        address caller = getRandomAccount(1);
        maxMintable = (maxMintable % 8) + 1;
        masterMaxMintable = (masterMaxMintable % 8) + 1;
        quantity = (quantity % 8) + 1;

        (SoundEditionV1 edition, FixedPricePublicSaleMinter minter) = _createEdition(maxMintable, masterMaxMintable);

        vm.prank(caller);
        if (masterMaxMintable < maxMintable && quantity > masterMaxMintable && maxMintable >= quantity) {
            vm.expectRevert(abi.encodeWithSelector(SoundEditionV1.OutOfStock.selector, masterMaxMintable));
        } else if (quantity > maxMintable) {
            vm.expectRevert(FixedPricePublicSaleMinter.SoldOut.selector);
        }
        minter.mint{ value: PRICE * quantity }(address(edition), quantity);
    }
}
