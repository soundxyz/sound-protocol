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

    uint256 internal _numAliases;

    mapping(address => address) internal _aliasToAddress;

    mapping(address => address) internal _addressToAlias;

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

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

    fallback() external payable {
        LibZip.cdFallback();
    }

    receive() external payable {
        LibZip.cdFallback();
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    function addressesToAliases(address[] memory a) public view returns (address[] memory) {
        unchecked {
            uint256 n = a.length;
            for (uint256 i; i != n; ++i) {
                a[i] = _addressToAlias[a[i]];
            }
            return a;
        }
    }

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

    function _getAliasAndAddress(address aliasOrAddress) internal returns (address alias_, address address_) {
        if (aliasOrAddress == address(0)) revert AliasOrAddressCannotBeZero();

        address_ = _aliasToAddress[aliasOrAddress];

        if (address_ == address(0)) {
            // If the address has not been registered,
            address_ = aliasOrAddress; // then the input must be an address.
            unchecked {
                alias_ = address(uint160(++_numAliases)); // Increment the `_numAliases` and cast it into an alias.
            }
            // Add to the mappings.
            _aliasToAddress[alias_] = address_;
            _addressToAlias[address_] = alias_;
            emit RegisteredAlias(address_, alias_);
        } else {
            // Otherwise, if the address has already been registered,
            alias_ = aliasOrAddress; // then the input must be an alias.
        }
    }
}
