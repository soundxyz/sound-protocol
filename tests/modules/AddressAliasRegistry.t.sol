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
            (r0.aliases, r0.addresses) = aar.resolve(new address[](addresses.length));
            assertEq(r0.aliases, new address[](addresses.length));
            assertEq(r0.addresses, new address[](addresses.length));
        }
        (r0.aliases, r0.addresses) = aar.resolveAndRegister(addresses);
        (r1.aliases, r1.addresses) = aar.resolve(addresses);
        assertEq(r1.aliases, r0.aliases);
        assertEq(r1.addresses, r0.addresses);
        (r1.aliases, r1.addresses) = aar.resolve(r0.aliases);
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
