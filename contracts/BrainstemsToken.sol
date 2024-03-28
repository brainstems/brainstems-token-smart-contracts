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

import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract BrainstemsToken is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    AccessControlEnumerableUpgradeable
{
    uint256 public constant MAX_SUPPLY = 1000e6 * 1e18; // 1000 million tokens
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _admin
    ) public initializer {
        __ERC20_init("Brainstems Token", "STEMS");
        __ERC20Burnable_init();
        __AccessControlEnumerable_init();
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _setRoleAdmin(MINTER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    /**
     * @notice mints token to other pools until max supply is reached (e.g. community programs, emissions, bridge, etc).
     * @param recipient address to receive the tokens.
     * @param amount amount of tokens to mint.
     */
    function mint(
        address recipient,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) {
        require(amount > 0, "amount is 0");
        require(totalSupply() + amount <= MAX_SUPPLY, "exceeds maximum supply");

        _mint(recipient, amount);
    }
}
