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
    /// @notice Mapping from creator to list of owned model IDs
    mapping(address => mapping(uint256 => uint256)) private creatorAssets;
    /// @notice Mapping creator address to model count
    mapping(address => uint256) private creatorAssetAmounts;
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
        Contributors calldata contributors,
        string calldata ipfsHash,
        Metadata calldata metadata
    ) external onlyRole(DEFAULT_ADMIN_ROLE) nonExistingAsset(assetId) {
        address creator = contributors.creator;
        // Check if the creator address is valid
        if (creator == address(0)) {
            revert InvalidCreator(address(0));
        }

        // Add the model ID to the list of all model IDs
        _addAssetId(assetId);
        // Add the model ID to the list of model IDs owned by the creator
        _addAssetIdToCreator(creator, assetId);

        // Increase the balance of model IDs owned by the creator
        unchecked {
            // Will not overflow unless all 2**256 model ids are allocated to the same creator.
            // Given that models are allocated one by one, it is impossible in practice that
            // this ever happens. Might change if we allow batch allocating.
            creatorAssetAmounts[creator] += 1;
        }

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
            msg.sender,
            assetId,
            assets[assetId],
            block.timestamp
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

        emit TIExMarketingAddressUpdated(__marketing);
    }

    function updatePresaleAddress(
        uint256 assetId,
        address __presale
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        IAssets.Asset memory asset = getAsset(assetId);

        if (__presale == address(0) || __presale == asset.contributors.presale)
            revert ErrorInvalidParam();

        asset.contributors.presale = __presale;

        emit TIExPresaleAddressUpdated(__presale);
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
     * @dev See {ITIExBaseIPAllocation-modelBalanceOf}.
     */
    function assetBalanceOf(address creator) public view returns (uint256) {
        if (creator == address(0)) {
            revert InvalidCreator(address(0));
        }
        return creatorAssetAmounts[creator];
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
     * @dev See {ITIExBaseIPAllocation-modelOfCreatorByIndex}.
     */
    function creatorAssetByIndex(
        address creator,
        uint256 index
    ) public view returns (uint256) {
        if (index >= assetBalanceOf(creator)) {
            revert OutOfBounds(creator, index);
        }
        return creatorAssets[creator][index];
    }

    /**
     * @dev See {ITIExBaseIPAllocation-totalModelSupply}.
     */
    function assetAmount() public view returns (uint256) {
        return assetIds.length;
    }

    /**
     * @dev See {ITIExBaseIPAllocation-modelByIndex}.
     */
    function assetByIndex(uint256 index) public view returns (uint256) {
        if (index >= assetAmount()) {
            revert OutOfBounds(address(0), index);
        }
        return assetIds[index];
    }

    /**
     * @dev See {ITIExBaseIPAllocation-modelsOfCreator}.
     */
    function assetsByCreator(
        address creator
    ) public view returns (uint256[] memory) {
        uint256 modelCount = assetBalanceOf(creator);

        uint256[] memory modelsId = new uint256[](modelCount);
        for (uint256 i; i < modelCount; i++) {
            modelsId[i] = creatorAssetByIndex(creator, i);
        }
        return modelsId;
    }

    function uri(
        uint256 __modelId
    ) public view existingAsset(__modelId) returns (string memory) {
        return string(abi.encodePacked("ipfs://", getAsset(__modelId).uri));
    }

    ////////////////////////////////////////////////////////////////////////////
    // PRIVATE
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Private function to add a model to this extension's model tracking data structures.
     * @param assetId uint256 ID of the model to be added to the models list
     *
     */
    function _addAssetId(uint256 assetId) private {
        assets[assetId].index = assetIds.length;
        assetIds.push(assetId);
    }

    /**
     * @notice Private function to add a model to this extension's ownership-tracking data structures.
     * @param creator address representing the new owner of the given model ID
     * @param assetId uint256 ID of the model to be added to the models list of the given address
     *
     */
    function _addAssetIdToCreator(address creator, uint256 assetId) private {
        uint256 length = assetBalanceOf(creator);
        creatorAssets[creator][length] = assetId;
        assets[assetId].creatorIndex = length;
    }

    /**
     * @notice Private function to remove a model from this extension's model tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allModels array.
     * @param assetId uint256 ID of the model to be removed from the models list
     *
     */
    function _removeAssetId(uint256 assetId) private {
        // To prevent a gap in the models array, we store the last model in the index of the model to delete, and
        // then delete the last slot.

        uint256 lastModelIndex = assetIds.length - 1;
        uint256 modelIndex = assets[assetId].index;

        // When the model to delete is the last model. However, since this occurs so
        // an 'if' statement (like in _removeModelFromCreatorEnumeration)
        uint256 lastModelId = assetIds[lastModelIndex];

        assetIds[modelIndex] = lastModelId; // Move the last model to the slot of the to-delete model
        assets[lastModelId].index = modelIndex; // Update the moved model's index

        // This also deletes the contents at the last position of the array
        delete assets[assetId].index;
        assetIds.pop();
    }

    /**
     * @notice Private function to remove a model from this extension's ownership-tracking data structures. Note that
     * while the model is not assigned a new creator, the `_ownedModelsIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a allocate operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedModels array.
     * @param creator address representing the previous creator of the given model ID
     * @param assetId uint256 ID of the model to be removed from the models list of the given address
     *
     */
    function _removeAssetIdFromCreator(
        address creator,
        uint256 assetId
    ) private {
        // To prevent a gap in from's models array, we store the last model in the index of the model to delete, and
        // then delete the last slot

        uint256 lastModelIndex = assetBalanceOf(creator) - 1;
        uint256 modelIndex = assets[assetId].creatorIndex;

        // When the model to delete is the last model
        if (modelIndex != lastModelIndex) {
            uint256 lastModelId = creatorAssets[creator][lastModelIndex];

            creatorAssets[creator][modelIndex] = lastModelId; // Move the last model to the slot of the to-delete model
            assets[lastModelId].creatorIndex = modelIndex; // Update the moved model's index
        }

        // This also deletes the contents at the last position of the array
        delete assets[assetId].creatorIndex;
        delete creatorAssets[creator][lastModelIndex];
    }
}
