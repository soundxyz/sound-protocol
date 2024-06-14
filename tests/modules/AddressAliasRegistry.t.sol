pragma solidity ^0.8.16;

import { IAddressAliasRegistry, AddressAliasRegistry } from "@modules/AddressAliasRegistry.sol";
import { LibSort } from "solady/utils/LibSort.sol";
import "../TestConfigV2_1.sol";

contract AddressAliasRegistryTests is TestConfigV2_1 {
    AddressAliasRegistry aar;

    function setUp() public virtual override {
        super.setUp();
        aar = new AddressAliasRegistry();
    }

    struct Resolved {
        address[] aliases;
        address[] addresses;
    }

    function test_registerAliases(uint256) public {
        Resolved memory r0;
        Resolved memory r1;
        address[] memory addresses = _randomNonZeroAddressesGreaterThan();
        if (_random() % 32 == 0) {
            (r0.addresses, r0.aliases) = aar.resolve(new address[](addresses.length));
            assertEq(r0.aliases, new address[](addresses.length));
            assertEq(r0.addresses, new address[](addresses.length));
            address a = addresses.length > 0 ? addresses[0] : address(0);
            assertEq(aar.addressOf(a), a);
            assertEq(uint160(aar.aliasOf(a)), 0);
        }
        (r0.addresses, r0.aliases) = aar.resolveAndRegister(addresses);
        (r1.addresses, r1.aliases) = aar.resolve(addresses);
        if (addresses.length != 0) {
            assertEq(uint160(r0.aliases[0]), 1);
            assertEq(uint160(r1.aliases[0]), 1);
            address a = addresses[0];
            assertEq(aar.addressOf(a), a);
            assertEq(aar.addressOf(aar.aliasOf(a)), a);
            assertEq(uint160(aar.aliasOf(a)), 1);
        }
        assertEq(r1.aliases, r0.aliases);
        assertEq(r1.addresses, r0.addresses);
        (r1.addresses, r1.aliases) = aar.resolve(r0.aliases);
        assertEq(r1.aliases, r0.aliases);
        assertEq(r1.addresses, r0.addresses);
        uint256 n = _uniquified(addresses).length;
        assertEq(n, _uniquified(r0.aliases).length);
        assertEq(n, _uniquified(r0.addresses).length);
    }

    function _uniquified(address[] memory a) internal pure returns (address[] memory) {
        LibSort.sort(a);
        LibSort.uniquifySorted(a);
        return a;
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
}
