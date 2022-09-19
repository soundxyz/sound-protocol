// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { ArweaveURILib } from "@core/utils/ArweaveURILib.sol";

import { TestConfig } from "../../TestConfig.sol";
import { Base64 } from "solady/utils/Base64.sol";

contract ArweaveURILibTest is TestConfig {
    using ArweaveURILib for ArweaveURILib.URI;

    ArweaveURILib.URI public uriStorage;

    function test_initializeURIArweave(uint256 randomness, bool withTrailingSlash) public {
        vm.assume(randomness != 0);
        delete uriStorage;

        string memory newURI = string.concat("ar://", string(Base64.encode(abi.encode(randomness), true, true)));
        string memory expectedURI = string.concat(newURI, "/");

        if (withTrailingSlash) {
            newURI = expectedURI;
        }

        uriStorage.initialize(newURI);

        assertEq(uriStorage.load(), expectedURI);
    }

    function test_initializeURIArweave() public {
        unchecked {
            for (uint256 i = 1; i != 8; ++i) {
                uint256 randomness = uint256(keccak256(abi.encode(i)));
                test_initializeURIArweave(randomness, true);
                test_initializeURIArweave(randomness, false);
            }
        }
    }

    function test_updateURIArweave(uint256 randomness, bool withTrailingSlash) public {
        vm.assume(randomness != 0);
        delete uriStorage;

        string memory newURI = string.concat("ar://", string(Base64.encode(abi.encode(randomness), true, true)));
        string memory expectedURI = string.concat(newURI, "/");

        if (withTrailingSlash) {
            newURI = expectedURI;
        }

        uriStorage.update(newURI);

        assertEq(uriStorage.load(), expectedURI);
    }

    function test_updateURIArweave() public {
        unchecked {
            for (uint256 i = 1; i != 8; ++i) {
                uint256 randomness = uint256(keccak256(abi.encode(i)));
                test_updateURIArweave(randomness, true);
                test_updateURIArweave(randomness, false);
            }
        }
    }

    function test_setBaseURIArweaveAndRegular(uint256 randomness) public {
        vm.assume(randomness != 0);
        delete uriStorage;

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

    function test_setBaseURIArweaveAndRegular() public {
        unchecked {
            for (uint256 i = 1; i != 16; ++i) {
                uint256 randomness = uint256(keccak256(abi.encode(i)));
                test_setBaseURIArweaveAndRegular(randomness);
            }
        }
    }
}
