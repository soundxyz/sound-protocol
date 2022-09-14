// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import { ArweaveURILib } from "@core/utils/ArweaveURILib.sol";

import { TestConfig } from "../../TestConfig.sol";
import { Base64 } from "solady/utils/Base64.sol";

contract ArweaveURILibTest is TestConfig {
    using ArweaveURILib for ArweaveURILib.URI;

    ArweaveURILib.URI public uriStorage;

    function test_initializeURIArweave(uint256 randomness, bool withTrailingSlash) public {
        delete uriStorage;

        vm.assume(randomness != 0);

        string memory newURI = string.concat("ar://", string(Base64.encode(abi.encode(randomness), true, true)));
        string memory expectedURI = string.concat(newURI, "/");

        if (withTrailingSlash) {
            newURI = expectedURI;
        }

        uriStorage.initialize(newURI);

        assertEq(uriStorage.load(), expectedURI);
    }

    function test_updateURIArweave(uint256 randomness, bool withTrailingSlash) public {
        delete uriStorage;

        vm.assume(randomness != 0);

        string memory newURI = string.concat("ar://", string(Base64.encode(abi.encode(randomness), true, true)));
        string memory expectedURI = string.concat(newURI, "/");

        if (withTrailingSlash) {
            newURI = expectedURI;
        }

        uriStorage.update(newURI);

        assertEq(uriStorage.load(), expectedURI);
    }

    function test_updateURIArweave() public {
        test_updateURIArweave(1, false);
        test_updateURIArweave(2, true);
    }

    function test_setBaseURIArweaveAndRegular(uint256 randomness) public {
        vm.assume(randomness != 0);

        string memory newURI;

        for (uint256 i; i < 10; ++i) {
            newURI = string.concat("ar://", string(Base64.encode(abi.encode(randomness), true, true)), "/");

            if (randomness & 1 == 0) {
                newURI = string.concat("https://example.xyz/", string(Base64.encode(bytes(newURI), true, true)), "/");
            }

            uriStorage.update(newURI);

            assertEq(uriStorage.load(), newURI);

            randomness = uint256(keccak256(abi.encode(randomness, block.timestamp)));
        }
    }
}
