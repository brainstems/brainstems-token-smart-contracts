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

pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";

contract IntelligenceToken is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    AccessControlEnumerableUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;

    struct Balance {
        bool enabled;
        uint256 balance; // in tokens
    }

    enum Stage {
        Whitelisting,
        PrivateSale,
        PublicSale,
        Finished
    }

    event InvestorAdded(address indexed investor, uint256 balance);
    event WhitelistUpdated(bytes32 merkleRoot);
    event TokensPurchased(
        address indexed buyer,
        uint256 amount,
        uint256 price,
        Stage stage
    );
    event TokensClaimed(address indexed investor, uint256 amount);
    event RateUpdated(uint256 rate);

    // merkle tree root for whitelisted addresses
    bytes32 public whitelistRoot;

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
        address _usdcToken,
        uint256 _tokenToUsdc
    ) public initializer {
        require(_tokenToUsdc > 0, "invalid conversion");
        require(_usdcToken != address(0), "invalid contract param");
        __ERC20_init("Intelligence Token", "INTELL");
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        usdcToken = IERC20(_usdcToken);
        tokenToUsdc = _tokenToUsdc;
        currentStage = Stage.Whitelisting;

        emit RateUpdated(_tokenToUsdc);
    }

    function setWhitelistRoot(
        bytes32 _root
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_root.length > 0, "invalid root");
        whitelistRoot = _root;
        emit WhitelistUpdated(_root);
    }

    function addInvestor(
        address investor,
        uint256 balance
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!investors[investor].enabled, "investor already added");
        require(
            investorTokensAllocated + balance <= INVESTORS_CAP,
            "insufficient investor tokens"
        );
        investors[investor].enabled = true;
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

    function claimInvestorTokens() external {
        Balance storage balance = investors[msg.sender];
        require(balance.enabled, "not investor");
        require(balance.balance > 0, "no balance");
        require(
            totalSupply() + balance.balance <= MAX_SUPPLY,
            "exceeds maximum supply"
        );

        uint256 amount = balance.balance;
        balance.balance = 0;

        emit TokensClaimed(msg.sender, amount);
        _mint(msg.sender, amount);
    }

    function buyWhitelistedTokens(
        uint256 amount,
        bytes32[] memory proof
    ) external whenNotPaused {
        require(currentStage == Stage.PrivateSale, "invalid stage");
        _buyTokens(amount, msg.sender, proof);
    }

    function buyPublicTokens(uint256 amount) external whenNotPaused {
        require(currentStage == Stage.PublicSale, "invalid stage");
        bytes32[] memory emptyProof = new bytes32[](0);
        _buyTokens(amount, msg.sender, emptyProof);
    }

    function _buyTokens(
        uint256 amount,
        address buyer,
        bytes32[] memory proof
    ) internal {
        require(amount > 0, "amount is 0");

        if (proof.length > 0) {
            bytes32 leaf = keccak256(
                bytes.concat(keccak256(abi.encode(buyer)))
            );
            require(
                MerkleProof.verify(proof, whitelistRoot, leaf),
                "not whitelisted"
            );
        }

        require(
            tokensSold + amount <= SALES_CAP,
            "insufficient available tokens"
        );
        require(totalSupply() + amount <= MAX_SUPPLY, "exceeds maximum supply");
        tokensSold += amount;

        uint256 price = amount * tokenToUsdc;
        usdcEarnings += price;

        emit TokensPurchased(buyer, amount, price, currentStage);
        _mint(buyer, amount);
        usdcToken.safeTransferFrom(buyer, address(this), price);
    }

    // distribute to other pools (e.g. community programs, emissions)
    function distribute(
        address recipient,
        uint256 amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(recipient != address(0), "invalid recipient");
        require(amount > 0, "amount is 0");
        require(totalSupply() + amount <= MAX_SUPPLY, "exceeds maximum supply");
        _mint(recipient, amount);
    }

    function claimEarnings(
        address cashOutRecipient
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        require(cashOutRecipient != address(0), "invalid recipient");
        uint256 _usdcEarnings = usdcEarnings;
        usdcEarnings = 0;
        usdcToken.safeTransfer(cashOutRecipient, _usdcEarnings);
    }
}
