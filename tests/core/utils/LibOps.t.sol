// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { LibOps } from "@core/utils/LibOps.sol";
import { LibMap } from "solady/utils/LibMap.sol";
import { TestConfig } from "../../TestConfig.sol";

contract MintRandomnessLibTest is TestConfig {
    using LibMap for *;

    error Overflow();
    error Unauthorized();

    function _brutalizeBool(bool x) internal view returns (bool result) {
        assembly {
            mstore(0x00, gas())
            result := mul(iszero(iszero(x)), keccak256(0x00, 0x20))
        }
    }

    function _brutalizeUint8(uint8 x) internal view returns (uint8 result) {
        assembly {
            mstore(0x00, gas())
            result := or(x, shl(8, keccak256(0x00, 0x20)))
        }
    }

    function _brutalizeUint32(uint32 x) internal view returns (uint32 result) {
        assembly {
            mstore(0x00, gas())
            result := or(x, shl(32, keccak256(0x00, 0x20)))
        }
    }

    function _brutalizeUint96(uint96 x) internal view returns (uint96 result) {
        assembly {
            mstore(0x00, gas())
            result := or(x, shl(96, keccak256(0x00, 0x20)))
        }
    }

    function _brutalizeAddress(address x) internal view returns (address result) {
        assembly {
            mstore(0x00, gas())
            result := or(x, shl(160, keccak256(0x00, 0x20)))
        }
    }

    function testAndDifferential(bool x, bool y) public {
        assertEq(LibOps.and(_brutalizeBool(x), _brutalizeBool(y)), x && y);
    }

    function testOrDifferential(bool x, bool y) public {
        assertEq(LibOps.or(_brutalizeBool(x), _brutalizeBool(y)), x || y);
    }

    function testMaxDifferential(uint256 x, uint256 y) public {
        assertEq(LibOps.max(x, y), x > y ? x : y);
    }

    function testMaxDifferential(uint32 x, uint32 y) public {
        assertEq(LibOps.max(_brutalizeUint32(x), _brutalizeUint32(y)), x > y ? x : y);
    }

    function testMinDifferential(uint256 x, uint256 y) public {
        assertEq(LibOps.min(x, y), x < y ? x : y);
    }

    function testMinDifferential(uint32 x, uint32 y) public {
        assertEq(LibOps.min(_brutalizeUint32(x), _brutalizeUint32(y)), x < y ? x : y);
    }

    function testToFlagDifferential(bool isOn, uint8 flag) public {
        assertEq(LibOps.toFlag(_brutalizeBool(isOn), _brutalizeUint8(flag)), isOn ? flag : 0);
    }

    function testSetFlagToDifferential(
        uint8 flags,
        uint8 index,
        bool b
    ) public {
        uint8 expected = flags;
        uint8 flag = uint8(1 << (index % 8));
        if ((flags & flag != 0) != b) {
            expected ^= flag;
        }
        assertEq(LibOps.setFlagTo(_brutalizeUint8(flags), _brutalizeUint8(flag), _brutalizeBool(b)), expected);
    }

    function testMaxIfZeroDifferential(uint32 q, uint32 n) public {
        uint256 expected = q == 0 ? type(uint256).max : q;
        assertEq(LibOps.maxIfZero(_brutalizeUint32(q)), expected);
        bool b = n > LibOps.maxIfZero(_brutalizeUint32(q));
        assertEq(b, LibOps.and(q != 0, n > q));
        assertEq(b, q != 0 && n > q);
    }

    LibMap.Uint32Map binarySearchMap;
    mapping(uint256 => bool) filled;

    function _binarySearch(uint256 tokenId, uint256 n) internal view returns (uint256) {
        (bool found, uint256 index) = binarySearchMap.searchSorted(uint32(tokenId), 0, n);
        return LibOps.and(tokenId < 1 << 32, found) ? index : type(uint256).max;
    }

    function testBinarySearch(uint256) public {
        unchecked {
            uint256 n = 1 + (_random() % 64);
            uint256 v = _random() % 3;
            for (uint256 i; i != n; ++i) {
                binarySearchMap.set(i, uint32(v));
                filled[uint32(v)] = true;
                v += 1 + (_random() % 256);
            }
            uint256 randomIndex = _random() % n;
            assertEq(_binarySearch(binarySearchMap.get(randomIndex), n), randomIndex);
            assertEq(_binarySearch(type(uint256).max, n), type(uint256).max);
            assertEq(_binarySearch(type(uint256).max, 0), type(uint256).max);

            uint256 notFoundValue;
            do {
                notFoundValue = _bound(_random(), 0, v);
            } while (filled[notFoundValue]);
            assertFalse(filled[notFoundValue]);
            assertEq(_binarySearch(notFoundValue, n), type(uint256).max);
        }
    }

    function testPackIdDifferential(address x, uint96 y) public {
        uint256 expected = (uint256(uint160(x)) << 96) | uint256(y);
        assertEq(LibOps.packId(_brutalizeAddress(x), _brutalizeUint96(y)), expected);
    }

    function testPackIdDifferential(
        address x,
        uint8 y,
        uint8 z
    ) public {
        uint256 expected = (uint256(uint160(x)) << 96) | (uint256(y) << 8) | uint256(z);
        assertEq(LibOps.packId(_brutalizeAddress(x), _brutalizeUint8(y), _brutalizeUint8(z)), expected);
    }

    function testRevertOverflow() public {
        vm.expectRevert(Overflow.selector);
        LibOps.revertOverflow();
    }

    function testRevertUnauthorized() public {
        vm.expectRevert(Unauthorized.selector);
        LibOps.revertUnauthorized();
    }
}
