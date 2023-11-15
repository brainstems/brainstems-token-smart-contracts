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

import "./interface/IAssets.sol";
import "./interface/IAssetsRevenue.sol";
import "hardhat/console.sol";

contract AssetsRevenue is
    Initializable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    AccessControlEnumerableUpgradeable,
    IAssetsRevenue
{
    using SafeMath for uint256;
    using SafeERC20 for IPaymentToken;

    /// @notice See {ITIExShareCollections-paymentToken}.
    IPaymentToken public override paymentToken;

    /// @notice See {ITIExShareCollections-investmentDistribution}.
    InvestmentDistribution public override investmentDistribution;

    /// @notice See {ITIExShareCollections-utility}.
    IUtility public override utilityContract;

    /// @notice See {ITIExShareCollections-tiexBaseIPAllocation}.
    IAssets public override assetsContract;

    /**
     * @notice Defines the initialize function, which sets the name, symbol,
     * truth holder, payment token, and investment distribution for the token when deploying Proxy.
     * It also grants the initial roles to the owner upon construction.
     */
    function initialize(
        IPaymentToken __paymentToken,
        address __admin,
        InvestmentDistribution memory __investmentDistribution,
        IUtility __utility,
        IAssets __tiexBaseIPAllocation
    ) public initializer {
        uint256 _tRate = __investmentDistribution
            .creatorRate
            .add(__investmentDistribution.marketingtRate)
            .add(__investmentDistribution.presaleRate)
            .add(__investmentDistribution.reserveRate);

        if (_tRate != 10000) revert ErrorInvalidParam();

        paymentToken = __paymentToken;
        investmentDistribution = __investmentDistribution;
        utilityContract = __utility;
        assetsContract = __tiexBaseIPAllocation;

        __Context_init_unchained();
        __Pausable_init_unchained();

        _grantRole(DEFAULT_ADMIN_ROLE, __admin);
    }

    ////////////////////////////////////////////////////////////////////////////
    // MODIFIERS
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Checks if modelId allocated exists.
     * @param __modelId must be of existing ID of model.
     */
    modifier onlyExistingModelId(uint256 __modelId) {
        if (!assetsContract.assetExists(__modelId)) {
            revert IAssets.AssetNotFound(__modelId);
        }
        _;
    }

    ////////////////////////////////////////////////////////////////////////////
    // INTERNALS
    ////////////////////////////////////////////////////////////////////////////

    ////////////////////////////////////////////////////////////////////////////
    // ADMIN
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @dev See {ITIExShareCollections-distribute}.
     */
    // function distribute(
    //     uint256 __modelId
    // )
    //     external
    //     onlyRole(DEFAULT_ADMIN_ROLE)
    //     onlyExistingModelId(__modelId)
    //     onlyExistingShareCollection(__modelId)
    //     nonReentrant
    // {
    //     uint256 restOfAmount = _shareCollections[__modelId].totalInvestment.sub(
    //         _shareCollections[__modelId].withdrawnAmount
    //     );

    //     // TODO: replace with funds added by TIEX instead of shares investments, which are no longer present
    //     // if (restOfAmount == 0) revert();

    //     uint256 toCreators = restOfAmount.mul(
    //         investmentDistribution.creatorRate
    //     );
    //     uint256 toMarketing = restOfAmount.mul(
    //         investmentDistribution.marketingtRate
    //     );
    //     uint256 toReserve = restOfAmount.mul(
    //         investmentDistribution.reserveRate
    //     );
    //     uint256 toPresale = restOfAmount.mul(
    //         investmentDistribution.presaleRate
    //     );

    //     IAssets.Contribution[] memory contributedModels = tiexBaseIPAllocation
    //         .getAsset(__modelId)
    //         .contributedModels;

    //     _shareCollections[__modelId].withdrawnAmount = _shareCollections[
    //         __modelId
    //     ].withdrawnAmount.add(restOfAmount);

    //     for (uint256 i = 0; i < contributedModels.length; i++) {
    //         address contributer = tiexBaseIPAllocation
    //             .getAsset(contributedModels[i].modelId)
    //             .creator;

    //         if (contributer == address(0)) continue;

    //         uint256 toContributer = toCreators *
    //             contributedModels[i].contributionRate;

    //         paymentToken.safeTransfer(
    //             contributer,
    //             toContributer.div(10000).div(10000)
    //         );
    //     }

    //     paymentToken.safeTransfer(
    //         investmentDistribution.marketing,
    //         toMarketing.div(10000)
    //     );
    //     paymentToken.safeTransfer(
    //         investmentDistribution.reserve,
    //         toReserve.div(10000)
    //     );
    //     paymentToken.safeTransfer(
    //         investmentDistribution.presale,
    //         toPresale.div(10000)
    //     );

    //     emit Distribute(__modelId, restOfAmount, block.timestamp);
    // }

    /**
     * @dev See {ITIExShareCollections-updateUtility}.
     */
    function updateUtility(
        IUtility __utility
    ) external onlyRole("DEFAULT_ADMIN_ROLE") {
        if (address(__utility) == address(0)) revert ErrorInvalidParam();

        utilityContract = __utility;

        emit TIExUtilityUpdated(__utility);
    }

    // /**
    //  * @dev See {ITIExShareCollections-updateInvestmentDistributionRate}.
    //  */
    // function updateInvestmentDistributionRate(
    //     uint256 __creatorRate,
    //     uint256 __marketingRate,
    //     uint256 __presaleRate,
    //     uint256 __reserveRate
    // ) external onlyRole(DEFAULT_ADMIN_ROLE) {
    //     uint256 _tRate = __creatorRate
    //         .add(__marketingRate)
    //         .add(__presaleRate)
    //         .add(__reserveRate);

    //     if (_tRate != 10000 || __creatorRate < 2000) revert ErrorInvalidParam();

    //     investmentDistribution.creatorRate = __creatorRate;
    //     investmentDistribution.marketingtRate = __marketingRate;
    //     investmentDistribution.presaleRate = __presaleRate;
    //     investmentDistribution.reserveRate = __reserveRate;

    //     emit TIExInvestmentDistributionRate(investmentDistribution);
    // }

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
                    assetsContract.getAsset(__modelId).uri
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
