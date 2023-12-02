pragma solidity ^0.8.16;

import {SuperMinterV1_1} from "@modules/SuperMinterV1_1.sol";
import {SymTest} from "halmos-cheatcodes/SymTest.sol";

contract SuperMinterV1_1SymTest is SuperMinterV1_1, SymTest {

    /// @custom:halmos --no-test-constructor --symbolic-storage --solver-timeout-assertion 0
    function check_totalPriceAndFees(
        uint8 tier,
        uint256 mintId,
        uint32 quantity,
        uint96 signedPrice
    ) public view {
        MintData storage d = _getMintData(mintId);
        _totalPriceAndFees(tier, d, quantity, signedPrice);
    }

    /// @custom:halmos --no-test-constructor --symbolic-storage --solver-timeout-assertion 0
    function check_computeAndAccrueFees(
        uint256 mintId,
        MintTo calldata p,
        TotalPriceAndFees memory f
    ) public payable {
        MintData storage d = _getMintData(mintId);
        MintedLogData memory l = _computeAndAccrueFees(p, d, f);
        assert(l.finalArtistFee + l.finalPlatformFee + l.finalAffiliateFee == f.total);
    }

    function _isAffiliatedWithProof(
        MintData storage,
        address,
        bytes32[] calldata
    ) internal pure override returns (bool) {
        return svm.createBool("_isAffiliatedWithProof");
    }

}
