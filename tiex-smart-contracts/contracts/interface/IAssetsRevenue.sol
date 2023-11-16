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

    /// @notice The payment token (ERC20: INTELL token)
    function paymentToken() external view returns (IPaymentToken);

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
    function updateMarketingAddress(
        uint256 assetId,
        address __marketing
    ) external;

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
    function updatePresaleAddress(uint256 assetId, address __presale) external;
}
