// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { EditionMintData } from "@modules/interfaces/IRangeEditionMinter.sol";
import { RangeEditionMinter } from "@modules/RangeEditionMinter.sol";
import { BaseMinter } from "@modules/BaseMinter.sol";
import { RangeEditionMinterTests } from "../modules/RangeEditionMinter.t.sol";
import { InvariantTest } from "./InvariantTest.sol";

contract RangeEditionMinterInvariants is RangeEditionMinterTests, InvariantTest {
    RangeEditionMinterUpdater minterUpdater;
    RangeEditionMinter minter;
    SoundEditionV1 edition;

    function setUp() public override {
        super.setUp();

        edition = createGenericEdition();

        minter = new RangeEditionMinter();

        edition.grantRoles(address(minter), edition.MINTER_ROLE());

        minter.createEditionMint(
            address(edition),
            PRICE,
            START_TIME,
            CLOSING_TIME,
            END_TIME,
            MAX_MINTABLE_LOWER,
            MAX_MINTABLE_UPPER,
            MAX_MINTABLE_PER_ACCOUNT
        );

        minterUpdater = new RangeEditionMinterUpdater(edition, minter);

        addTargetContract(address(minter));
    }

    function invariant_maxMintableRange() public {
        EditionMintData memory data = minter.editionMintData(address(edition), MINT_ID);
        assertTrue(data.maxMintableLower < data.maxMintableUpper);
    }

    function invariant_timeRange() public {
        EditionMintData memory data = minter.editionMintData(address(edition), MINT_ID);
        BaseMinter.BaseData memory baseData = minter.baseMintData(address(edition), MINT_ID);

        uint32 startTime = baseData.startTime;
        uint32 closingTime = data.closingTime;
        uint32 endTime = baseData.endTime;
        assertTrue(startTime < closingTime && closingTime < endTime);
    }
}

contract RangeEditionMinterUpdater {
    uint256 constant MINT_ID = 0;

    SoundEditionV1 edition;
    RangeEditionMinter minter;

    constructor(SoundEditionV1 _edition, RangeEditionMinter _minter) {
        edition = _edition;
        minter = _minter;
    }

    function setTimeRange(
        uint32 startTime,
        uint32 closingTime,
        uint32 endTime
    ) public {
        minter.setTimeRange(address(edition), MINT_ID, startTime, closingTime, endTime);
    }

    function setMaxMintableRange(uint32 maxMintableLower, uint32 maxMintableUpper) public {
        minter.setMaxMintableRange(address(edition), MINT_ID, maxMintableLower, maxMintableUpper);
    }
}
