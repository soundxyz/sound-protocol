// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { OwnableRoles } from "solady/auth/OwnableRoles.sol";
import { ISoundEditionV1 } from "@core/interfaces/ISoundEditionV1.sol";
import { IMinterModule } from "@core/interfaces/IMinterModule.sol";
import { ISoundFeeRegistry } from "@core/interfaces/ISoundFeeRegistry.sol";
import { IERC165 } from "openzeppelin/utils/introspection/IERC165.sol";
import { SafeTransferLib } from "solady/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "solady/utils/FixedPointMathLib.sol";

/**
 * @title Minter Base
 * @dev The `BaseMinter` class maintains a central storage record of edition mint instances.
 */
abstract contract BaseMinter is IMinterModule {
    // =============================================================
    //                           CONSTANTS
    // =============================================================

    /**
     * @dev This is the denominator, in basis points (BPS), for:
     * - platform fees
     * - affiliate fees
     */
    uint16 private constant _MAX_BPS = 10_000;

    // =============================================================
    //                            STORAGE
    // =============================================================

    /**
     * @dev The next mint ID. Shared amongst all editions connected.
     */
    uint128 private _nextMintId;

    /**
     * @dev How much platform fees have been accrued.
     */
    uint128 private _platformFeesAccrued;

    /**
     * @dev Maps an edition and the mint ID to a mint instance.
     */
    mapping(address => mapping(uint256 => BaseData)) internal _baseData;

    /**
     * @dev Maps an address to how much affiliate fees have they accrued.
     */
    mapping(address => uint128) private _affiliateFeesAccrued;

    /**
     * @dev The fee registry. Used for handling platform fees.
     */
    ISoundFeeRegistry public immutable feeRegistry;

    // =============================================================
    //                          CONSTRUCTOR
    // =============================================================

    constructor(ISoundFeeRegistry feeRegistry_) {
        if (address(feeRegistry_) == address(0)) revert FeeRegistryIsZeroAddress();
        feeRegistry = feeRegistry_;
    }

    // =============================================================
    //               PUBLIC / EXTERNAL WRITE FUNCTIONS
    // =============================================================

    /**
     * @inheritdoc IMinterModule
     */
    function setEditionMintPaused(
        address edition,
        uint128 mintId,
        bool paused
    ) public virtual onlyEditionOwnerOrAdmin(edition) {
        _baseData[edition][mintId].mintPaused = paused;
        emit MintPausedSet(edition, mintId, paused);
    }

    /**
     * @inheritdoc IMinterModule
     */
    function setTimeRange(
        address edition,
        uint128 mintId,
        uint32 startTime,
        uint32 endTime
    ) public virtual onlyEditionOwnerOrAdmin(edition) onlyValidTimeRange(startTime, endTime) {
        _baseData[edition][mintId].startTime = startTime;
        _baseData[edition][mintId].endTime = endTime;

        emit TimeRangeSet(edition, mintId, startTime, endTime);
    }

    /**
     * @inheritdoc IMinterModule
     */
    function setAffiliateFee(
        address edition,
        uint128 mintId,
        uint16 feeBPS
    ) public virtual override onlyEditionOwnerOrAdmin(edition) onlyValidAffiliateFeeBPS(feeBPS) {
        _baseData[edition][mintId].affiliateFeeBPS = feeBPS;
        emit AffiliateFeeSet(edition, mintId, feeBPS);
    }

    /**
     * @inheritdoc IMinterModule
     */
    function withdrawForAffiliate(address affiliate) public override {
        uint256 accrued = _affiliateFeesAccrued[affiliate];
        if (accrued != 0) {
            _affiliateFeesAccrued[affiliate] = 0;
            SafeTransferLib.safeTransferETH(affiliate, accrued);
        }
    }

    /**
     * @inheritdoc IMinterModule
     */
    function withdrawForPlatform() public override {
        uint256 accrued = _platformFeesAccrued;
        if (accrued != 0) {
            _platformFeesAccrued = 0;
            SafeTransferLib.safeTransferETH(feeRegistry.soundFeeAddress(), accrued);
        }
    }

    // =============================================================
    //               PUBLIC / EXTERNAL VIEW FUNCTIONS
    // =============================================================

    /**
     * @dev Getter for the max basis points.
     */
    function MAX_BPS() external pure returns (uint16) {
        return _MAX_BPS;
    }

    /**
     * @inheritdoc IMinterModule
     */
    function affiliateFeesAccrued(address affiliate) external view returns (uint128) {
        return _affiliateFeesAccrued[affiliate];
    }

    /**
     * @inheritdoc IMinterModule
     */
    function platformFeesAccrued() external view returns (uint128) {
        return _platformFeesAccrued;
    }

    /**
     * @inheritdoc IMinterModule
     */
    function isAffiliated(
        address, /* edition */
        uint128, /* mintId */
        address affiliate
    ) public view virtual override returns (bool) {
        return affiliate != address(0);
    }

    /**
     * @inheritdoc IMinterModule
     */
    function nextMintId() public view returns (uint128) {
        return _nextMintId;
    }

    /**
     * @inheritdoc IERC165
     */
    function supportsInterface(bytes4 interfaceId) public view virtual returns (bool) {
        return interfaceId == type(IMinterModule).interfaceId || interfaceId == this.supportsInterface.selector;
    }

    /**
     * @inheritdoc IMinterModule
     */
    function totalPrice(
        address edition,
        uint128 mintId,
        address to,
        uint32 quantity
    ) public view virtual override returns (uint128);

    // =============================================================
    //                  INTERNAL / PRIVATE HELPERS
    // =============================================================

    /**
     * @dev Restricts the function to be only callable by the owner or admin of `edition`.
     * @param edition The edition address.
     */
    modifier onlyEditionOwnerOrAdmin(address edition) virtual {
        if (
            msg.sender != OwnableRoles(edition).owner() &&
            !OwnableRoles(edition).hasAnyRole(msg.sender, ISoundEditionV1(edition).ADMIN_ROLE())
        ) revert Unauthorized();

        _;
    }

    /**
     * @dev Restricts the start time to be less than the end time.
     * @param startTime The start time of the mint.
     * @param endTime The end time of the mint.
     */
    modifier onlyValidTimeRange(uint32 startTime, uint32 endTime) virtual {
        if (startTime >= endTime) revert InvalidTimeRange();
        _;
    }

    /**
     * @dev Restricts the affiliate fee numerator to not exceed the `MAX_BPS`.
     */
    modifier onlyValidAffiliateFeeBPS(uint16 affiliateFeeBPS) virtual {
        if (affiliateFeeBPS > _MAX_BPS) revert InvalidAffiliateFeeBPS();
        _;
    }

    /**
     * @dev Creates an edition mint instance.
     * @param edition The edition address.
     * @param startTime The start time of the mint.
     * @param endTime The end time of the mint.
     * @param affiliateFeeBPS The affiliate fee in basis points.
     * @return mintId The ID for the mint instance.
     * Calling conditions:
     * - Must be owner or admin of the edition.
     */
    function _createEditionMint(
        address edition,
        uint32 startTime,
        uint32 endTime,
        uint16 affiliateFeeBPS
    )
        internal
        onlyEditionOwnerOrAdmin(edition)
        onlyValidTimeRange(startTime, endTime)
        onlyValidAffiliateFeeBPS(affiliateFeeBPS)
        returns (uint128 mintId)
    {
        mintId = _nextMintId;

        BaseData storage data = _baseData[edition][mintId];
        data.startTime = startTime;
        data.endTime = endTime;
        data.affiliateFeeBPS = affiliateFeeBPS;

        _nextMintId = mintId + 1;

        emit MintConfigCreated(edition, msg.sender, mintId, startTime, endTime, affiliateFeeBPS);
    }

    /**
     * For avoiding stack too deep.
     */
    struct _MintTemps {
        uint256 requiredEtherValue;
        uint256 payment;
        bool affiliated;
        uint256 affiliateFee;
        uint256 remainingPayment;
        uint256 platformFee;
    }

    /**
     * @dev Mints `quantity` of `edition` to `to` with a required payment of `requiredEtherValue`.
     * Note: this function should be called at the end of a function due to it refunding any
     * excess ether paid, to adhere to the checks-effects-interactions pattern.
     * Otherwise, a reentrancy guard must be used.
     * @param edition   The edition address.
     * @param mintId    The ID for the mint instance.
     * @param to        The address to mint to.
     * @param quantity  The quantity of tokens to mint.
     * @param affiliate The affiliate (referral) address.
     * @param tip       The amount of tip.
     */
    function _mint(
        address edition,
        uint128 mintId,
        address to,
        uint32 quantity,
        address affiliate,
        uint256 tip
    ) internal {
        BaseData storage baseData = _baseData[edition][mintId];
        _MintTemps memory t;
        t.payment = msg.value - tip; // Reverts if underflow.

        /* --------------------- GENERAL CHECKS --------------------- */
        {
            uint32 startTime = baseData.startTime;
            uint32 endTime = baseData.endTime;
            if (block.timestamp < startTime) revert MintNotOpen(block.timestamp, startTime, endTime);
            if (block.timestamp > endTime) revert MintNotOpen(block.timestamp, startTime, endTime);
            if (baseData.mintPaused) revert MintPaused();
        }

        /* ----------- AFFILIATE AND PLATFORM FEES LOGIC ------------ */

        t.requiredEtherValue = totalPrice(edition, mintId, to, quantity);

        // Reverts if the payment is not sufficient.
        unchecked {
            if (t.payment < t.requiredEtherValue) revert Underpaid(t.payment, t.requiredEtherValue);
        }

        (t.remainingPayment, t.platformFee) = _deductPlatformFee(uint128(t.requiredEtherValue));

        // Check if the mint is an affiliated mint.
        t.affiliated = isAffiliated(edition, mintId, affiliate);

        unchecked {
            if (t.affiliated) {
                // Compute the affiliate fee.
                // Won't overflow, as `remainingPayment` from `_deductPlatformFee` is 128 bits,
                // and `affiliateFeeBPS` is 16 bits.
                t.affiliateFee = (t.remainingPayment * uint256(baseData.affiliateFeeBPS)) / uint256(_MAX_BPS);
                // Deduct the affiliate fee from the remaining payment.
                // Won't underflow as `affiliateFee <= remainingPayment`.
                t.remainingPayment -= t.affiliateFee;
                // Increment the affiliate fees accrued.
                // Overflow is incredibly unrealistic.
                _affiliateFeesAccrued[affiliate] += uint128(t.affiliateFee);
            }
        }

        /* ------------------------- MINT --------------------------- */

        // Emit the event.
        emit Minted(
            edition,
            mintId,
            to,
            // Need to put this call here to avoid stack-too-deep error (it returns fromTokenId)
            uint32(ISoundEditionV1(edition).mint{ value: t.remainingPayment }(to, quantity)),
            quantity,
            uint128(t.requiredEtherValue),
            uint128(t.platformFee),
            uint128(t.affiliateFee),
            affiliate,
            t.affiliated,
            tip
        );

        /* ------------------------- REFUND ------------------------- */

        unchecked {
            // Note: We do this at the end to avoid creating a reentrancy vector.
            // Refund the caller any ETH they spent over the current total price of the NFTs.
            // Note that refunds are always to the caller, not the address
            // which the NFTs are minted to.
            if (t.payment > t.requiredEtherValue) {
                SafeTransferLib.safeTransferETH(msg.sender, t.payment - t.requiredEtherValue);
            }
        }
    }

    /**
     * @dev Deducts the platform fee from `requiredEtherValue`.
     * @param requiredEtherValue The amount of Ether required.
     * @return remainingPayment  The remaining payment Ether amount.
     * @return platformFee       The platform fee.
     */
    function _deductPlatformFee(uint128 requiredEtherValue)
        internal
        returns (uint128 remainingPayment, uint128 platformFee)
    {
        unchecked {
            // Compute the platform fee.
            platformFee = feeRegistry.platformFee(requiredEtherValue);
            // Increment the platform fees accrued.
            // Overflow is incredibly unrealistic.
            _platformFeesAccrued += platformFee;
            // Deduct the platform fee.
            // Won't underflow as `platformFee <= requiredEtherValue`;
            remainingPayment = requiredEtherValue - platformFee;
        }
    }

    /**
     * @dev Increments `totalMinted` with `quantity`, reverting if `totalMinted + quantity > maxMintable`.
     * @param totalMinted The current total number of minted tokens.
     * @param maxMintable The maximum number of mintable tokens.
     * @return `totalMinted` + `quantity`.
     */
    function _incrementTotalMinted(
        uint32 totalMinted,
        uint32 quantity,
        uint32 maxMintable
    ) internal pure returns (uint32) {
        unchecked {
            // Won't overflow as both are 32 bits.
            uint256 sum = uint256(totalMinted) + uint256(quantity);
            if (sum > maxMintable) {
                // Note that the `maxMintable` may vary and drop over time
                // and cause `totalMinted` to be greater than `maxMintable`.
                // The `zeroFloorSub` is equivalent to `max(0, x - y)`.
                uint32 available = uint32(FixedPointMathLib.zeroFloorSub(maxMintable, totalMinted));
                revert ExceedsAvailableSupply(available);
            }
            return uint32(sum);
        }
    }
}
