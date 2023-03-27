// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "solady/utils/FixedPointMathLib.sol";

library BondingCurveLib {
    function sigmoid2Sum(
        uint32 inflectionPoint,
        uint128 inflectionPrice,
        uint32 fromSupply,
        uint32 quantity
    ) internal pure returns (uint256 sum) {
        // We don't need checked arithmetic for the sum.
        // The max possible sum for the quadratic region is capped at:
        // `n * (n + 1) * (2*n + 1) * h < 2**32 * 2**33 * 2**34 * 2**128 = 2**227`.
        // The max possible sum for the sqrt region is capped at:
        // `end * (2*h * sqrt(end)) < 2**32 * 2**129 * 2**16 = 2**177`.
        // The overall sum is capped by:
        // `2**161 + 2**227 <= 2**228 < 2 **256`.
        // The result will be small enough for unchecked multiplication with a 16-bit BPS.
        unchecked {
            uint256 g = inflectionPoint;
            uint256 h = inflectionPrice;

            // Early return to save gas if either `g` or `h` is zero.
            if (g * h == 0) return 0;

            uint256 s = uint256(fromSupply) + 1;
            uint256 end = s + uint256(quantity);
            uint256 quadraticEnd = FixedPointMathLib.min(g, end);

            if (s < quadraticEnd) {
                uint256 k = uint256(fromSupply); // `s - 1`.
                uint256 n = quadraticEnd - 1;
                // In practice, `h` (units: wei) will be set to be much greater than `g * g`.
                uint256 a = FixedPointMathLib.rawDiv(h, g * g);
                // Use the closed form to compute the sum.
                sum = ((n * (n + 1) * ((n << 1) + 1) - k * (k + 1) * ((k << 1) + 1)) / 6) * a;
                s = quadraticEnd;
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
    }

    function linearSum(
        uint128 linearPriceSlope,
        uint32 fromSupply,
        uint32 quantity
    ) internal pure returns (uint256 sum) {
        // We don't need checked arithmetic for the sum because the max possible
        // intermediate value is capped at:
        // `k * m < 2**32 * 2**128 = 2**160 < 2**256`.
        // As `quantity` is 32 bits, max possible value for `sum`
        // is capped at:
        // `2**32 * 2**160 = 2**192 < 2**256`.
        // The result will be small enough for unchecked multiplication with a 16-bit BPS.
        unchecked {
            uint256 m = linearPriceSlope;
            uint256 k = uint256(fromSupply);
            uint256 n = k + uint256(quantity);
            // Use the closed form to compute the sum.
            return m * ((n * (n + 1) - k * (k + 1)) >> 1);
        }
    }
}
