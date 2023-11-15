// SPDX-License-Identifier: MIT

/*.----------------.  .----------------.  .----------------.  .----------------. 
        | .--------------. || .--------------. || .--------------. || .--------------. |
        | |  _________   | || |     _____    | || |  _________   | || |  ____  ____  | |
        | | |  _   _  |  | || |    |_   _|   | || | |_   ___  |  | || | |_  _||_  _| | |
        | | |_/ | | \_|  | || |      | |     | || |   | |_  \_|  | || |   \ \  / /   | |
        | |     | |      | || |      | |     | || |   |  _|  _   | || |    > `' <    | |
        | |    _| |_     | || |     _| |_    | || |  _| |___/ |  | || |  _/ /'`\ \_  | |
        | |   |_____|    | || |    |_____|   | || | |_________|  | || | |____||____| | |
        | |              | || |              | || |              | || |              | |
        | '--------------' || '--------------' || '--------------' || '--------------' |
        '----------------'  '----------------'  '----------------'  '----------------' */

pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import "./IAssets.sol";
import "./IUtility.sol";

// Interface for payment token
interface IPaymentToken is IERC20, IERC20Permit {

}

interface IAssetsRevenue {
    // TODO: revise same as assets

    /**
     * @notice Defines the distribution rates and addresses for different aspects
     * of an investment.
     */
    struct InvestmentDistribution {
        /// @notice Indicates the rate of investment distribution for the creator.
        uint256 creatorRate;
        /// @notice Indicates the rate of investment distribution for marketing.
        uint256 marketingtRate;
        /// @notice Indicates the rate of investment distribution for reserves.
        uint256 reserveRate;
        /// @notice Indicates the rate of investment distribution for presale.
        uint256 presaleRate;
        /// @notice Indicates the address where the marketing funds will be distributed.
        address marketing;
        /// @notice Indicates the address where the reserve funds will be distributed.
        address reserve;
        /// @notice Indicates the address where the presale funds will be distributed.
        address presale;
    }

    /// @notice Indicates that a share collection cannot be found
    error ErrorShareCollectionNotFound(uint256 modelId);

    /// @notice Indicates that a share collection with the specified
    /// model ID has already been released.
    error ErrorTIExShareCollectionReleasedAlready(uint256 modelId);

    /// @notice Indicates that there is not enough supply available for share sale.
    error ErrorNotEnoughSupply();

    /// @notice Indicates that a share collection with the specified model ID has been
    /// paused and is currently not available.
    error ErrorShareCollectionPaused(uint256 modelId);

    /// @notice Indicates that the share collection with the specified model ID is blocked.
    error ErrorShareCollectionBlocked(uint256 modelId);

    /// @notice Indicates that the TIEx is currently paused.
    error ErrorTIExPaused();

    /// @notice Indicates that the maximum limit for share purchases has been exceeded.
    error ErrorExceedMaxSharePurchase();

    /// @notice Indicates that the signature provided for authentication or verification
    /// purposes is invalid or cannot be verified.
    error ErrorInvalidSignature();

    /// @notice Indicates that one or more parameters provided in the request are invalid or missing.
    error ErrorInvalidParam();

    /// @notice Indicates that the provided nonce (a unique identifier) is invalid or has already been used.
    error ErrorInvalidNonce();

    // @notice Indicates that the deadline for a certain operation has been reached.
    error ErrorDeadlineReached();

    // @notice Indicates that the msg.sender() is invalid
    error ErrorInvalidMsgSender();

    /// @notice Emitted when the URI associated with a model is updated.
    event TIExCollectionURIUpdated(uint256 indexed modelId, string uri);

    /// @notice Emitted when the payment token used in the contract is updated.
    event TIExPaymentTokenUpdated(IPaymentToken newPaymentToken);

    /// @notice Emitted when the truth holder address is updated.
    event TIExTruthHolderUpdated(address newTruthHolder);

    /// @notice Emitted when the price of a share for a specific model is updated.
    event TIExSharePriceUpdated(uint256 indexed modelId, uint256 newPrice);

    /// @notice Emitted when the maximum supply of shares for a model is updated.
    event TIExMaxSupplyUpdated(uint256 indexed modelId, uint256 newMaxSupply);

    /// @notice Emitted when the maximum share purchase limit for a model is updated.
    event TIExMaxSharePurchaseUpdated(
        uint256 indexed modelId,
        uint256 newMaxSharePurchase
    );

    /// @notice Emitted when a share collection for a model is blocked or disabled.
    event TIExShareCollectionBlocked(uint256 indexed modelId);

    /// @notice Emitted when a previously blocked share collection for a model is unblocked or enabled.
    event TIExShareCollectionUnblocked(uint256 indexed modelId);

    /// @notice Emitted when a share collection for a model is paused.
    event TIExShareCollectionPaused(uint256 indexed modelId);

    /// @notice Emitted when a previously paused share collection for a model is unpaused.
    event TIExShareCollectionUnpaused(uint256 indexed modelId);

    /// @notice Emitted when the investor position of share collection is updated.
    /// e.g. U.S. investor => Non-U.S. investor or Non-U.S. investor => U.S. Investor
    event TIExShareCollectionInvestorPositionUpdated(
        uint256 indexed modelId,
        bool newInvestorPosition
    );

    /// @notice Emitted when the investment distribution rate is updated.
    event TIExInvestmentDistributionRate(
        InvestmentDistribution newInvestmentDistribution
    );

    /// @notice Emitted when the marketing address is update.
    event TIExMarketingAddressUpdated(address newMarketingAddress);

    /// @notice Emitted when the presale address is updated.
    event TIExPresaleAddressUpdated(address newPresaleAddress);

    /// @notice Emitted when reserve address is updated.
    event TIExReserveAddressUpdated(address newReserveAddress);

    /// @notice Emitted when Utility contract address is updated.
    event TIExUtilityUpdated(IUtility utility);

    /// @notice Emitted when distributing funds fromm investors to creators, marketing etc.
    event Distribute(uint256 indexed modelId, uint256 amount, uint256 when);

    /// @notice The payment token (ERC20: INTELL token)
    function paymentToken() external view returns (IPaymentToken);

    /// @notice Investment distribution rates and addresses
    function investmentDistribution()
        external
        view
        returns (
            uint256 creatorRate,
            uint256 marketingtRate,
            uint256 reserveRate,
            uint256 presaleRate,
            address marketing,
            address reserve,
            address presale
        );

    /// @notice Utility
    function utilityContract() external view returns (IUtility);

    /// @notice TIExBaseIPAllocation
    function assetsContract() external view returns (IAssets);

    // /**
    //  * @notice Distributes funds from investor
    //  */
    // function distribute(uint256 __modelId) external;

    /**
     * @notice Updates the Utiltity address.
     * @param __utility IUtility
     *
     * Emits a {TIExUtilityUpdated} event.
     *
     * Requirements:
     *
     * - Must be called by an account with the `DEFAULT_ADMIN_ROLE` role.
     * - `__utility` IUtility must not be the zero address(address(0))
     */
    function updateUtility(IUtility __utility) external;

    // /**
    //  * @notice Update investment distribution rates.
    //  * @param __creatorRate uint256 The rate for the creators.
    //  * @param __marketingRate uint256 The rate for theh marketing.
    //  * @param __presaleRate uint256 The rate for the presale.
    //  * @param __reserveRate uint256 The rate for the reserve.
    //  *
    //  * Emits a {TIExInvestmentDistributionRate} event.
    //  *
    //  * Requirements:
    //  *
    //  * - `__creatorRate` + `__marketingRate` + `__presaleRate` + `__reserveRate` must be equal to 10000 (100%).
    //  * - `__creatorRate` must not be less than 2000 (20%).
    //  * - Must be called by an account with the `DEFAULT_ADMIN_ROLE` role.
    //  */
    // function updateInvestmentDistributionRate(
    //     uint256 __creatorRate,
    //     uint256 __marketingRate,
    //     uint256 __presaleRate,
    //     uint256 __reserveRate
    // ) external;

    /**
     * @notice Updates the marketing address.
     * @param __marketing address The address where the marketing funds will be distributed.
     *
     * Emits a {TIExMarketingAddressUpdated} event.
     *
     * Requirements:
     *
     * - Must be called by an account with the `DEFAULT_ADMIN_ROLE` role.
     * - `__marketing` address must not be the zero address(address(0)) or the same as the
     * current truth holder address.
     */
    function updateMarketingAddress(address __marketing) external;

    /**
     * @notice Updates the presale address.
     * @param __presale address The address where the presale funds will be distributed.
     *
     * Emits a {TIExPresaleAddressUpdated} event.
     *
     * Requirements:
     *
     * - Must be called by an account with the `DEFAULT_ADMIN_ROLE` role.
     * - `__presale` address must not be the zero address(address(0))
     */
    function updatePresaleAddress(address __presale) external;

    /**
     * @notice Updates the reserve address.
     * @param __reserve address The address where the reserve funds will be distributed.
     *
     * Emits a {TIExReserveAddressUpdated} event.
     *
     * Requirements:
     *
     * - Must be called by an account with the `DEFAULT_ADMIN_ROLE` role.
     * - `__reserve` address must not be the zero address(address(0))
     */
    function updateReserveAddress(address __reserve) external;

    /**
     * @notice Updates the payment token address.
     * @param __paymentToken address The address for ERC20 token used as utility token on TIEx.
     *
     * Emits a {TIExPaymentTokenUpdated} event.
     *
     * Requirements:
     *
     * - Must be called by an account with the `DEFAULT_ADMIN_ROLE` role.
     * - `__paymentToken` address must not be the zero address(address(0))
     */
    function updatePaymentToken(IPaymentToken __paymentToken) external;
}
