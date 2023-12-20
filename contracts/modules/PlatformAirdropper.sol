// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { ISuperMinterV2 } from "@modules/interfaces/ISuperMinterV2.sol";
import { IPlatformAirdropper } from "@modules/interfaces/IPlatformAirdropper.sol";
import { LibZip } from "solady/utils/LibZip.sol";

/**
 * @title PlatformAirdropper
 * @dev The `PlatformAirdropper` utility class to batch airdrop tokens.
 */
contract PlatformAirdropper is IPlatformAirdropper {
    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev The current number of aliases.
     */
    uint32 public numAliases;

    /**
     * @dev Maps an alias to its original address.
     */
    mapping(address => address) internal _aliasToAddress;

    /**
     * @dev Maps an address to its alias.
     */
    mapping(address => address) internal _addressToAlias;

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
            uint256 n = p.to.length;
            aliases = new address[](n);
            for (uint256 i; i != n; ++i) {
                (aliases[i], p.to[i]) = _getAliasAndAddress(p.to[i]);
            }
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

    /**
     * @inheritdoc IPlatformAirdropper
     */
    function registerAliases(address[] memory a) public returns (address[] memory) {
        unchecked {
            uint256 n = a.length;
            for (uint256 i; i != n; ++i) {
                a[i] = _registerAlias(a[i]);
            }
            return a;
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

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IPlatformAirdropper
     */
    function addressesToAliases(address[] memory a) public view returns (address[] memory) {
        unchecked {
            uint256 n = a.length;
            for (uint256 i; i != n; ++i) {
                a[i] = _addressToAlias[a[i]];
            }
            return a;
        }
    }

    /**
     * @inheritdoc IPlatformAirdropper
     */
    function aliasesToAddresses(address[] memory a) public view returns (address[] memory) {
        unchecked {
            uint256 n = a.length;
            for (uint256 i; i != n; ++i) {
                a[i] = _aliasToAddress[a[i]];
            }
            return a;
        }
    }

    // =============================================================
    //                  INTERNAL / PRIVATE HELPERS
    // =============================================================

    /**
     * @dev Returns the alias and address for `aliasOrAddress`.
     *      If the `aliasOrAddress` is less than `2**31 - 1`, it is treated as an alias.
     *      Otherwise, it is treated as an address, and it's alias will be registered on-the-fly.
     * @param aliasOrAddress The alias or address.
     * @return alias_   The alias.
     * @return address_ The address.
     */
    function _getAliasAndAddress(address aliasOrAddress) internal returns (address alias_, address address_) {
        // If the `aliasOrAddress` is less than or equal to `2**32 - 1`, we will consider it an alias.
        if (uint160(aliasOrAddress) <= type(uint32).max) {
            alias_ = aliasOrAddress;
            address_ = _aliasToAddress[alias_];
            if (address_ == address(0)) revert AliasNotFound();
        } else {
            address_ = aliasOrAddress;
            alias_ = _registerAlias(address_);
        }
    }

    /**
     * @dev Registers the alias for the address on-the-fly.
     * @param address_ The address.
     * @return alias_ The alias registered for the address.
     */
    function _registerAlias(address address_) internal returns (address alias_) {
        if (uint160(address_) <= type(uint32).max) revert AddressTooSmall();

        alias_ = _addressToAlias[address_];
        // If the address has no alias, register it's alias.
        if (alias_ == address(0)) {
            // Increment the `numAliases` and cast it into an alias.
            alias_ = address(uint160(++numAliases));
            // Add to the mappings.
            _aliasToAddress[alias_] = address_;
            _addressToAlias[address_] = alias_;
            emit RegisteredAlias(address_, alias_);
        }
    }
}
