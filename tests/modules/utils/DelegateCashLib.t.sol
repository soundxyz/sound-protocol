// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../../TestPlus.sol";
import { DelegateCashLib } from "../../../contracts/modules/utils/DelegateCashLib.sol";

contract MockDelegateCashV2 {
    mapping(address => mapping(address => bool)) internal _hasDelegateForAll;

    function setDelegateForAll(
        address delegate,
        address vault,
        bool value
    ) public {
        _hasDelegateForAll[delegate][vault] = value;
    }

    function checkDelegateForAll(
        address delegate,
        address vault,
        bytes32 rights
    ) public view returns (bool) {
        require(rights == "");
        return _hasDelegateForAll[delegate][vault];
    }
}

contract DelegateCashLibTest is TestPlus {
    function setUp() public {
        vm.etch(DelegateCashLib.REGISTRY_V2, address(new MockDelegateCashV2()).code);
    }

    function test_checkDelegateForAllV2(
        address delegate,
        address vault,
        bool value
    ) public {
        MockDelegateCashV2(DelegateCashLib.REGISTRY_V2).setDelegateForAll(delegate, vault, value);
        assertEq(DelegateCashLib.checkDelegateForAll(delegate, vault), value);
    }
}
