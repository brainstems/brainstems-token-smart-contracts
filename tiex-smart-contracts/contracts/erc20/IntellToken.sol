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

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
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
    using SafeERC20 for IERC20;

    struct Balance {
        bool isInvestor;
        uint256 balance; // in tokens
    }

    enum Stage {
        Whitelisting,
        PrivateSale,
        PublicSale,
        Finished
    }

    event InvestorAdded(address indexed investor, uint256 balance);
    event WhitelistUpdated(address indexed participant);
    event TokensPurchased(
        address indexed buyer,
        uint256 amount,
        uint256 price,
        Stage stage
    );
    event TokensClaimed(address indexed investor, uint256 amount);
    event RateUpdated(uint256 rate);

    mapping(address => bool) public whitelist;
    mapping(address => Balance) public investors;

    IERC20 public usdcToken;
    uint256 public tokenToUsdc; // price of tokens in USDC
    uint256 public usdcEarnings;

    Stage public currentStage;

    uint256 public constant MAX_SUPPLY = 1000e6 * 1e18; // 1000 million tokens
    uint256 public constant INVESTORS_CAP = 100e6 * 1e18; // 100 million tokens
    uint256 public constant SALES_CAP = 70e6 * 1e18; // 70 million tokens

    uint256 public investorTokensAllocated;
    uint256 public tokensSold;

    function initialize(
        address _admin,
        IERC20 _usdcToken,
        uint256 _tokenToUsdc
    ) public initializer {
        require(_tokenToUsdc > 0, "invalid ratio");
        __ERC20_init("Intelligence Token", "INTELL");
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        usdcToken = _usdcToken;
        tokenToUsdc = _tokenToUsdc;
        currentStage = Stage.Whitelisting;
    }

    function signUpToWhitelist() external whenNotPaused {
        whitelist[msg.sender] = true;
        emit WhitelistUpdated(msg.sender);
    }

    function addInvestor(
        address investor,
        uint256 balance
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            investors[investor].isInvestor == false,
            "investor already added"
        );
        require(
            investorTokensAllocated + balance <= INVESTORS_CAP,
            "insufficient investor tokens"
        );
        investors[investor].isInvestor = true;
        investors[investor].balance = balance;
        investorTokensAllocated += balance;
        emit InvestorAdded(investor, balance);
    }

    function setPrice(
        uint256 _tokenToUsdc
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_tokenToUsdc > 0, "invalid price");
        tokenToUsdc = _tokenToUsdc;
        emit RateUpdated(_tokenToUsdc);
    }

    function moveToNextStage() external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(currentStage != Stage.Finished, "sales finished");
        currentStage = Stage(uint256(currentStage) + 1);
    }

    function pause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function claimInvestorTokens() external whenNotPaused {
        Balance storage balance = investors[msg.sender];
        require(balance.isInvestor, "not investor");
        require(balance.balance > 0, "no balance");
        _mint(msg.sender, balance.balance);
        emit TokensClaimed(msg.sender, balance.balance);
        balance.balance = 0;
    }

    function buyTokens(uint256 amount) external whenNotPaused {
        require(
            currentStage == Stage.PrivateSale ||
                currentStage == Stage.PublicSale,
            "invalid stage"
        );
        require(amount > 0, "amount is 0");

        if (currentStage == Stage.PrivateSale) {
            require(whitelist[msg.sender], "not whitelisted");
        }
        require(
            tokensSold + amount <= SALES_CAP,
            "insufficient available tokens"
        );
        tokensSold += amount;

        uint256 price = amount * tokenToUsdc;
        usdcEarnings += price;
        usdcToken.transferFrom(address(this), msg.sender, price);
        _mint(msg.sender, amount);
        emit TokensPurchased(msg.sender, amount, price, currentStage);
    }

    // distribute to other pools (e.g. community programs, emissions)
    function distribute(
        address recipient,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        require(amount > 0, "amount is 0");
        require(totalSupply() + amount <= MAX_SUPPLY, "exceeds maximum supply");
        _mint(recipient, amount);
    }

    function claimEarnings(
        address cashOutRecipient
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        usdcToken.transferFrom(address(this), cashOutRecipient, usdcEarnings);
        usdcEarnings = 0;
    }
}
