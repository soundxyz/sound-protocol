// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { ISuperMinterV2 } from "@modules/interfaces/ISuperMinterV2.sol";
import { IPlatformAirdropper } from "@modules/interfaces/IPlatformAirdropper.sol";
import { IAddressAliasRegistry } from "@modules/interfaces/IAddressAliasRegistry.sol";
import { LibZip } from "solady/utils/LibZip.sol";

/**
 * @title PlatformAirdropper
 * @dev The `PlatformAirdropper` utility class to batch airdrop tokens.
 */
contract PlatformAirdropper is IPlatformAirdropper {
    // =============================================================
    //                          IMMUTABLES
    // =============================================================

    /**
     * @dev The address alias registry.
     */
    address public immutable addressAliasRegistry;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor(address addressAliasRegistry_) payable {
        addressAliasRegistry = addressAliasRegistry_;
    }

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IPlatformAirdropper
     */
    function platformAirdrop(address superMinter, ISuperMinterV2.PlatformAirdrop memory p)
        public
        returns (uint256 fromTokenId, address[] memory aliases)
    {
        unchecked {
            (p.to, aliases) = IAddressAliasRegistry(addressAliasRegistry).resolveAndRegister(p.to);
            fromTokenId = ISuperMinterV2(superMinter).platformAirdrop(p);
        }
    }

    /**
     * @inheritdoc IPlatformAirdropper
     */
    function platformAirdropMulti(address superMinter, ISuperMinterV2.PlatformAirdrop[] memory p)
        public
        returns (uint256[] memory fromTokenIds, address[][] memory aliases)
    {
        unchecked {
            uint256 n = p.length;
            fromTokenIds = new uint256[](n);
            aliases = new address[][](n);
            for (uint256 i; i != n; ++i) {
                (fromTokenIds[i], aliases[i]) = platformAirdrop(superMinter, p[i]);
            }
        }
    }

    // Misc functions:
    // ---------------

    /**
     * @dev For calldata compression.
     */
    fallback() external payable {
        LibZip.cdFallback();
    }

    /**
     * @dev For calldata compression.
     */
    receive() external payable {
        LibZip.cdFallback();
    }
}
