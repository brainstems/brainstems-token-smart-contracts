// SPDX-License-Identifier: MIT

/*
$$$$$$$\  $$$$$$$\   $$$$$$\  $$$$$$\ $$\   $$\  $$$$$$\ $$$$$$$$\ $$$$$$$$\ $$\      $$\  $$$$$$\  
$$  __$$\ $$  __$$\ $$  __$$\ \_$$  _|$$$\  $$ |$$  __$$\\__$$  __|$$  _____|$$$\    $$$ |$$  __$$\ 
$$ |  $$ |$$ |  $$ |$$ /  $$ |  $$ |  $$$$\ $$ |$$ /  \__|  $$ |   $$ |      $$$$\  $$$$ |$$ /  \__|
$$$$$$$\ |$$$$$$$  |$$$$$$$$ |  $$ |  $$ $$\$$ |\$$$$$$\    $$ |   $$$$$\    $$\$$\$$ $$ |\$$$$$$\  
$$  __$$\ $$  __$$< $$  __$$ |  $$ |  $$ \$$$$ | \____$$\   $$ |   $$  __|   $$ \$$$  $$ | \____$$\ 
$$ |  $$ |$$ |  $$ |$$ |  $$ |  $$ |  $$ |\$$$ |$$\   $$ |  $$ |   $$ |      $$ |\$  /$$ |$$\   $$ |
$$$$$$$  |$$ |  $$ |$$ |  $$ |$$$$$$\ $$ | \$$ |\$$$$$$  |  $$ |   $$$$$$$$\ $$ | \_/ $$ |\$$$$$$  |
\_______/ \__|  \__|\__|  \__|\______|\__|  \__| \______/   \__|   \________|\__|     \__| \______/ 
*/

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";

contract BrainstemsToken is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    AccessControlEnumerableUpgradeable
{
    uint256 public constant MAX_SUPPLY = 1000e6 * 1e18; // 1000 million tokens

    function initialize(
        address _admin
    ) public initializer {
        __ERC20_init("Brainstems Token", "STEMS");
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    /**
     * @notice mints token to other pools until max supply is reached (e.g. community programs, emissions, bridge, etc).
     * @param recipient address to receive the tokens.
     * @param amount amount of tokens to mint.
     */
    function mint(
        address recipient,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(recipient != address(0), "invalid recipient");
        require(amount > 0, "amount is 0");
        require(totalSupply() + amount <= MAX_SUPPLY, "exceeds maximum supply");

        _mint(recipient, amount);
    }
}
