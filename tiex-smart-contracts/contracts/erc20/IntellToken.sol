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

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

contract IntelligenceToken is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    AccessControlEnumerableUpgradeable,
    PausableUpgradeable
{
    enum SaleStage {
        Whitelist,
        PrivateSale,
        PublicSale,
        Finished
    }
    event WhitelistUpdated(address indexed participant);
    event InvestorAdded(address indexed investor);
    event TokensPurchased(
        address indexed buyer,
        uint256 amount,
        SaleStage stage
    );
    event RateUpdated(uint256 rate);

    mapping(address => bool) public whitelist;
    mapping(address => bool) public investors;

    SaleStage public currentStage;

    uint256 public constant MAX_SUPPLY = 1000e6 * 1e18; // 1000 million tokens
    uint256 public constant PRIVATE_SALE_CAP = 100e6 * 1e18; // 100 million tokens
    uint256 public constant PUBLIC_SALE_CAP = 70e6 * 1e18; // 70 million tokens

    uint256 public privateSaleTokensSold;
    uint256 public publicSaleTokensSold;

    function initialize(address admin) public initializer {
        __ERC20_init("Intelligence Token", "INTELL");
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        currentStage = SaleStage.Whitelist;
    }

    function signUpToWhitelist() external whenNotPaused {
        whitelist[msg.sender] = true;
        emit WhitelistUpdated(msg.sender);
    }

    function addInvestor(
        address investor
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        investors[msg.sender] = true;
        emit WhitelistUpdated(investor);
    }

    function setRate() external onlyRole(DEFAULT_ADMIN_ROLE) {}

    function moveToNextStage() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(currentStage != SaleStage.Finished, "sales finished");
        currentStage = SaleStage(uint256(currentStage) + 1);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function buyTokens(uint256 amount) external whenNotPaused {
        require(
            currentStage == SaleStage.PrivateSale ||
                currentStage == SaleStage.PublicSale,
            "invalid stage"
        );
        require(amount > 0, "amount is 0");

        if (currentStage == SaleStage.PrivateSale) {
            if (investors[msg.sender]) {
                // investors can buy from available public sale tokens if needed
                uint256 availablePrivateTokens = PRIVATE_SALE_CAP -
                    privateSaleTokensSold;
                uint256 availablePublicTokens = PUBLIC_SALE_CAP -
                    publicSaleTokensSold;
                require(
                    availablePrivateTokens + availablePublicTokens - amount > 0,
                    "not enough tokens available"
                );
                if (availablePrivateTokens < amount) {
                    privateSaleTokensSold += availablePrivateTokens;
                    publicSaleTokensSold += amount - availablePrivateTokens;
                } else {
                    privateSaleTokensSold += amount;
                }
            } else {
                require(whitelist[msg.sender], "not whitelisted");
                require(
                    privateSaleTokensSold + amount <= PRIVATE_SALE_CAP,
                    "exceeds private sale cap"
                );
                require(
                    PRIVATE_SALE_CAP - privateSaleTokensSold > 0,
                    "not enough tokens available"
                );
                privateSaleTokensSold += amount;
            }
        } else {
            require(
                publicSaleTokensSold + amount <= PUBLIC_SALE_CAP,
                "exceeds public sale cap"
            );
            require(
                PUBLIC_SALE_CAP - publicSaleTokensSold > 0,
                "not enough tokens available"
            );
            publicSaleTokensSold += amount;
        }

        _mint(msg.sender, amount);
        emit TokensPurchased(msg.sender, amount, currentStage);
    }

    // distribute to other pools (e.g. community programs, emissions)
    function distributeTokens(
        address recipient,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        require(amount > 0, "amount is 0");
        require(totalSupply() + amount <= MAX_SUPPLY, "exceeds maximum supply");
        _mint(recipient, amount);
    }

    function cashOut() external onlyRole(DEFAULT_ADMIN_ROLE) {}
}
