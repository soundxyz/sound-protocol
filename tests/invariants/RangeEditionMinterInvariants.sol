// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { SoundEditionV1 } from "@core/SoundEditionV1.sol";
import { MintInfo } from "@modules/interfaces/IRangeEditionMinter.sol";
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

        minter = new RangeEditionMinter(feeRegistry);

        edition.grantRoles(address(minter), edition.MINTER_ROLE());

        minter.createEditionMint(
            address(edition),
            PRICE,
            START_TIME,
            CUTOFF_TIME,
            END_TIME,
            AFFILIATE_FEE_BPS,
            MAX_MINTABLE_LOWER,
            MAX_MINTABLE_UPPER,
            MAX_MINTABLE_PER_ACCOUNT
        );

        minterUpdater = new RangeEditionMinterUpdater(edition, minter);

        addTargetContract(address(minter));
    }

    function invariant_maxMintableRange() public {
        MintInfo memory data = minter.mintInfo(address(edition), MINT_ID);
        assertTrue(data.maxMintableLower <= data.maxMintableUpper);
    }

    function invariant_timeRange() public {
        MintInfo memory mintInfo = minter.mintInfo(address(edition), MINT_ID);

        uint32 startTime = mintInfo.startTime;
        uint32 cutoffTime = mintInfo.cutoffTime;
        uint32 endTime = mintInfo.endTime;
        assertTrue(startTime < cutoffTime && cutoffTime < endTime);
    }
}

contract RangeEditionMinterUpdater {
    uint128 constant MINT_ID = 0;

    SoundEditionV1 edition;
    RangeEditionMinter minter;

    constructor(SoundEditionV1 _edition, RangeEditionMinter _minter) {
        edition = _edition;
        minter = _minter;
    }

    function setTimeRange(
        uint32 startTime,
        uint32 cutoffTime,
        uint32 endTime
    ) public {
        minter.setTimeRange(address(edition), MINT_ID, startTime, cutoffTime, endTime);
    }

    function setMaxMintableRange(uint32 maxMintableLower, uint32 maxMintableUpper) public {
        minter.setMaxMintableRange(address(edition), MINT_ID, maxMintableLower, maxMintableUpper);
    }
}
