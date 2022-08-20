// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.16;

import "openzeppelin/utils/introspection/IERC165.sol";

/**
 * @title Interface for the base minter functionality, excluding the mint function.
 */
interface IBaseMinter is IERC165 {
    // ================================
    // STRUCTS
    // ================================

    struct BaseData {
        uint32 startTime;
        uint32 endTime;
        uint16 affiliateFeeBPS;
        uint16 affiliateDiscountBPS;
        bool mintPaused;
    }

    // ================================
    // WRITE FUNCTIONS
    // ================================

    /**
     * @dev Sets the `paused` status for `edition`.
     * Calling conditions:
     * - The caller must be the edition's owner or an admin.
     */
    function setEditionMintPaused(
        address edition,
        uint256 mintId,
        bool paused
    ) external;

    /**
     * @dev Sets the time range for an edition mint.
     * Calling conditions:
     * - The caller must be the edition's owner or an admin.
     */
    function setTimeRange(
        address edition,
        uint256 mintId,
        uint32 startTime,
        uint32 endTime
    ) external;

    /**
     * @dev Sets the `affiliateFeeBPS` for (`edition`, `mintId`).
     * Calling conditions:
     * - The caller must be the current controller for (`edition`, `mintId`).
     */
    function setAffiliateFee(
        address edition,
        uint256 mintId,
        uint16 affiliateFeeBPS
    ) external;

    /**
     * @dev Sets the `affiliateDiscountBPS` for (`edition`, `mintId`).
     * Calling conditions:
     * - The caller must be the current controller for (`edition`, `mintId`).
     */
    function setAffiliateDiscount(
        address edition,
        uint256 mintId,
        uint16 affiliateDiscountBPS
    ) external;

    /**
     * @dev Sets the `platformFeePBS`.
     * Calling conditions:
     * - The caller must be the owner of the contract.
     */
    function setPlatformFee(uint16 platformFeeBPS_) external;

    /**
     * @dev Withdraws all the accrued funds for the `affiliate`.
     */
    function withdrawForAffiliate(address affiliate) external;

    /**
     * @dev Withdraws all the accrued funds for the platform.
     */
    function withdrawForPlatform(address to) external;

    // ================================
    // VIEW FUNCTIONS
    // ================================

    function price(address edition, uint256 mintId) external view returns (uint256);

    function maxMintable(address edition, uint256 mintId) external view returns (uint32);

    function maxAllowedPerWallet(address edition, uint256 mintId) external view returns (uint32);

    /**
     * @dev Returns whether `affiliate` is a valid affiliate for (`edition`, `mintId`).
     * Child contracts may override this function to provide a custom logic.
     */
    function isAffiliated(
        address edition,
        uint256 mintId,
        address affiliate
    ) external view returns (bool);

    /**
     * @dev Returns the discounted price for affiliated purchases.
     */
    function affiliatedPrice(
        address edition,
        uint256 mintId,
        uint256 originalPrice,
        address affiliate
    ) external view returns (uint256);

    /**
     * @dev Returns the next mint ID for `edition`.
     */
    function nextMintId(address edition) external view returns (uint256);

    /**
     * @dev Returns the configuration data for an edition mint.
     */
    function baseMintData(address edition, uint256 mintId) external view returns (BaseData memory);
}
