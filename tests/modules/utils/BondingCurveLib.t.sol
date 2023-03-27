// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../TestPlus.sol";
import { BondingCurveLib } from "../../../contracts/modules/utils/BondingCurveLib.sol";
import { LibString } from "solady/utils/LibString.sol";
import { DynamicBufferLib } from "solady/utils/DynamicBufferLib.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";

contract BondingCurveLibTest is TestPlus {
    using LibString for *;
    using DynamicBufferLib for *;

    function testSigmoid2MultiPurchase(
        uint32 g,
        uint96 h,
        uint32 s,
        uint8 q
    ) public {
        vm.assume(s <= type(uint32).max - q);

        uint256 sum;
        for (uint256 i = 0; i < q; ++i) {
            sum += BondingCurveLib.sigmoid2Sum(g, h, s + uint32(i), 1);
        }
        uint256 multi = BondingCurveLib.sigmoid2Sum(g, h, s, q);

        assertTrue(multi == sum);
    }

    function testSigmoid2MultiSell(
        uint32 g,
        uint96 h,
        uint32 s,
        uint8 q
    ) public {
        vm.assume(s >= q);

        uint256 sum;
        for (uint256 i = 0; i < q; ++i) {
            sum += BondingCurveLib.sigmoid2Sum(g, h, s - uint32(i + 1), 1);
        }
        uint256 multi = BondingCurveLib.sigmoid2Sum(g, h, s - q, q);

        assertTrue(multi == sum);
    }

    function testSigmoid2(uint32 g, uint96 h) public {
        unchecked {
            if (g < 3) g = 3;
            if (h == 0) h++;
            for (uint256 o; o < 8; ++o) {
                uint256 supply = g - 3 + o;
                if (supply < type(uint32).max) {
                    uint256 p0 = _sigmoid2(g, h, uint32(supply));
                    uint256 p1 = _sigmoid2(g, h, uint32(supply + 1));
                    assertTrue(p0 <= p1);
                }
            }
        }
    }

    function testSigmoid2() public {
        uint32 g; // Inflection point.
        uint96 h; // Inflection price.

        g = 1000;
        h = 10000000000000000000;
        _testSigmoid2Brutalized(g, h, 0, 10000000000000);
        _testSigmoid2Brutalized(g, h, 1, 40000000000000);
        _testSigmoid2Brutalized(g, h, 2, 90000000000000);
        _testSigmoid2Brutalized(g, h, 998, 9980010000000000000);
        _testSigmoid2Brutalized(g, h, 999, 10000000000000000000);
        _testSigmoid2Brutalized(g, h, 1000, 10000000000000000000);
        _testSigmoid2Brutalized(g, h, 1001, 10020000000000000000);
        _testSigmoid2Brutalized(g, h, 1002, 10040000000000000000);
        _testSigmoid2Brutalized(g, h, 1003, 10060000000000000000);
        _testSigmoid2Brutalized(g, h, 9999, 60820000000000000000);
        _testSigmoid2Brutalized(g, h, 10000, 60820000000000000000);
        _testSigmoid2Brutalized(g, h, 2147483646, 29308580000000000000000);
        _testSigmoid2Brutalized(g, h, 2147483647, 29308580000000000000000);
        _testSigmoid2Brutalized(g, h, 2147483648, 29308580000000000000000);
        _testSigmoid2Brutalized(g, h, 4294967293, 41448600000000000000000);
        _testSigmoid2Brutalized(g, h, 4294967294, 41448600000000000000000);
        _testSigmoid2Brutalized(g, h, 4294967295, 41448600000000000000000);

        g = 1;
        h = 123456789123456789123;
        _testSigmoid2Brutalized(g, h, 0, 246913578246913578246);
        _testSigmoid2Brutalized(g, h, 1, 246913578246913578246);
        _testSigmoid2Brutalized(g, h, 2, 246913578246913578246);
        _testSigmoid2Brutalized(g, h, 998, 7654320925654320925626);
        _testSigmoid2Brutalized(g, h, 999, 7654320925654320925626);
        _testSigmoid2Brutalized(g, h, 1000, 7654320925654320925626);
        _testSigmoid2Brutalized(g, h, 1001, 7654320925654320925626);
        _testSigmoid2Brutalized(g, h, 1002, 7654320925654320925626);
        _testSigmoid2Brutalized(g, h, 1003, 7654320925654320925626);
        _testSigmoid2Brutalized(g, h, 9999, 24691357824691357824600);
        _testSigmoid2Brutalized(g, h, 10000, 24691357824691357824600);
        _testSigmoid2Brutalized(g, h, 2147483646, 11441975215961975215919640);
        _testSigmoid2Brutalized(g, h, 2147483647, 11441975215961975215919640);
        _testSigmoid2Brutalized(g, h, 2147483648, 11441975215961975215919640);
        _testSigmoid2Brutalized(g, h, 4294967293, 16181481350411481350351610);
        _testSigmoid2Brutalized(g, h, 4294967294, 16181481350411481350351610);
        _testSigmoid2Brutalized(g, h, 4294967295, 16181728263989728263929856);

        g = type(uint32).max;
        h = type(uint96).max;
        _testSigmoid2Brutalized(g, h, 0, 4294967298);
        _testSigmoid2Brutalized(g, h, 1, 17179869192);
        _testSigmoid2Brutalized(g, h, 2, 38654705682);
        _testSigmoid2Brutalized(g, h, 998, 4286381658371298);
        _testSigmoid2Brutalized(g, h, 999, 4294967298000000);
        _testSigmoid2Brutalized(g, h, 1000, 4303561527563298);
        _testSigmoid2Brutalized(g, h, 1001, 4312164347061192);
        _testSigmoid2Brutalized(g, h, 1002, 4320775756493682);
        _testSigmoid2Brutalized(g, h, 1003, 4329395755860768);
        _testSigmoid2Brutalized(g, h, 9999, 429496729800000000);
        _testSigmoid2Brutalized(g, h, 10000, 429582633440927298);
        _testSigmoid2Brutalized(g, h, 2147483646, 19807040619342712357236244482);
        _testSigmoid2Brutalized(g, h, 2147483647, 19807040637789456435240763392);
        _testSigmoid2Brutalized(g, h, 2147483648, 19807040656236200521835216898);
        _testSigmoid2Brutalized(g, h, 4294967293, 79228162477370849428944977928);
        _testSigmoid2Brutalized(g, h, 4294967294, 79228162495817593515539431422);
        _testSigmoid2Brutalized(g, h, 4294967295, 79228162532711081671548469248);

        g = type(uint32).max >> 1;
        h = type(uint96).max;
        _testSigmoid2Brutalized(g, h, 0, 17179869200);
        _testSigmoid2Brutalized(g, h, 1, 68719476800);
        _testSigmoid2Brutalized(g, h, 2, 154618822800);
        _testSigmoid2Brutalized(g, h, 998, 17145526641469200);
        _testSigmoid2Brutalized(g, h, 999, 17179869200000000);
        _testSigmoid2Brutalized(g, h, 1000, 17214246118269200);
        _testSigmoid2Brutalized(g, h, 1001, 17248657396276800);
        _testSigmoid2Brutalized(g, h, 1002, 17283103034022800);
        _testSigmoid2Brutalized(g, h, 1003, 17317583031507200);
        _testSigmoid2Brutalized(g, h, 9999, 1717986920000000000);
        _testSigmoid2Brutalized(g, h, 10000, 1718330534563869200);
        _testSigmoid2Brutalized(g, h, 2147483646, 79228162477370849428944977910);
        _testSigmoid2Brutalized(g, h, 2147483647, 79228162551157825758142922759);
        _testSigmoid2Brutalized(g, h, 2147483648, 79228162624944802087340867607);
        _testSigmoid2Brutalized(g, h, 4294967293, 177159557067767033207256239551);
        _testSigmoid2Brutalized(g, h, 4294967294, 177159557141554009536454184399);
        _testSigmoid2Brutalized(g, h, 4294967295, 177159557141554009536454184399);

        g = 1;
        h = type(uint96).max;
        _testSigmoid2Brutalized(g, h, 0, 158456325028528675187087900670);
        _testSigmoid2Brutalized(g, h, 1, 158456325028528675187087900670);
        _testSigmoid2Brutalized(g, h, 2, 158456325028528675187087900670);
        _testSigmoid2Brutalized(g, h, 998, 4912146075884388930799724920770);
        _testSigmoid2Brutalized(g, h, 999, 4912146075884388930799724920770);
        _testSigmoid2Brutalized(g, h, 1000, 4912146075884388930799724920770);
        _testSigmoid2Brutalized(g, h, 1001, 4912146075884388930799724920770);
        _testSigmoid2Brutalized(g, h, 1002, 4912146075884388930799724920770);
        _testSigmoid2Brutalized(g, h, 1003, 4912146075884388930799724920770);
        _testSigmoid2Brutalized(g, h, 9999, 15845632502852867518708790067000);
        _testSigmoid2Brutalized(g, h, 10000, 15845632502852867518708790067000);
        _testSigmoid2Brutalized(g, h, 2147483646, 7342866101822018808169653317047800);
        _testSigmoid2Brutalized(g, h, 2147483647, 7342866101822018808169653317047800);
        _testSigmoid2Brutalized(g, h, 2147483648, 7342866101822018808169653317047800);
        _testSigmoid2Brutalized(g, h, 4294967293, 10384435260744626728385805570408450);
        _testSigmoid2Brutalized(g, h, 4294967294, 10384435260744626728385805570408450);
        _testSigmoid2Brutalized(g, h, 4294967295, 10384593717069655257060992658309120);

        // Yes, for certain values, where the inflection price is too low compared to
        // the inflection point, the price for the quadratic region can be zero.
        g = 1351215609;
        h = 4294967296;
        _testSigmoid2Brutalized(g, h, 0, 0);
        _testSigmoid2Brutalized(g, h, 1, 0);
        _testSigmoid2Brutalized(g, h, 2, 0);
        _testSigmoid2Brutalized(g, h, 998, 0);
        _testSigmoid2Brutalized(g, h, 999, 0);
        _testSigmoid2Brutalized(g, h, 1000, 0);
        _testSigmoid2Brutalized(g, h, 1001, 0);
        _testSigmoid2Brutalized(g, h, 1002, 0);
        _testSigmoid2Brutalized(g, h, 1003, 0);
        _testSigmoid2Brutalized(g, h, 9999, 0);
        _testSigmoid2Brutalized(g, h, 10000, 0);
        _testSigmoid2Brutalized(g, h, 2147483646, 7869512557);
        _testSigmoid2Brutalized(g, h, 2147483647, 7869512557);
        _testSigmoid2Brutalized(g, h, 2147483648, 7869512563);
        _testSigmoid2Brutalized(g, h, 4294967293, 13386511417);
        _testSigmoid2Brutalized(g, h, 4294967294, 13386511417);
        _testSigmoid2Brutalized(g, h, 4294967295, 13386511423);

        g = 0;
        h = 123456789123456789123;
        _testSigmoid2Brutalized(g, h, 0, 0);
        _testSigmoid2Brutalized(g, h, 4294967295, 0);

        g = 0;
        h = 0;
        _testSigmoid2Brutalized(g, h, 0, 0);
        _testSigmoid2Brutalized(g, h, 4294967295, 0);

        g = 1000;
        h = 0;
        _testSigmoid2Brutalized(g, h, 0, 0);
        _testSigmoid2Brutalized(g, h, 4294967295, 0);
    }

    // Uncomment this to run.

    // function testSigmoid2FFI(uint32 g, uint96 h, uint32 s) public {
    //     DynamicBufferLib.DynamicBuffer memory b;
    //     b.append("import math;");
    //     b.append("g = ", bytes(LibString.toString(g)), ";");
    //     b.append("h = ", bytes(LibString.toString(h)), ";");
    //     b.append("s = ", bytes(LibString.toString(s)), ";");
    //     b.append("print (str(0 if (g == 0 or h == 0) else (");
    //     b.append(
    //         "int( ((h * int(math.isqrt(abs((s + 1) - ((3 * g) >> 2)) * g))) << 1) // g) ",
    //         "if (s + 1) >= g else ",
    //         "int((s + 1) * (s + 1) * (h // (g * g)))"
    //     );
    //     b.append(")) + '_');");

    //     string[] memory cmds = new string[](3);
    //     cmds[0] = "python3";
    //     cmds[1] = "-c";
    //     cmds[2] = string(b.data);

    //     bytes memory result = vm.ffi(cmds);

    //     uint256 computed = _sigmoid2(g, h, s);

    //     assertEq(LibString.toString(computed).concat("_"), string(result));
    // }

    function _testSigmoid2Brutalized(
        uint32 inflectionPoint,
        uint96 inflectionPrice,
        uint32 supply,
        uint256 expectedResult
    ) internal {
        uint256 w = _random();
        assembly {
            inflectionPoint := or(inflectionPoint, shl(32, w))
            inflectionPrice := or(inflectionPrice, shl(96, w))
            supply := or(supply, shl(32, w))
        }
        assertEq(_sigmoid2(inflectionPoint, inflectionPrice, supply), expectedResult);
    }

    function _sigmoid2(
        uint32 inflectionPoint,
        uint96 inflectionPrice,
        uint32 supply
    ) internal pure returns (uint256) {
        return BondingCurveLib.sigmoid2Sum(inflectionPoint, inflectionPrice, supply, 1);
    }

    function testSigmoid2Sum(
        uint128 inflectionPrice,
        uint32 fromSupply,
        uint32 quantity0,
        uint32 quantity1
    ) public {
        if (uint256(fromSupply) + uint256(quantity0) + uint256(quantity1) > type(uint32).max) {
            fromSupply = uint32(_bound(_random(), 0, type(uint32).max));
            quantity0 = uint32(_bound(_random(), 0, type(uint32).max - fromSupply));
            quantity1 = uint32(_bound(_random(), 0, type(uint32).max - fromSupply - quantity0));
        }
        uint32 inflectionPoint = type(uint32).max;
        uint256 sum0 = BondingCurveLib.sigmoid2Sum(inflectionPoint, inflectionPrice, fromSupply, quantity0);
        uint256 sum1 = BondingCurveLib.sigmoid2Sum(inflectionPoint, inflectionPrice, fromSupply + quantity0, quantity1);
        assertEq(
            sum0 + sum1,
            BondingCurveLib.sigmoid2Sum(inflectionPoint, inflectionPrice, fromSupply, quantity0 + quantity1)
        );
    }

    function testSigmoid2Sum(
        uint128 inflectionPrice,
        uint32 fromSupply,
        uint32 quantity
    ) public {
        uint32 inflectionPoint = uint32(type(uint32).max);
        quantity = uint32(_bound(quantity, 0, 256));
        uint256 sum = BondingCurveLib.sigmoid2Sum(inflectionPoint, inflectionPrice, fromSupply, quantity);
        assertEq(sum, _sigmoid2Sum(inflectionPoint, inflectionPrice, fromSupply, quantity));
    }

    function _sigmoid2Sum(
        uint32 inflectionPoint,
        uint128 inflectionPrice,
        uint32 fromSupply,
        uint32 quantity
    ) internal pure returns (uint256 sum) {
        uint256 g = inflectionPoint;
        uint256 h = inflectionPrice;

        // Early return to save gas if either `g` or `h` is zero.
        if (g * h == 0) return 0;

        uint256 s = uint256(fromSupply) + 1;
        uint256 end = s + uint256(quantity);
        uint256 quadraticEnd = FixedPointMathLib.min(g, end);

        if (s < quadraticEnd) {
            uint256 a = FixedPointMathLib.rawDiv(h, g * g);
            do {
                sum += s * s * a;
            } while (++s != quadraticEnd);
        }

        if (s < end) {
            uint256 c = (3 * g) >> 2;
            uint256 h2 = h << 1;
            do {
                uint256 r = FixedPointMathLib.sqrt((s - c) * g);
                sum += FixedPointMathLib.rawDiv(h2 * r, g);
            } while (++s != end);
        }
    }

    function testLinearSum(
        uint128 linearPriceSlope,
        uint32 fromSupply,
        uint32 quantity
    ) public {
        quantity = uint32(_bound(quantity, 0, 256));
        uint256 sum = BondingCurveLib.linearSum(linearPriceSlope, fromSupply, quantity);
        assertEq(sum, _linearSum(linearPriceSlope, fromSupply, quantity));
    }

    function testLinearSum(
        uint128 linearPriceSlope,
        uint32 fromSupply,
        uint32 quantity0,
        uint32 quantity1
    ) public {
        if (uint256(fromSupply) + uint256(quantity0) + uint256(quantity1) > type(uint32).max) {
            fromSupply = uint32(_bound(_random(), 0, type(uint32).max));
            quantity0 = uint32(_bound(_random(), 0, type(uint32).max - fromSupply));
            quantity1 = uint32(_bound(_random(), 0, type(uint32).max - fromSupply - quantity0));
        }
        uint256 sum0 = BondingCurveLib.linearSum(linearPriceSlope, fromSupply, quantity0);
        uint256 sum1 = BondingCurveLib.linearSum(linearPriceSlope, fromSupply + quantity0, quantity1);
        assertEq(sum0 + sum1, BondingCurveLib.linearSum(linearPriceSlope, fromSupply, quantity0 + quantity1));
    }

    function _linearSum(
        uint128 linearPriceSlope,
        uint32 fromSupply,
        uint32 quantity
    ) internal pure returns (uint256 sum) {
        uint256 m = linearPriceSlope;

        // Early return to save gas if `m` is zero.
        if (m == 0) return 0;

        uint256 s = uint256(fromSupply) + 1;
        uint256 end = s + uint256(quantity);

        while (s < end) {
            sum += m * s;
            ++s;
        }
    }
}
