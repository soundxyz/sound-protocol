pragma solidity ^0.8.16;

import { ICoreActions, CoreActions } from "@modules/CoreActions.sol";
import { IAddressAliasRegistry, AddressAliasRegistry } from "@modules/AddressAliasRegistry.sol";
import { EnumerableMap } from "openzeppelin/utils/structs/EnumerableMap.sol";
import { LibSort } from "solady/utils/LibSort.sol";
import "../TestConfigV2_1.sol";

contract CoreActionsTests is TestConfigV2_1 {
    using EnumerableMap for *;

    AddressAliasRegistry aar;
    CoreActions ca;

    EnumerableMap.Bytes32ToUintMap expectedTimestamps;

    function setUp() public virtual override {
        super.setUp();
        aar = new AddressAliasRegistry();
        ca = new CoreActions(address(aar));
    }

    struct _TestTemps {
        address platform;
        uint256 platformSignerPrivateKey;
        address platformSigner;
        address[] targetAliases;
        address[][] actorAliases;
        address[] targets;
        address[] actors;
        uint32[] timestamps;
    }

    function testRegisterCoreActions(uint256) public {
        _TestTemps memory t;
        t.platform = _randomNonZeroAddress();
        (t.platformSigner, t.platformSignerPrivateKey) = _randomSigner();

        vm.prank(t.platform);
        ca.setPlatformSigner(t.platformSigner);

        CoreActions.CoreActionRegistrations memory rs;
        rs.platform = t.platform;
        rs.coreActionType = _random();
        rs.targets = _randomNonZeroAddressesGreaterThan();
        rs.actors = new address[][](rs.targets.length);
        rs.timestamps = new uint32[][](rs.targets.length);
        rs.nonce = _random();
        for (uint256 i; i != rs.targets.length; ++i) {
            rs.actors[i] = _randomNonZeroAddressesGreaterThan();
            rs.timestamps[i] = _randomTimestamps(rs.actors[i].length);
            for (uint256 j; j != rs.actors[i].length; ++j) {
                bytes32 h = keccak256(abi.encodePacked(rs.targets[i], rs.actors[i][j]));
                if (!expectedTimestamps.contains(h)) {
                    expectedTimestamps.set(h, rs.timestamps[i][j]);
                }
            }
        }
        rs.signature = _generateSignature(rs, t.platformSignerPrivateKey);

        (t.targetAliases, t.actorAliases) = ca.register(rs);

        for (uint256 i; i != rs.targets.length; ++i) {
            for (uint256 j; j != rs.actors[i].length; ++j) {
                uint32 timestamp = ca.getCoreActionTimestamp(
                    rs.platform,
                    rs.coreActionType,
                    rs.targets[i],
                    rs.actors[i][j]
                );
                bytes32 h = keccak256(abi.encodePacked(rs.targets[i], rs.actors[i][j]));
                assertEq(timestamp, expectedTimestamps.get(h));
            }
        }

        uint256 actionsSum;
        t.targets = LibSort.difference(rs.targets, new address[](0));
        LibSort.sort(t.targets);
        LibSort.uniquifySorted(t.targets);
        for (uint256 i; i != t.targets.length; ++i) {
            (t.actors, t.timestamps) = ca.getCoreActions(rs.platform, rs.coreActionType, t.targets[i]);
            assertEq(t.actors.length, t.timestamps.length);
            actionsSum += t.actors.length;
            for (uint256 j; j != t.actors.length; ++j) {
                bytes32 h = keccak256(abi.encodePacked(t.targets[i], t.actors[j]));
                assertEq(t.timestamps[j], expectedTimestamps.get(h));
            }
        }
        assertEq(actionsSum, expectedTimestamps.length());

        vm.expectRevert(ICoreActions.InvalidSignature.selector);
        ca.register(rs);
    }

    function _generateSignature(CoreActions.CoreActionRegistrations memory rs, uint256 privateKey)
        internal
        returns (bytes memory signature)
    {
        bytes32 digest = ca.computeDigest(rs);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        signature = abi.encodePacked(r, s, v);
    }

    function _randomNonZeroAddressesGreaterThan() internal returns (address[] memory a) {
        a = _randomNonZeroAddressesGreaterThan(0xffffffff);
    }

    function _randomNonZeroAddressesGreaterThan(uint256 t) internal returns (address[] memory a) {
        uint256 n = _random() % 4;
        if (_random() % 32 == 0) {
            n = _random() % 32;
        }
        a = new address[](n);
        require(t != 0, "t must not be zero");
        unchecked {
            for (uint256 i; i != n; ++i) {
                uint256 r;
                if (_random() & 1 == 0) {
                    while (r <= t) r = uint256(uint160(_random()));
                } else {
                    r = type(uint256).max ^ _bound(_random(), 1, 8);
                }
                a[i] = address(uint160(r));
            }
        }
    }

    function _randomTimestamps(uint256 n) internal returns (uint32[] memory a) {
        a = new uint32[](n);
        unchecked {
            for (uint256 i; i != n; ++i) {
                a[i] = uint32(_bound(_random(), 1, type(uint32).max));
            }
        }
    }

    function _hashOf(address[] memory a) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(a));
    }

    function _hashOf(address[][] memory a) internal pure returns (bytes32) {
        uint256 n = a.length;
        bytes32[] memory encoded = new bytes32[](n);
        for (uint256 i = 0; i != n; ++i) {
            encoded[i] = keccak256(abi.encodePacked(a[i]));
        }
        return keccak256(abi.encodePacked(encoded));
    }

    function _hashOf(uint256[][] calldata a) internal pure returns (bytes32) {
        uint256 n = a.length;
        bytes32[] memory encoded = new bytes32[](n);
        for (uint256 i = 0; i != n; ++i) {
            encoded[i] = keccak256(abi.encodePacked(a[i]));
        }
        return keccak256(abi.encodePacked(encoded));
    }
}
