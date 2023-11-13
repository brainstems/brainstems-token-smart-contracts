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

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interface/IBaseIPAllocation.sol";
import "./interface/ITIExShareCollections.sol";
import "hardhat/console.sol";

contract TIExShareCollections is
    Initializable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlEnumerableUpgradeable,
    ITIExShareCollections
{
    using SafeMath for uint256;
    using SafeERC20 for IPaymentToken;

    /// @notice MAX_INT = 2**256 - 1 = uint256(-1)
    uint256 constant MAX_INT =
        0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;

    /// @notice See {ITIExShareCollections-name}.
    string public override name;

    /// @notice See {ITIExShareCollections-symbol}.
    string public override symbol;

    /// @notice Mapping of share collctions
    mapping(uint256 => TIExShareCollection) private _shareCollections;

    /// @notice Mapping the number of shares purchased per account in every share collection
    mapping(uint256 => mapping(address => uint256)) public purchasedPerAccount;

    /// @notice See {ITIExShareCollections-truthHolder}.
    address public override truthHolder;

    /// @notice See {ITIExShareCollections-paymentToken}.
    IPaymentToken public override paymentToken;

    /// @notice Mapping of nonces used
    mapping(uint256 => bool) public noncesUsed;

    /// @notice See {ITIExShareCollections-investmentDistribution}.
    InvestmentDistribution public override investmentDistribution;

    /// @notice See {ITIExShareCollections-utility}.
    IUtility public override utility;

    /// @notice See {ITIExShareCollections-tiexBaseIPAllocation}.
    IBaseIPAllocation public override tiexBaseIPAllocation;

    /**
     * @notice Defines the initialize function, which sets the name, symbol,
     * truth holder, payment token, and investment distribution for the token when deploying Proxy.
     * It also grants the initial roles to the owner upon construction.
     */
    function initialize(
        address __truthHolder,
        IPaymentToken __paymentToken,
        address __admin,
        InvestmentDistribution memory __investmentDistribution,
        IUtility __utility,
        IBaseIPAllocation __tiexBaseIPAllocation
    ) public initializer {
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
        utility = __utility;
        tiexBaseIPAllocation = __tiexBaseIPAllocation;

        __Context_init_unchained();
        __Pausable_init_unchained();

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
     * @notice Checks if modelId allocated exists.
     * @param __modelId must be of existing ID of model.
     */
    modifier onlyExistingModelId(uint256 __modelId) {
        if (!tiexBaseIPAllocation.modelExists(__modelId)) {
            revert IBaseIPAllocation.ErrorAssetNotFound(__modelId);
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
     * @dev See {ITIExShareCollections-afterRemoveModel}.
     */
    function afterRemoveModel(uint256 __modelId) external {
        if (msg.sender != address(tiexBaseIPAllocation))
            revert ErrorInvalidMsgSender();
        if (shareCollectionExists(__modelId)) {
            delete _shareCollections[__modelId];
        }
    }

    ////////////////////////////////////////////////////////////////////////////
    // ADMIN
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @dev See {ITIExShareCollections-releaseShareCollection}.
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

            emit TIExShareCollectionReleased(
                __modelId,
                _shareCollections[__modelId]
            );
        } else revert ErrorInvalidParam();
    }

    /**
     * @dev See {ITIExShareCollections-distribute}.
     */
    function distribute(
        uint256 __modelId
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        onlyExistingModelId(__modelId)
        onlyExistingShareCollection(__modelId)
        nonReentrant
    {
        uint256 restOfAmount = _shareCollections[__modelId].totalInvestment.sub(
            _shareCollections[__modelId].withdrawnAmount
        );

        // TODO: replace with funds added by TIEX instead of shares investments, which are no longer present
        // if (restOfAmount == 0) revert();

        uint256 toCreators = restOfAmount.mul(
            investmentDistribution.creatorRate
        );
        uint256 toMarketing = restOfAmount.mul(
            investmentDistribution.marketingtRate
        );
        uint256 toReserve = restOfAmount.mul(
            investmentDistribution.reserveRate
        );
        uint256 toPresale = restOfAmount.mul(
            investmentDistribution.presaleRate
        );

        IBaseIPAllocation.Contribution[]
            memory contributedModels = tiexBaseIPAllocation
                .getAsset(__modelId)
                .contributedModels;

        _shareCollections[__modelId].withdrawnAmount = _shareCollections[
            __modelId
        ].withdrawnAmount.add(restOfAmount);

        for (uint256 i = 0; i < contributedModels.length; i++) {
            address contributer = tiexBaseIPAllocation
                .getAsset(contributedModels[i].modelId)
                .creator;

            if (contributer == address(0)) continue;

            uint256 toContributer = toCreators *
                contributedModels[i].contributionRate;

            paymentToken.safeTransfer(
                contributer,
                toContributer.div(10000).div(10000)
            );
        }

        paymentToken.safeTransfer(
            investmentDistribution.marketing,
            toMarketing.div(10000)
        );
        paymentToken.safeTransfer(
            investmentDistribution.reserve,
            toReserve.div(10000)
        );
        paymentToken.safeTransfer(
            investmentDistribution.presale,
            toPresale.div(10000)
        );

        emit Distribute(__modelId, restOfAmount, block.timestamp);
    }

    /**
     * @dev See {ITIExShareCollections-updateUtility}.
     */
    function updateUtility(
        IUtility __utility
    ) external onlyRole("DEFAULT_ADMIN_ROLE") {
        if (address(__utility) == address(0)) revert ErrorInvalidParam();

        utility = __utility;

        emit TIExUtilityUpdated(__utility);
    }

    /**
     * @dev See {ITIExShareCollections-updateTruthHolder}.
     */
    function updateTruthHolder(
        address __truthHolder
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (__truthHolder == address(0) || __truthHolder == truthHolder)
            revert ErrorInvalidParam();
        truthHolder = __truthHolder;

        emit TIExTruthHolderUpdated(__truthHolder);
    }

    /**
     * @dev See {ITIExShareCollections-updateInvestmentDistributionRate}.
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

        if (_tRate != 10000 || __creatorRate < 2000) revert ErrorInvalidParam();

        investmentDistribution.creatorRate = __creatorRate;
        investmentDistribution.marketingtRate = __marketingRate;
        investmentDistribution.presaleRate = __presaleRate;
        investmentDistribution.reserveRate = __reserveRate;

        emit TIExInvestmentDistributionRate(investmentDistribution);
    }

    /**
     * @dev See {ITIExShareCollections-updateMarketingAddress}.
     */
    function updateMarketingAddress(
        address __marketing
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (
            __marketing == address(0) ||
            __marketing == investmentDistribution.marketing
        ) revert ErrorInvalidParam();

        investmentDistribution.marketing = __marketing;

        emit TIExMarketingAddressUpdated(__marketing);
    }

    /**
     * @dev See {ITIExShareCollections-updatePresaleAddress}.
     */
    function updatePresaleAddress(
        address __presale
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (
            __presale == address(0) ||
            __presale == investmentDistribution.presale
        ) revert ErrorInvalidParam();

        investmentDistribution.presale = __presale;

        emit TIExPresaleAddressUpdated(__presale);
    }

    /**
     * @dev See {ITIExShareCollections-updateReserveAddress}.
     */
    function updateReserveAddress(
        address __reserve
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (
            __reserve == address(0) ||
            __reserve == investmentDistribution.reserve
        ) revert ErrorInvalidParam();

        investmentDistribution.reserve = __reserve;

        emit TIExReserveAddressUpdated(__reserve);
    }

    /**
     * @dev See {ITIExShareCollections-updatePaymentToken}.
     */
    function updatePaymentToken(
        IPaymentToken __paymentToken
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (
            address(__paymentToken) == address(0) ||
            address(paymentToken) == address(__paymentToken)
        ) revert ErrorInvalidParam();

        paymentToken = __paymentToken;

        emit TIExPaymentTokenUpdated(__paymentToken);
    }

    /**
     * @dev See {ITIExShareCollections-setPause}.
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
     * @dev See {ITIExShareCollections-setUnpause}.
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
     * @dev See {ITIExShareCollections-setBlock}.
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
     * @dev See {ITIExShareCollections-setUnblock}.
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
     * @dev See {ITIExShareCollections-updateSharePrice}.
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

        _shareCollections[__modelId].price = __price;

        emit TIExSharePriceUpdated(__modelId, __price);
    }

    /**
     * @dev See {ITIExShareCollections-updateMaxSupply}.
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

        _shareCollections[__modelId].maxSupply = __maxSupply;

        emit TIExMaxSupplyUpdated(__modelId, __maxSupply);
    }

    /**
     * @dev See {ITIExShareCollections-updateMaxSharePurchase}.
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

        _shareCollections[__modelId].maxSharePurchase = __maxSharePurchase;

        emit TIExMaxSharePurchaseUpdated(__modelId, __maxSharePurchase);
    }

    /**
     * @dev See {ITIExShareCollections-updateInvestorPosition}.
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

        _shareCollections[__modelId].forOnlyUSInvestors = __forOnlyUSInvestors;

        emit TIExShareCollectionInvestorPositionUpdated(
            __modelId,
            __forOnlyUSInvestors
        );
    }

    /**
     * @dev See {ITIExShareCollections-resume}.
     */
    function resume() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @dev See {ITIExShareCollections-emergency}.
     */
    function emergency() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    ////////////////////////////////////////////////////////////////////////////
    // READS
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @dev See {ITIExShareCollections-shareCollectionExists}.
     */
    function shareCollectionExists(
        uint256 __modelId
    ) public view returns (bool) {
        return _shareCollections[__modelId].launchStartTime != 0;
    }

    /**
     * @dev See {ITIExShareCollections-shareCollection}.
     */
    function shareCollection(
        uint256 __modelId
    )
        external
        view
        onlyExistingShareCollection(__modelId)
        returns (
            TIExShareCollection memory,
            IBaseIPAllocation.Asset memory
        )
    {
        return (
            _shareCollections[__modelId],
            tiexBaseIPAllocation.getAsset(__modelId)
        );
    }

    /**
     * @notice Returns the model URI.
     *
     */
    function uri(
        uint256 __modelId
    ) public view onlyExistingModelId(__modelId) returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "ipfs://",
                    tiexBaseIPAllocation.getAsset(__modelId).uri
                )
            );
    }

    /**
     * @notice See {AccessControl-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(AccessControlEnumerableUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev This function is called for plain Ether transfers, i.e. for every call with empty calldata.
     */
    receive() external payable {}

    /**
     * @dev Fallback function is executed if none of the other functions match the function
     * identifier or no data was provided with the function call.
     */
    fallback() external payable {}
}
