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
    /**
     * @notice Defines details of each share collection for investors.
     */
    struct TIExShareCollection {
        /// @notice Indicates the maximum share supply.
        uint256 maxSupply;
        /// @notice Indicates the total investment in the share
        uint256 totalInvestment;
        /// @notice Indicates the amount that has been withdrawn.
        uint256 withdrawnAmount;
        /// @notice Indicates the price per share.
        uint256 price;
        /// @notice Indicates the time when the share collection was launched.
        uint256 launchStartTime;
        /// @notice Indicates the maximum share purchase allowed per account.
        uint256 maxSharePurchase;
        /// @notice Indicates whether the sale is paused or not.
        bool paused;
        /// @notice Indicates whether the share collection is available for
        /// trading and share sale or not.
        bool blocked;
        /// @notice Indicates whether the share collection is only available
        /// for U.S. investors or not.
        bool forOnlyUSInvestors;
    }

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

    /// @notice Emitted when a share collection is released for a specific model.
    /// It provides the model ID and the share collection object as parameters.
    event TIExShareCollectionReleased(
        uint256 indexed modelId,
        TIExShareCollection shareCollection
    );

    /// @notice Emitted when the URI associated with a model is updated.
    event TIExCollectionURIUpdated(uint256 indexed modelId, string uri);

    /// @notice Emitted when the share collection for the detail of model is updated.
    event TIExShareCollectionUpdated(
        uint256 indexed modelId,
        TIExShareCollection newShareCollection
    );

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

    /// @notice The token name
    function name() external view returns (string memory);

    /// @notice The token symbol
    function symbol() external view returns (string memory);

    /// @notice The truth holder (TIEx Signer for generating ECDSA Signature)
    function truthHolder() external view returns (address);

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
    function utility() external view returns (IUtility);

    /// @notice TIExBaseIPAllocation
    function tiexBaseIPAllocation() external view returns (IAssets);

    /**
     * @notice Used to clean up data related to a model after it has been removed.
     * @param __modelId uint256 The ID of the model associated with the Share Collection.
     *
     * Requirements:
     * - Must be called by TIExBaseIPAllocation contract.
     */
    function afterRemoveModel(uint256 __modelId) external;

    /**
     * @notice Used to release a new Share Collection.
     * @param __maxSupply uint256 The maximum supply of shares for the collection.
     * @param __modelId uint256 The ID of the model associated with the Share Collection.
     * @param __price uint256 The price of each share in the collection.
     * @param __maxSharePurchase uint256 The maximum number of shares that can be purchased per account.
     * @param __forOnlyUSInvestors bool Indicates whether the Share Collection is only available to U.S. investors.
     *
     * Emits a {TIExShareCollectionReleased} event.
     *
     * Requirements:
     *
     * - Must be called by an address with the `DEFAULT_ADMIN_ROLE` role.
     * - A shared collection with the given `__modelId` must not already exist.
     * - The model with the given `__modelId` must exist.
     * - `__maxSupply` must be greater than 0.
     * - `__price` must be greater than 0.
     * - `__maxSharePurchase` must be greater than 0.
     */
    function releaseShareCollection(
        uint256 __maxSupply,
        uint256 __modelId,
        uint256 __price,
        uint256 __maxSharePurchase,
        bool __forOnlyUSInvestors
    ) external;

    /**
     * @notice Distributes funds from investor
     */
    function distribute(uint256 __modelId) external;

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

    /**
     * @notice Updates the address of truth holder, which is responsible for generating and
     * signing ECDSA singatures for rquested messages from investors.
     *
     * Emits a {TIExTruthHolderUpdated} event.
     *
     * Requirements:
     *
     * - Must be called by an account with the `DEFAULT_ADMIN_ROLE` role.
     * - `__truthHolder` address must not be the zero address(address(0)) or the same as the
     * current truth holder address.
     */
    function updateTruthHolder(address __truthHolder) external;

    /**
     * @notice Update investment distribution rates.
     * @param __creatorRate uint256 The rate for the creators.
     * @param __marketingRate uint256 The rate for theh marketing.
     * @param __presaleRate uint256 The rate for the presale.
     * @param __reserveRate uint256 The rate for the reserve.
     *
     * Emits a {TIExInvestmentDistributionRate} event.
     *
     * Requirements:
     *
     * - `__creatorRate` + `__marketingRate` + `__presaleRate` + `__reserveRate` must be equal to 10000 (100%).
     * - `__creatorRate` must not be less than 2000 (20%).
     * - Must be called by an account with the `DEFAULT_ADMIN_ROLE` role.
     */
    function updateInvestmentDistributionRate(
        uint256 __creatorRate,
        uint256 __marketingRate,
        uint256 __presaleRate,
        uint256 __reserveRate
    ) external;

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

    /**
     * @notice Pauses the selling of shares for the share collection with a specific `__modelId`.
     * @param __modelId uint256 The model id
     *
     * Emits a {TIExShareCollectionPaused} event.
     *
     * Requirements:
     *
     * - Must be called by an account with the `DEFAULT_ADMIN_ROLE` role.
     * - The share collection with the given `__modelId` must exist.
     *
     * WARNING: If the share collection is already paused, the function will throw an error.
     */
    function setPause(uint256 __modelId) external;

    /**
     * @notice Unpauses the selling of shares for the share collection with a specific `__modelId`.
     * @param __modelId uint256 The model id
     *
     * Emits a {TIExShareCollectionUnpaused} event.
     *
     * Requirements:
     *
     * - Must be called by an account with the `DEFAULT_ADMIN_ROLE` role.
     * - The share collection with the given `__modelId` must exist.
     *
     * WARNING: If the share collection is already unpaused, the function will throw an error.
     */
    function setUnpause(uint256 __modelId) external;

    /**
     * @notice Blocks a share collection
     * @param __modelId uint256 The model id.
     *
     * Emits a {TIExShareCollectionBlocked} event.
     *
     * Requirements:
     *
     * - Must be called by an account with the `DEFAULT_ADMIN_ROLE` role.
     * - The share collection with the given `__modelId` must exist.
     * WARNING: If the share collection is already blocked, the function will throw an error.
     */
    function setBlock(uint256 __modelId) external;

    /**
     * @notice Unblocks a share collection
     * @param __modelId uint256 The model id.
     *
     * Emits a {TIExShareCollectionUnblocked} event.
     *
     * Requirements:
     *
     * - Must be called by an account with the `DEFAULT_ADMIN_ROLE` role.
     * - The share collection with the given `__modelId` must exist.
     * WARNING: If the share collection is already unblocked, the function will throw an error.
     */
    function setUnblock(uint256 __modelId) external;

    /**
     * @notice Updates the price per share for a specific share collection.
     * @param __modelId uint256 The model id.
     * @param __price uint256 The price per share.
     *
     * Emits a {TIExSharePriceUpdated} event.
     *
     * Requirements:
     *
     * - Must be called by an account with the `DEFAULT_ADMIN_ROLE` role.
     * - The share collection with the given `__modelId` must exist.
     * - `__price` must not be zero.
     *
     * WARNING: If `__price` is equal to the current price, it reverts with
     * an `ErrorInvalidParam` error.
     */
    function updateSharePrice(uint256 __modelId, uint256 __price) external;

    /**
     * @notice Updates maximum supply of a share collection.
     * @param __modelId uint256 The model id.
     * @param __maxSupply uint256 The maximum supply.
     *
     * Emits a {TIExMaxSupplyUpdated} event.
     *
     * Requirements:
     *
     * - Must be called by an account with the `DEFAULT_ADMIN_ROLE` role.
     * - The share collection with the given `__modelId` must exist.
     * - `__maxSupply` must not be zero.
     *
     * WARNING: If `__maxSupply` is equal to the current maximum supply, it reverts with
     * an `ErrorInvalidParam` error.
     */
    function updateMaxSupply(uint256 __modelId, uint256 __maxSupply) external;

    /**
     * @notice Updates maximum share purchase allowed per account.
     * @param __modelId uint256 The model id.
     * @param __maxSharePurchase uint256 The maximum share purchase allowed per account.
     *
     * Emits a {TIExMaxSharePurchaseUpdated} event.
     *
     * Requirements:
     *
     * - Must be called by an account with the `DEFAULT_ADMIN_ROLE` role.
     * - The share collection with the given `__modelId` must exist.
     * - `__maxSharePurchase` must not be zero.
     *
     * WARNING: If `__maxSharePurchase` is equal to the current maximum share purchase, it reverts with
     * an `ErrorInvalidParam` error.
     */
    function updateMaxSharePurchase(
        uint256 __modelId,
        uint256 __maxSharePurchase
    ) external;

    /**
     * @notice Updates the available position for investors
     * @param __modelId uint256 The model id.
     * @param __forOnlyUSInvestors bool Indicates whether the Share Collection is only available to U.S. investors.
     *
     * Emits a {TIExShareCollectionInvestorPositionUpdated} event.
     *
     * Requirements:
     *
     * - Must be called by an account with the `DEFAULT_ADMIN_ROLE` role.
     * - The share collection with the given `__modelId` must exist.
     * - the `__forOnlyUSInvestors` parameter must not be the same as the current value of `forOnlyUSInvestors` in the share collection
     */
    function updateInvestorPosition(
        uint256 __modelId,
        bool __forOnlyUSInvestors
    ) external;

    /**
     * @notice Resumes operating the platform
     *
     * Requirements:
     *
     * - Must be called by an account with the `DEFAULT_ADMIN_ROLE` role.
     */
    function resume() external;

    /**
     * @notice Pauses operating the platform
     *
     * Requirements:
     *
     * - Must be called by an account with the `DEFAULT_ADMIN_ROLE` role.
     */
    function emergency() external;

    /**
     * @notice Returns whether or not an shareCollection exists.
     */
    function shareCollectionExists(
        uint256 __modelId
    ) external view returns (bool);

    /**
     * @notice Returns an Share Collection Status.
     */
    function shareCollection(
        uint256 __modelId
    ) external view returns (TIExShareCollection memory, IAssets.Asset memory);
}
