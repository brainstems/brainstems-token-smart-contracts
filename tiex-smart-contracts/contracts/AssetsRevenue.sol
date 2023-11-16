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
    AccessControlEnumerableUpgradeable
{
    using SafeMath for uint256;
    using SafeERC20 for IPaymentToken;

    /// @notice See {ITIExShareCollections-paymentToken}.
    IPaymentToken public paymentToken;

    /// @notice See {ITIExShareCollections-utility}.
    IUtility public utilityContract;

    /// @notice See {ITIExShareCollections-tiexBaseIPAllocation}.
    IAssets public assetsContract;

    /**
     * @notice Defines the initialize function, which sets the name, symbol,
     * truth holder, payment token, and investment distribution for the token when deploying Proxy.
     * It also grants the initial roles to the owner upon construction.
     */
    function initialize(
        IPaymentToken __paymentToken,
        address __admin,
        IUtility __utility,
        IAssets __tiexBaseIPAllocation
    ) public initializer {
        paymentToken = __paymentToken;
        utilityContract = __utility;
        assetsContract = __tiexBaseIPAllocation;

        __Context_init_unchained();
        __Pausable_init_unchained();

        _grantRole(DEFAULT_ADMIN_ROLE, __admin);
    }

    ////////////////////////////////////////////////////////////////////////////
    // MODIFIERS
    ////////////////////////////////////////////////////////////////////////////

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

    /**
     * @dev See {ITIExShareCollections-updatePresaleAddress}.
     */

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
