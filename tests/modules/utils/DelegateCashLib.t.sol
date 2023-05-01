// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../TestPlus.sol";
import { DelegateCashLib } from "../../../contracts/modules/utils/DelegateCashLib.sol";

contract MockDelegateCash {
    mapping(address => mapping(address => bool)) internal _hasDelegateForAll;

    function setDelegateForAll(
        address delegate,
        address vault,
        bool value
    ) public {
        _hasDelegateForAll[delegate][vault] = value;
    }

    function checkDelegateForAll(address delegate, address vault) public view returns (bool) {
        return _hasDelegateForAll[delegate][vault];
    }
}

contract DelegateCashLibTest is TestPlus {
    function setUp() public {
        address mock = address(new MockDelegateCash());
        vm.etch(DelegateCashLib.REGISTRY, mock.code);
    }

    function test_checkDelegateForAll(
        address delegate,
        address vault,
        bool value
    ) public {
        MockDelegateCash(DelegateCashLib.REGISTRY).setDelegateForAll(delegate, vault, value);
        assertEq(DelegateCashLib.checkDelegateForAll(delegate, vault), value);
    }
}
