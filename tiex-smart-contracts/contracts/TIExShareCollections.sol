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

pragma solidity ^0.8.21;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

import "./TIExBaseIPAllocationUpgradeable.sol";

interface IPaymentToken is IERC20, IERC20Permit { }

contract TIExShareCollections is
    Initializable,
    ERC1155Upgradeable,
    ERC1155BurnableUpgradeable,
    ERC1155SupplyUpgradeable,
    PausableUpgradeable,
    TIExBaseIPAllocationUpgradeable
{
    using Strings for uint256;
    using SafeMath for uint256;
    using SafeERC20 for IPaymentToken;

    uint256 constant MAX_INT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

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

    /// @notice Indicates that the specified country is not valid. Identifies investors
    /// and non-U.S. investors here
    error ErrorInvalidCountry();

    /// @notice Indicates that one or more parameters provided in the request are invalid or missing.
    error ErrorInvalidParam();

    /// @notice Indicates that the provided nonce (a unique identifier) is invalid or has already been used.
    error ErrorInvalidNonce();

    /// @notice Emitted when a share collection is released for a specific model.
    /// It provides the model ID and the share collection object as parameters.
    event TIExShareCollectionReleased(
        uint256 indexed modelId,
        TIExShareCollection indexed shareCollection
    );

    /// @notice Emitted when the URI associated with a model is updated.
    event TIExCollectionURIUpdated(
        uint256 indexed modelId,
        string indexed uri
    );

    /// @notice Emitted when the share collection for the detail of model is updated.
    event TIExShareCollectionUpdated(
        uint256 indexed modelId,
        TIExShareCollection indexed oldShareCollection,
        TIExShareCollection indexed newShareCollection
    );

    /// @notice Emitted when the payment token used in the contract is updated.
    event TIExPaymentTokenUpdated(
        IPaymentToken indexed oldPaymentToken,
        IPaymentToken indexed newPaymentToken
    );

    /// @notice Emitted when the truth holder address is updated.
    event TIExTruthHolderUpdated(
        address indexed oldTruthHolder,
        address indexed newTruthHolder
    );

    /// @notice Emitted when the price of a share for a specific model is updated.
    event TIExSharePriceUpdated(
        uint256 indexed modelId,
        uint256 indexed oldPrice,
        uint256 indexed newPrice
    );

    /// @notice Emitted when the maximum supply of shares for a model is updated.
    event TIExMaxSupplyUpdated(
        uint256 indexed modelId,
        uint256 indexed oldMaxSupply,
        uint256 indexed newMaxSupply
    );

    /// @notice Emitted when the maximum share purchase limit for a model is updated.
    event TIExMaxSharePurchaseUpdated(
        uint256 indexed modelId,
        uint256 indexed oldMaxSharePurchase,
        uint256 indexed newMaxSharePurchase
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
        bool indexed oldInvestorPosition,
        bool indexed newInvestorPosition
    );

    /// @notice Emitted when the investment distribution rate is updated.
    event TIExInvestmentDistributionRate(
        InvestmentDistribution indexed oldInvestmentDistribution,
        InvestmentDistribution indexed newInvestmentDistribution
    );

    /// @notice Emitted when the marketing address is update.
    event TIExMarketingAddressUpdated(
        address indexed oldMarketingAddress,
        address indexed newMarketingAddress
    );

    /// @notice Emitted when the presale address is updated.
    event TIExPresaleAddressUpdated(
        address indexed oldPresaleAddress,
        address indexed newPresaleAddress
    );

    /// @notice Emitted when reserve address is updated.
    event TIExReserveAddressUpdated(
        address indexed oldReserveAddress,
        address indexed newReserveAddress
    );

    /// @notice Emitted when distributing funds fromm investors to creators, marketing etc.
    event Distribute(uint256 modelId, uint256 indexed amount, uint256 indexed when);

    /// @notice The token name
    string public name;

    /// @notice The token symbol
    string public symbol;

    /// @notice Mapping of share collctions
    mapping(uint256 => TIExShareCollection) private _shareCollections;

    /// @notice Mapping of share collection released
    mapping(uint256 => bool) private _shareCollectionExists;

    /// @notice Mapping the number of shares purchased per account in every share collection
    mapping(uint256 => mapping(address => uint256)) public purchasedPerAccount;

    /// @notice The truth holder (TIEx Signer for generating ECDSA Signature)
    address public truthHolder;

    /// @notice The payment token (ERC20: INTELL token)
    IPaymentToken public paymentToken;

    /// @notice Mapping of nonces used
    mapping(uint256 => bool) public noncesUsed;

    /// @notice Investment distribution rates and addresses
    InvestmentDistribution public investmentDistribution;

    /**
     * @notice Defines the initialize function, which sets the name, symbol,
     * truth holder, payment token, and investment distribution for the token when deploying Proxy.
     * It also grants the initial roles to the owner upon construction.
     */
    function initialize(
        address __truthHolder,
        IPaymentToken __paymentToken,
        address __admin,
        InvestmentDistribution memory __investmentDistribution
    ) public virtual initializer {
        uint256 _tRate = __investmentDistribution
            .creatorRate
            .add(__investmentDistribution.marketingtRate)
            .add(__investmentDistribution.presaleRate)
            .add(__investmentDistribution.reserveRate);

        if (_tRate != 10000) revert ErrorInvalidParam();

        name = "TIEx Share Collections";
        symbol = "TIExSHARE";

        truthHolder = __truthHolder;
        paymentToken = __paymentToken;

        investmentDistribution = __investmentDistribution;

        __TIExBaseIPAllocation_init();
        __Context_init_unchained();
        __ERC165_init_unchained();
        __ERC1155_init_unchained("");
        __ERC1155Burnable_init_unchained();
        __Pausable_init_unchained();
        __TIExBaseIPAllocation_init_unchained();

        _grantRole(DEFAULT_ADMIN_ROLE, __admin);
    }

    ////////////////////////////////////////////////////////////////////////////
    // MODIFIERS
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Modifier that checks if a Share Collection with the given modelId is not paused.
     * @param __modelId The modelId of the Share Collection to check.
     */
    modifier whenShareCollectionNotPaused(uint256 __modelId) {
        if (_shareCollections[__modelId].paused) {
            revert ErrorShareCollectionPaused(__modelId);
        }
        _;
    }

    /**
     * @notice Modifier that checks if a Share Collection with the given modelId exists.
     * @param __modelId The modelId of the Share Collection to check.
     */
    modifier onlyExistingShareCollection(uint256 __modelId) {
        if (!shareCollectionExists(__modelId)) {
            revert ErrorShareCollectionNotFound(__modelId);
        }
        _;
    }

    /**
     * @notice Modifier that checks if a Share Collection with the given modelId doesn't exist.
     * @param __modelId The modelId of the Share Collection to check.
     */
    modifier onlyNotExistingShareCollection(uint256 __modelId) {
        if (shareCollectionExists(__modelId)) {
            revert ErrorTIExShareCollectionReleasedAlready(__modelId);
        }
        _;
    }

    ////////////////////////////////////////////////////////////////////////////
    // INTERNALS
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Internal function that overrides two functions, "ERC1155Upgradeable._beforeTokenTransfer" and 
     * "ERC1155SupplyUpgradeable._beforeTokenTransfer".
     * 
     * NOTE: The purpose of this function is to perform some checks before transferring tokens from one address to 
     * another. 
     *
     * Here's a breakdown of what the function does:
     * 1. It calls the "_beforeTokenTransfer" function from the parent contracts, "ERC1155Upgradeable" and 
     * "ERC1155SupplyUpgradeable", passing the provided arguments.
     * 2. It checks if the recipient address (__to) is not the zero address (address(0)). 
     * 3. If it is not the zero address, it proceeds with the following checks:
     * It iterates over the __modelIds array using a for loop. For each modelId, it performs the following checks:
     * - It checks if the Share Collection with the given modelId is blocked by accessing the "blocked" property of the 
     * Share Collection in the "_shareCollections" mapping. If it is blocked, it reverts the transaction with an error 
     * using the "ErrorShareCollectionBlocked" function, passing the modelId as an argument.
     * - It checks if the Share Collection with the given modelId exists by calling the "shareCollectionExists" 
     * function. If it doesn't exist, it reverts the transaction with an error using the "ErrorShareCollectionNotFound" 
     * function, passing the modelId as an argument.
     * - It checks if the contract is paused by calling the "paused" function. If it is paused, it reverts the 
     * transaction with an error using the "ErrorTIExPaused" function.

     * Overall, this function ensures that certain conditions are met before transferring tokens, such as checking if 
     * the Share Collection is blocked, if it exists, and if the contract is paused.
     */
    function _beforeTokenTransfer(
        address __operator,
        address __from,
        address __to,
        uint256[] memory __modelIds,
        uint256[] memory __amounts,
        bytes memory __data
    ) internal virtual override(ERC1155Upgradeable, ERC1155SupplyUpgradeable) {
        super._beforeTokenTransfer(
            __operator,
            __from,
            __to,
            __modelIds,
            __amounts,
            __data
        );

        if (__to != address(0)) {
            for (uint256 i = 0; i < __modelIds.length; i++) {
                if (_shareCollections[__modelIds[i]].blocked)
                    revert ErrorShareCollectionBlocked(__modelIds[i]);
                if (!shareCollectionExists(__modelIds[i]))
                    revert ErrorShareCollectionNotFound(__modelIds[i]);
                if (paused()) revert ErrorTIExPaused();
            }
        }
    }

    /**
     * @notice See { TIExBaseIPAllocationUpgradeable } 
     * 
     * Internal function that overrides the `TIExBaseIPAllocationUpgradeable` contract's `_afterRemoveModel` function.
     * Used to clean up data related to a model after it has been removed.
     */
    function _afterRemoveModel(
        uint256 __modelId
    ) internal virtual override(TIExBaseIPAllocationUpgradeable) {
        if (_shareCollectionExists[__modelId]) {
            _shareCollectionExists[__modelId] = false;
            delete _shareCollections[__modelId];
        }
    }

    ////////////////////////////////////////////////////////////////////////////
    // ADMIN
    ////////////////////////////////////////////////////////////////////////////

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
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        onlyNotExistingShareCollection(__modelId)
        onlyExistingModelId(__modelId)
    {
        if (__maxSupply > 0 && __price > 0 && __maxSharePurchase > 0) {
            _shareCollections[__modelId] = TIExShareCollection({
                maxSupply: __maxSupply,
                totalInvestment: 0,
                withdrawnAmount: 0,
                price: __price,
                launchStartTime: block.timestamp,
                paused: true,
                blocked: false,
                forOnlyUSInvestors: __forOnlyUSInvestors,
                maxSharePurchase: __maxSharePurchase
            });

            _shareCollectionExists[__modelId] = true;

            emit TIExShareCollectionReleased(
                __modelId,
                _shareCollections[__modelId]
            );
        } else revert ErrorInvalidParam();
    }

    /**
     * @notice Distributes funds from investor
     */
    function distribute(uint256 __modelId) external onlyRole(DEFAULT_ADMIN_ROLE) onlyExistingModelId(__modelId) onlyExistingShareCollection(__modelId) {
        uint256 restOfAmount = _shareCollections[__modelId].totalInvestment.sub(_shareCollections[__modelId].withdrawnAmount);

        if(restOfAmount == 0) revert();

        uint256 toCreators = restOfAmount.mul(investmentDistribution.creatorRate);
        uint256 toMarketing = restOfAmount.mul(investmentDistribution.marketingtRate);
        uint256 toReserve = restOfAmount.mul(investmentDistribution.reserveRate);
        uint256 toPresale = restOfAmount.mul(investmentDistribution.presaleRate);
        (, , Contribution[] memory contributedModels) = getModelDetail(__modelId);

        _shareCollections[__modelId].withdrawnAmount = _shareCollections[__modelId].withdrawnAmount.add(restOfAmount);

        for(uint256 i = 0; i < contributedModels.length; i++) {
            address contributer = _creatorOf(contributedModels[i].modelId);

            if(contributer == address(0)) continue;

            uint256 toContributer = toCreators * contributedModels[i].contributionRate;

            paymentToken.safeTransfer(contributer, toContributer.div(10000).div(10000));
        }

        paymentToken.safeTransfer(investmentDistribution.marketing, toMarketing.div(10000));
        paymentToken.safeTransfer(investmentDistribution.reserve, toReserve.div(10000));
        paymentToken.safeTransfer(investmentDistribution.presale, toPresale.div(10000));

        emit Distribute(__modelId, restOfAmount, block.timestamp);
    }

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
    function updateTruthHolder(
        address __truthHolder
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (__truthHolder == address(0) || __truthHolder == truthHolder)
            revert ErrorInvalidParam();
        emit TIExTruthHolderUpdated(truthHolder, __truthHolder);
        truthHolder = __truthHolder;
    }

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
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 _tRate = __creatorRate
            .add(__marketingRate)
            .add(__presaleRate)
            .add(__reserveRate);
        InvestmentDistribution
            memory oldInvestmentDistribution = investmentDistribution;
        if (_tRate != 10000 || __creatorRate < 2000) revert ErrorInvalidParam();

        investmentDistribution.creatorRate = __creatorRate;
        investmentDistribution.marketingtRate = __marketingRate;
        investmentDistribution.presaleRate = __presaleRate;
        investmentDistribution.reserveRate = __reserveRate;

        emit TIExInvestmentDistributionRate(
            oldInvestmentDistribution,
            investmentDistribution
        );
    }


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
    function updateMarketingAddress(
        address __marketing
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (
            __marketing == address(0) ||
            __marketing == investmentDistribution.marketing
        ) revert ErrorInvalidParam();

        emit TIExMarketingAddressUpdated(
            investmentDistribution.marketing,
            __marketing
        );
        investmentDistribution.marketing = __marketing;
    }

    /**
     * @notice Updates the presale address.
     * @param __presale address The address where the presale funds will be distributed.
     * 
     * Emits a {TIExPresaleAddressUpdated} event.
     * 
     * Requirements:
     * 
     * - Must be called by an account with the `DEFAULT_ADMIN_ROLE` role.
     * - `__presale` address must not be the zero address(address(0)) or the same as the
     * current truth holder address.
     */
    function updatePresaleAddress(
        address __presale
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (
            __presale == address(0) ||
            __presale == investmentDistribution.presale
        ) revert ErrorInvalidParam();

        emit TIExPresaleAddressUpdated(
            investmentDistribution.presale,
            __presale
        );
        investmentDistribution.presale = __presale;
    }

    /**
     * @notice Updates the reserve address.
     * @param __reserve address The address where the reserve funds will be distributed.
     * 
     * Emits a {TIExReserveAddressUpdated} event.
     * 
     * Requirements:
     * 
     * - Must be called by an account with the `DEFAULT_ADMIN_ROLE` role.
     * - `__reserve` address must not be the zero address(address(0)) or the same as the
     * current truth holder address.
     */
    function updateReserveAddress(
        address __reserve
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (
            __reserve == address(0) ||
            __reserve == investmentDistribution.reserve
        ) revert ErrorInvalidParam();

        emit TIExReserveAddressUpdated(
            investmentDistribution.reserve,
            __reserve
        );
        investmentDistribution.reserve = __reserve;
    }

    /**
     * @notice Updates the payment token address.
     * @param __paymentToken address The address for ERC20 token used as utility token on TIEx.
     *
     * Emits a {TIExPaymentTokenUpdated} event.
     * 
     * Requirements:
     * 
     * - Must be called by an account with the `DEFAULT_ADMIN_ROLE` role.
     * - `__paymentToken` address must not be the zero address(address(0)) or the same as the
     * current truth holder address.
     */
    function updatePaymentToken(
        IPaymentToken __paymentToken
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (
            address(__paymentToken) == address(0) ||
            address(paymentToken) == address(__paymentToken)
        ) revert ErrorInvalidParam();
        emit TIExPaymentTokenUpdated(paymentToken, __paymentToken);
        paymentToken = __paymentToken;
    }

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
    function setPause(
        uint256 __modelId
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        onlyExistingShareCollection(__modelId)
    {
        if (_shareCollections[__modelId].paused) revert ErrorInvalidParam();
        _shareCollections[__modelId].paused = true;
        emit TIExShareCollectionPaused(__modelId);
    }

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
    function setUnpause(
        uint256 __modelId
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        onlyExistingShareCollection(__modelId)
    {
        if (!_shareCollections[__modelId].paused) revert ErrorInvalidParam();
        _shareCollections[__modelId].paused = false;
        emit TIExShareCollectionUnpaused(__modelId);
    }

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
    function setBlock(
        uint256 __modelId
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        onlyExistingShareCollection(__modelId)
    {
        if (_shareCollections[__modelId].blocked) revert ErrorInvalidParam();
        _shareCollections[__modelId].blocked = true;
        emit TIExShareCollectionBlocked(__modelId);
    }

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
    function setUnblock(
        uint256 __modelId
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        onlyExistingShareCollection(__modelId)
    {
        if (!_shareCollections[__modelId].blocked) revert ErrorInvalidParam();
        _shareCollections[__modelId].blocked = false;
        emit TIExShareCollectionUnblocked(__modelId);
    }

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
    function updateSharePrice(
        uint256 __modelId,
        uint256 __price
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        onlyExistingShareCollection(__modelId)
    {
        if (__price == 0 || __price == _shareCollections[__modelId].price)
            revert ErrorInvalidParam();
        emit TIExSharePriceUpdated(
            __modelId,
            _shareCollections[__modelId].price,
            __price
        );
        _shareCollections[__modelId].price = __price;
    }

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
    function updateMaxSupply(
        uint256 __modelId,
        uint256 __maxSupply
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        onlyExistingShareCollection(__modelId)
    {
        if (
            __maxSupply == 0 ||
            __maxSupply == _shareCollections[__modelId].maxSupply
        ) revert ErrorInvalidParam();
        emit TIExMaxSupplyUpdated(
            __modelId,
            _shareCollections[__modelId].maxSupply,
            __maxSupply
        );
        _shareCollections[__modelId].maxSupply = __maxSupply;
    }

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
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        onlyExistingShareCollection(__modelId)
    {
        if (
            __maxSharePurchase == 0 ||
            __maxSharePurchase == _shareCollections[__modelId].maxSharePurchase
        ) revert ErrorInvalidParam();
        emit TIExMaxSharePurchaseUpdated(
            __modelId,
            _shareCollections[__modelId].maxSharePurchase,
            __maxSharePurchase
        );
        _shareCollections[__modelId].maxSharePurchase = __maxSharePurchase;
    }

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
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        onlyExistingShareCollection(__modelId)
    {
        if (
            __forOnlyUSInvestors ==
            _shareCollections[__modelId].forOnlyUSInvestors
        ) revert ErrorInvalidParam();
        emit TIExShareCollectionInvestorPositionUpdated(
            __modelId,
            _shareCollections[__modelId].forOnlyUSInvestors,
            __forOnlyUSInvestors
        );
        _shareCollections[__modelId].forOnlyUSInvestors = __forOnlyUSInvestors;
    }

    /**
     * @notice Resumes operating the platform
     * 
     * Requirements:
     * 
     * - Must be called by an account with the `DEFAULT_ADMIN_ROLE` role.
     */
    function resume() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Pauses operating the platform
     * 
     * Requirements:
     * 
     * - Must be called by an account with the `DEFAULT_ADMIN_ROLE` role.
     */
    function emergency() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    ////////////////////////////////////////////////////////////////////////////
    // INVESTOR (OR MINTER)
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Used to mint tokens and assigns them to the investor's account 
     * when they want to invest in a model with a specific model ID.
     * @param __modelId uint256 The model id that the investor wants to invest in.
     * @param __amount uint256 The number of tokens the investor wants to buy.
     * @param __nonce uint256 A unique identifier for the transaction.
     * @param __usInvestor boolean Indicates whether the investor is a US investor or not.
     * @param __signature bytes A signature that verifies the authenticity of the transaction
     * signed by truth holder.
     * 
     * NOTE: 
     */
    function buyShares(
        uint256 __modelId,
        uint256 __amount,
        uint256 __nonce,
        bool __usInvestor,
        bytes calldata __signature,
        bytes calldata __permitMessage
    ) external whenShareCollectionNotPaused(__modelId) {
        // abi: [address, bool, address, string], [account, usInvestor, to, actionName]
        // Encodes a message using the provided parameters.
        bytes memory message = abi.encode(msg.sender, __usInvestor, address(this), __nonce);
        // Calculates the amount of payment tokens required based on the price of the model and the desired amount of tokens.
        uint256 paymentTokenAmount = _shareCollections[__modelId].price.mul(__amount);

        // Checks if the nonce has already been used and reverts the transaction if it has.
        if (noncesUsed[__nonce]) revert ErrorInvalidNonce();
        
        // Checks if the amount of tokens is 0 and reverts the transaction if it is.
        if (__amount == 0) revert ErrorInvalidParam();
        
        // Verifies the authenticity of the message using the provided signature and reverts the transaction if it is invalid.
        if (!verifyMessage(message, __signature)) revert ErrorInvalidSignature();
        
        // Checks if the investor's country matches the allowed country for the model and reverts the transaction if it doesn't.
        if (__usInvestor != _shareCollections[__modelId].forOnlyUSInvestors) revert ErrorInvalidCountry();
        
        // Checks if there is enough supply of tokens for the model and reverts the transaction if there isn't.
        if (totalSupply(__modelId).add(__amount) > _shareCollections[__modelId].maxSupply) revert ErrorNotEnoughSupply();

        // Checks if the investor has exceeded the maximum allowed share purchase for the model and reverts the transaction if they have.
        if (purchasedPerAccount[__modelId][msg.sender].add(__amount) > _shareCollections[__modelId].maxSharePurchase) revert ErrorExceedMaxSharePurchase();

        if(paymentToken.allowance(msg.sender, address(this)) < paymentTokenAmount) {
            (uint8 v, bytes32 r, bytes32 s, uint256 deadline) = abi.decode(__permitMessage, (uint8, bytes32, bytes32, uint256));
            paymentToken.permit(msg.sender, address(this), MAX_INT, deadline, v, r, s);
        }


        // Marks the nonce as used.
        noncesUsed[__nonce] = true;

        // Transfers the required amount of payment tokens from the investor to the contract.
        paymentToken.safeTransferFrom(msg.sender, address(this), paymentTokenAmount);

        // Updates the total investment for the model.
        _shareCollections[__modelId].totalInvestment = _shareCollections[__modelId].totalInvestment.add(paymentTokenAmount);

        // Increases the amount of tokens purchased by the investor for the model.
        purchasedPerAccount[__modelId][msg.sender] += __amount;

        // Mints the tokens and assigns them to the investor's account.
        _mint(msg.sender, __modelId, __amount, "");
    }

    ////////////////////////////////////////////////////////////////////////////
    // READS
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Returns whether or not an shareCollection exists.
     */
    function shareCollectionExists(
        uint256 __modelId
    ) public view returns (bool) {
        if (_shareCollectionExists[__modelId]) {
            return true;
        }
        return false;
    }

    /**
     * @notice Returns an Share Collection Status.
     */
    function shareCollection(
        uint256 __modelId
    )
        external
        view
        onlyExistingShareCollection(__modelId)
        returns (TIExShareCollection memory, string memory)
    {
        return (
            _shareCollections[__modelId],
            string(abi.encodePacked("ipfs://", _modelURIs[__modelId]))
        );
    }

    /**
     * @notice Returns the model URI.
     *
     */
    function uri(
        uint256 __modelId
    )
        public
        view
        override
        onlyExistingModelId(__modelId)
        returns (string memory)
    {
        return string(abi.encodePacked("ipfs://", _modelURIs[__modelId]));
    }

    /**
     * @notice See {ERC1155-supportsInterface} and {AccessControl-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(ERC1155Upgradeable, AccessControlEnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    ////////////////////////////////////////////////////////////////////////////
    // PRIVATES
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Verifies bytes message
     */
    function verifyMessage(
        bytes memory message,
        bytes memory signature
    ) private view returns (bool) {
        bytes32 hash = keccak256(message);
        return recoverSigner(hash, signature) == truthHolder;
    }

    /**
     * @notice Recovers signer
     */
    function recoverSigner(
        bytes32 hash,
        bytes memory signature
    ) private pure returns (address) {
        bytes32 messageDigest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );
        return ECDSA.recover(messageDigest, signature);
    }

}
