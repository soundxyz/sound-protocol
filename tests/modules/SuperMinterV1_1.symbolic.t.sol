pragma solidity ^0.8.16;

import {SuperMinterV1_1} from "@modules/SuperMinterV1_1.sol";

contract SuperMinterV1_1SymTest is SuperMinterV1_1 {

    /// @custom:halmos --no-test-constructor --symbolic-storage
    function check_totalPriceAndFees(
        uint8 tier,
        uint256 mintId,
        uint32 quantity,
        uint96 signedPrice
    ) public {
        MintData storage d = _getMintData(mintId);
        _totalPriceAndFees(tier, d, quantity, signedPrice);
    }

}
