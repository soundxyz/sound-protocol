// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

/**
 * @title LibOps
 * @dev Shared utilities.
 */
library LibOps {
    // =============================================================
    //                            ERRORS
    // =============================================================

    /**
     * @dev Error for overflows.
     */
    error Overflow();

    /**
     * @dev Error for unauthorized access.
     */
    error Unauthorized();

    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /**
     * @dev A role every minter module must have in order to mint new tokens.
     *      IMPORTANT: This constant must NEVER be changed!
     *      It will always be 2 across all past and future sound protocol contracts.
     */
    uint256 internal constant MINTER_ROLE = 1 << 1;

    /**
     * @dev A role the owner can grant for performing admin actions.
     *      IMPORTANT: This constant must NEVER be changed!
     *      It will always be 1 across all past and future sound protocol contracts.
     */
    uint256 internal constant ADMIN_ROLE = 1 << 0;

    /**
     * @dev Basis points denominator used in fee calculations.
     *      IMPORTANT: This constant must NEVER be changed!
     *      It will always be 10000 across all past and future sound protocol contracts.
     */
    uint16 internal constant BPS_DENOMINATOR = 10000;

    // =============================================================
    //                           FUNCTIONS
    // =============================================================

    /**
     * @dev `isOn ? flag : 0`.
     */
    function toFlag(bool isOn, uint8 flag) internal pure returns (uint8 result) {
        assembly {
            result := mul(iszero(iszero(isOn)), flag)
        }
    }

    /**
     * @dev `(flags & flag != 0) != isOn ? flags ^ flag : flags`.
     *      Sets `flag` in `flags` to 1 if `isOn` is true.
     *      Sets `flag` in `flags` to 0 if `isOn` is false.
     */
    function setFlagTo(
        uint8 flags,
        uint8 flag,
        bool isOn
    ) internal pure returns (uint8 result) {
        assembly {
            result := xor(flags, mul(xor(iszero(and(0xff, and(flags, flag))), iszero(isOn)), flag))
        }
    }

    /**
     * @dev `x > y ? x : y`.
     */
    function max(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            z := xor(x, mul(xor(x, y), gt(y, x)))
        }
    }

    /**
     * @dev `x < y ? x : y`.
     */
    function min(uint256 x, uint256 y) internal pure returns (uint256 z) {
        assembly {
            z := xor(x, mul(xor(x, y), lt(y, x)))
        }
    }

    /**
     * @dev `(a * b) / d`. Returns 0 if `d` is zero.
     */
    function rawMulDiv(
        uint256 a,
        uint256 b,
        uint256 d
    ) internal pure returns (uint256 z) {
        assembly {
            z := div(mul(a, b), d)
        }
    }

    /**
     * @dev `a / d`. Returns 0 if `d` is zero.
     */
    function rawMod(uint256 a, uint256 d) internal pure returns (uint256 z) {
        assembly {
            z := mod(a, d)
        }
    }

    /**
     * @dev `a | b`.
     */
    function or(bool a, bool b) internal pure returns (bool z) {
        assembly {
            z := or(iszero(iszero(a)), iszero(iszero(b)))
        }
    }

    /**
     * @dev `a | b | c`.
     */
    function or(
        bool a,
        bool b,
        bool c
    ) internal pure returns (bool z) {
        z = or(a, or(b, c));
    }

    /**
     * @dev `a | b | c | d`.
     */
    function or(
        bool a,
        bool b,
        bool c,
        bool d
    ) internal pure returns (bool z) {
        z = or(a, or(b, or(c, d)));
    }

    /**
     * @dev `a & b`.
     */
    function and(bool a, bool b) internal pure returns (bool z) {
        assembly {
            z := and(iszero(iszero(a)), iszero(iszero(b)))
        }
    }

    /**
     * @dev `x == 0 ? type(uint256).max : x`
     */
    function maxIfZero(uint256 x) internal pure returns (uint256 z) {
        assembly {
            z := sub(x, iszero(x))
        }
    }

    /**
     * @dev Packs an address and an index to create an unique identifier.
     * @param a The address.
     * @param i The index.
     * @return result The packed result.
     */
    function packId(address a, uint96 i) internal pure returns (uint256 result) {
        assembly {
            result := or(shl(96, a), shr(160, shl(160, i)))
        }
    }

    /**
     * @dev Packs `edition`, `tier`, `scheduleNum` to create an unique identifier.
     * @param edition     The address of the Sound Edition.
     * @param tier        The tier.
     * @param scheduleNum The edition-tier schedule number.
     * @return result The packed result.
     */
    function packId(
        address edition,
        uint8 tier,
        uint8 scheduleNum
    ) internal pure returns (uint256 result) {
        assembly {
            mstore(0x00, shl(96, edition))
            mstore8(0x1e, tier)
            mstore8(0x1f, scheduleNum)
            result := mload(0x00)
        }
    }

    /**
     * @dev `revert Overflow()`.
     */
    function revertOverflow() internal pure {
        assembly {
            mstore(0x00, 0x35278d12) // `Overflow()`.
            revert(0x1c, 0x04)
        }
    }

    /**
     * @dev `revert Unauthorized()`.
     */
    function revertUnauthorized() internal pure {
        assembly {
            mstore(0x00, 0x82b42900) // `Unauthorized()`.
            revert(0x1c, 0x04)
        }
    }
}
