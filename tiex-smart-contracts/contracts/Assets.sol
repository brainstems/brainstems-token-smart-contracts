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

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "./interface/IAssets.sol";

contract Assets is
    Initializable,
    AccessControlEnumerableUpgradeable,
    IAssets,
    ReentrancyGuardUpgradeable
{
    using Strings for uint256;
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    // TODO: revise mappings
    /// @notice Mapping model id to TIEx Model
    mapping(uint256 => Asset) private assets;
    /// @notice Array with all model ids, used for enumeration
    uint256[] private assetIds;
    // asset ID to address to balance
    mapping(uint256 => mapping(address => uint256)) balances;

    ERC20 public paymentToken;

    function initialize(
        address _admin,
        ERC20 _paymentToken
    ) public initializer {
        paymentToken = _paymentToken;
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    ////////////////////////////////////////////////////////////////////////////
    // MODIFIERS
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Checks if modelId allocated exists.
     * @param assetId must be of existing ID of model.
     */
    modifier existingAsset(uint256 assetId) {
        if (!assetExists(assetId)) {
            revert AssetNotFound(assetId);
        }
        _;
    }

    /**
     * @notice Checks if modelId allocated exists.
     * @param assetId uint256 must be of existing ID of model.
     */
    modifier nonExistingAsset(uint256 assetId) {
        if (assetExists(assetId)) {
            revert AssetAlreadyExists(assetId);
        }
        _;
    }

    ////////////////////////////////////////////////////////////////////////////
    // ADMIN
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @dev See {ITIExBaseIPAllocation-giveCreatorTIExIP}.
     */
    function createAsset(
        uint256 assetId,
        uint256 baseAsset,
        Contributors calldata contributors,
        string calldata ipfsHash,
        Metadata calldata metadata
    ) external onlyRole(DEFAULT_ADMIN_ROLE) nonExistingAsset(assetId) {
        address creator = contributors.creator;
        // Check if the creator address is valid
        if (creator == address(0)) {
            revert InvalidCreator(address(0));
        }

        require(
            baseAsset == 0 ||
                getAsset(baseAsset).contributors.creator != address(0),
            "invalid base asset"
        );
        assets[assetId].baseAsset = baseAsset;
        // Set the creator of the model ID
        assets[assetId].contributors = contributors;
        // Set the IPFS hash of the model's metadata
        assets[assetId].uri = ipfsHash;

        uint256 _tRate = contributors
            .creatorRate
            .add(contributors.marketingRate)
            .add(contributors.presaleRate);

        if (_tRate != 10000) revert("invalid contributor rates");

        // Check if the model metadata is valid
        bool validForMetadata = bytes(metadata.name).length > 0 &&
            bytes(metadata.description).length > 0 &&
            metadata.version == 1 &&
            metadata.fingerprint.length > 0 &&
            metadata.watermarkFingerprint.length > 0 &&
            metadata.performance > 0;

        if (!validForMetadata) revert InvalidMetadata(assetId);
        // Set the model metadata
        assets[assetId].metadata = metadata;

        // Emit an event to log the allocation of the model ID
        emit AssetCreated(
            assetId,
            assets[assetId]
        );
    }

    /**
     * @dev See {ITIExBaseIPAllocation-updateModelMetadata}.
     */
    function upgradeAsset(
        uint256 assetId,
        Metadata calldata metadata
    ) external onlyRole(DEFAULT_ADMIN_ROLE) existingAsset(assetId) {
        // Check if the model metadata is valid
        bool validForMetadata = bytes(metadata.name).length > 0 &&
            bytes(metadata.description).length > 0 &&
            metadata.version > 0 &&
            metadata.fingerprint.length > 0 &&
            metadata.watermarkFingerprint.length > 0 &&
            metadata.performance > 0;

        if (!validForMetadata) revert InvalidMetadata(assetId);
        assets[assetId].metadata.version++;
        assets[assetId].metadata = metadata;

        emit AssetUpgraded(assetId, assets[assetId].metadata);
    }

    /**
     * @dev See {ITIExBaseIPAllocation-editURI}.
     */
    function editUri(
        uint256 assetId,
        string calldata ipfsHash
    ) external onlyRole(DEFAULT_ADMIN_ROLE) existingAsset(assetId) {
        assets[assetId].uri = ipfsHash;

        emit AssetUriUpdated(assetId, ipfsHash);
    }

    function updateMarketingAddress(
        uint256 assetId,
        address __marketing
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IAssets.Asset memory asset = getAsset(assetId);

        if (
            __marketing == address(0) ||
            __marketing == asset.contributors.marketing
        ) revert ErrorInvalidParam();

        asset.contributors.marketing = __marketing;

        emit AssetMarketingAddressUpdated(assetId, __marketing);
    }

    function updatePresaleAddress(
        uint256 assetId,
        address __presale
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IAssets.Asset memory asset = getAsset(assetId);

        if (__presale == address(0) || __presale == asset.contributors.presale)
            revert ErrorInvalidParam();

        asset.contributors.presale = __presale;

        emit AssetPresaleAddressUpdated(assetId, __presale);
    }

    function updateInvestmentDistributionRate(
        uint256 assetId,
        uint256 __creatorRate,
        uint256 __marketingRate,
        uint256 __presaleRate
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 _tRate = __creatorRate.add(__marketingRate).add(__presaleRate);

        if (_tRate != 10000 || __creatorRate < 2000) revert ErrorInvalidParam();

        Asset storage asset = assets[assetId];

        asset.contributors.creatorRate = __creatorRate;
        asset.contributors.marketingRate = __marketingRate;
        asset.contributors.presaleRate = __presaleRate;
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

        uint256 creatorAmount = (amount.mul(contributors.creatorRate) / 100) *
            100;
        uint256 marketingAmount = (amount.mul(contributors.marketingRate) /
            100) * 100;
        uint256 presaleAmount = (amount.mul(contributors.presaleRate) / 100) *
            100;

        balances[assetId][contributors.creator] += creatorAmount;
        balances[assetId][contributors.marketing] += marketingAmount;
        balances[assetId][contributors.presale] += presaleAmount;

        paymentToken.safeTransferFrom(msg.sender, address(this), creatorAmount);
        paymentToken.safeTransferFrom(
            msg.sender,
            address(this),
            marketingAmount
        );
        paymentToken.safeTransferFrom(msg.sender, address(this), presaleAmount);
    }

    /**
     * @dev See {ITIExShareCollections-distribute}.
     */
    function withdraw(uint256 assetId) external {
        address caller = msg.sender;
        uint256 balance = balances[assetId][caller];
        require(balance > 0);

        Asset memory asset = assets[assetId];
        Contributors memory contributors = asset.contributors;

        require(
            caller == contributors.creator ||
                caller == contributors.marketing ||
                caller == contributors.presale,
            "caller is not a contributor"
        );

        balances[assetId][caller] = 0;
        paymentToken.safeTransferFrom(msg.sender, address(this), balance);
    }

    ////////////////////////////////////////////////////////////////////////////
    // READ
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @dev See {ITIExBaseIPAllocation-getTIExModel}.
     */
    function getAsset(uint256 assetId) public view returns (Asset memory) {
        return assets[assetId];
    }

    /**
     * @dev See {ITIExBaseIPAllocation-creatorOf}.
     */
    function creatorOf(uint256 assetId) public view returns (address) {
        address creator = assets[assetId].contributors.creator;
        if (creator == address(0)) {
            revert AssetNotFound(assetId);
        }
        return creator;
    }

    /**
     * @dev See {ITIExBaseIPAllocation-modelExists}.
     */
    function assetExists(uint256 assetId) public view returns (bool) {
        return assets[assetId].contributors.creator != address(0);
    }

    /**
     * @dev See {ITIExBaseIPAllocation-totalModelSupply}.
     */
    function assetAmount() public view returns (uint256) {
        return assetIds.length;
    }

    function uri(
        uint256 __modelId
    ) public view existingAsset(__modelId) returns (string memory) {
        return string(abi.encodePacked("ipfs://", getAsset(__modelId).uri));
    }
}
