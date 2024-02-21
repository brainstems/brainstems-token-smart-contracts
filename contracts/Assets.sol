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
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import "./interface/IAssets.sol";

contract Assets is
    Initializable,
    AccessControlEnumerableUpgradeable,
    IAssets,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    mapping(uint256 => Asset) private assets;
    mapping(uint256 => mapping(address => uint256)) public balances;

    IERC20 public paymentToken;

    function initialize(
        address _admin,
        address _paymentToken
    ) public initializer {
        require(_paymentToken != address(0), "invalid contract address");
        paymentToken = IERC20(_paymentToken);
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    modifier existingAsset(uint256 assetId) {
        require(assetExists(assetId), "asset not found");
        _;
    }

    function createAsset(
        uint256 assetId,
        uint256 baseAsset,
        Contributors calldata contributors,
        string calldata ipfsHash,
        Metadata calldata metadata
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(!assetExists(assetId), "asset already exists");
        address creator = contributors.creator;
        require(creator != address(0), "invalid creator");

        require(
            baseAsset == 0 ||
                assets[baseAsset].contributors.creator != address(0),
            "invalid base asset"
        );
        assets[assetId].baseAsset = baseAsset;
        assets[assetId].contributors = contributors;
        assets[assetId].uri = ipfsHash;

        uint256 _tRate = contributors.creatorRate +
            contributors.marketingRate +
            contributors.presaleRate;

        if (_tRate != 10000) revert("invalid contributor rates");

        bool validMetadata = bytes(metadata.name).length > 0 &&
            bytes(metadata.description).length > 0 &&
            metadata.version == 1;

        require(validMetadata, "invalid metadata");
        assets[assetId].metadata = metadata;

        emit AssetCreated(assetId, assets[assetId]);
    }

    function upgradeAsset(
        uint256 assetId,
        Metadata calldata metadata,
        string calldata ipfsHash
    ) external onlyRole(DEFAULT_ADMIN_ROLE) existingAsset(assetId) {
        bool validMetadata = bytes(metadata.name).length > 0 &&
            bytes(metadata.description).length > 0 &&
            metadata.version > assets[assetId].metadata.version;

        require(validMetadata, "invalid metadata");
        assets[assetId].metadata = metadata;
        assets[assetId].uri = ipfsHash;

        emit AssetUpgraded(assetId, metadata, ipfsHash);
    }

    function editUri(
        uint256 assetId,
        string calldata ipfsHash
    ) external onlyRole(DEFAULT_ADMIN_ROLE) existingAsset(assetId) {
        assets[assetId].uri = ipfsHash;

        emit AssetUriUpdated(assetId, ipfsHash);
    }

    function updateMarketingAddress(
        uint256 assetId,
        address marketing
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Asset storage asset = assets[assetId];

        require(
            marketing != asset.contributors.marketing,
            "no change to address"
        );
        asset.contributors.marketing = marketing;

        emit AssetMarketingAddressUpdated(assetId, marketing);
    }

    function updatePresaleAddress(
        uint256 assetId,
        address presale
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        Asset storage asset = assets[assetId];

        require(presale != asset.contributors.presale, "no change to address");
        asset.contributors.presale = presale;

        emit AssetPresaleAddressUpdated(assetId, presale);
    }

    function updateInvestmentDistributionRate(
        uint256 assetId,
        uint256 creatorRate,
        uint256 marketingRate,
        uint256 presaleRate
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 totalRate = creatorRate + marketingRate + presaleRate;

        require(totalRate == 10000 && creatorRate >= 2000, "invalid rates");

        Asset storage asset = assets[assetId];

        asset.contributors.creatorRate = creatorRate;
        asset.contributors.marketingRate = marketingRate;
        asset.contributors.presaleRate = presaleRate;

        emit AssetRatesUpdated(
            assetId,
            creatorRate,
            marketingRate,
            presaleRate
        );
    }

    function deposit(
        uint256 assetId,
        uint256 amount
    )
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        existingAsset(assetId)
        nonReentrant
    {
        require(amount > 0, "amount is 0");

        Asset memory asset = assets[assetId];
        Contributors memory contributors = asset.contributors;

        uint256 creatorAmount = (amount * contributors.creatorRate) / 10000;
        uint256 marketingAmount = (amount * contributors.marketingRate) / 10000;
        uint256 presaleAmount = (amount * contributors.presaleRate) / 10000;

        balances[assetId][contributors.creator] += creatorAmount;
        balances[assetId][contributors.marketing] += marketingAmount;
        balances[assetId][contributors.presale] += presaleAmount;

        emit AssetEarningsDeposited(
            assetId,
            creatorAmount,
            marketingAmount,
            presaleAmount
        );

        paymentToken.safeTransferFrom(msg.sender, address(this), creatorAmount);
        paymentToken.safeTransferFrom(
            msg.sender,
            address(this),
            marketingAmount
        );
        paymentToken.safeTransferFrom(msg.sender, address(this), presaleAmount);
    }

    function withdraw(uint256 assetId) external nonReentrant {
        address caller = msg.sender;

        Asset memory asset = assets[assetId];
        Contributors memory contributors = asset.contributors;

        require(
            caller == contributors.creator ||
                caller == contributors.marketing ||
                caller == contributors.presale,
            "caller is not a contributor"
        );

        uint256 balance = balances[assetId][caller];
        require(balance > 0, "no balance");

        balances[assetId][caller] = 0;

        emit AssetEarningsWithdrawn(assetId, caller, balance);

        paymentToken.safeTransfer(msg.sender, balance);
    }

    function getAsset(
        uint256 assetId
    ) public view existingAsset(assetId) returns (Asset memory) {
        return assets[assetId];
    }

    function creatorOf(
        uint256 assetId
    ) public view existingAsset(assetId) returns (address) {
        address creator = assets[assetId].contributors.creator;
        return creator;
    }

    function assetExists(uint256 assetId) public view returns (bool) {
        return assets[assetId].contributors.creator != address(0);
    }

    function uri(
        uint256 assetId
    ) public view existingAsset(assetId) returns (string memory) {
        return
            string(
                abi.encodePacked("https://ipfs.io/ipfs/", assets[assetId].uri)
            );
    }
}
