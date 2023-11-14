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

import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./interface/IAssets.sol";
import "./interface/IAssetsRevenue.sol";

contract Assets is Initializable, AccessControlEnumerableUpgradeable, IAssets {
    using Strings for uint256;
    using SafeMath for uint256;

    /// @notice Mapping from creator to list of owned model IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedModels;

    /// @notice Array with all model ids, used for enumeration
    uint256[] private _allModels;

    /// @notice Mapping creator address to model count
    mapping(address => uint256) private _modelBalances;

    /// @notice Mapping model id to TIEx Model
    mapping(uint256 => Asset) private assets;

    /// @notice TIExShareCollections
    IAssetsRevenue public tiexShareCollections;

    function initialize(
        address __admin,
        IAssetsRevenue __tiexShareCollections
    ) public initializer {
        __AccessControl_init_unchained();
        __AccessControlEnumerable_init_unchained();

        tiexShareCollections = __tiexShareCollections;

        _grantRole(DEFAULT_ADMIN_ROLE, __admin);
    }

    ////////////////////////////////////////////////////////////////////////////
    // MODIFIERS
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Checks if modelId allocated exists.
     * @param assetId must be of existing ID of model.
     */
    modifier onlyExistingModelId(uint256 assetId) {
        if (!assetExists(assetId)) {
            revert AssetNotFound(assetId);
        }
        _;
    }

    /**
     * @notice Checks if modelId allocated exists.
     * @param __modelId uint256 must be of existing ID of model.
     */
    modifier onlyNotExistingModelId(uint256 __modelId) {
        if (assetExists(__modelId)) {
            revert AssetAlreadyExists(__modelId);
        }
        _;
    }

    ////////////////////////////////////////////////////////////////////////////
    // ADMIN
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @dev See {ITIExBaseIPAllocation-upgradeStubbedModelToTrainedModel}.
     */
    function upgradeStubbedModelToTrainedModel(
        uint256 assetId,
        bytes memory fingerprint
    ) external onlyRole(DEFAULT_ADMIN_ROLE) onlyExistingModelId(assetId) {
        // Check if the model is already trained, if so, revert the transaction
        if (assets[assetId].metadata.trained)
            revert ModelAlreadyTrained(assetId);

        // Check if the new model fingerprint is valid, if not, revert the transaction
        if (fingerprint.length == 0) revert InvalidMetadata(assetId);

        // Set the model as trained
        assets[assetId].metadata.trained = true;
        // Set the model version to 1
        assets[assetId].metadata.version = 1;
        // Update the model fingerprint with the new one
        assets[assetId].metadata.fingerprint = fingerprint;

        // Emit an event to log the model upgrade
        emit ModelUpgraded(assetId, assets[assetId].metadata);
    }

    /**
     * @dev See {ITIExBaseIPAllocation-upgradeModel}.
     */
    function upgradeAsset(
        uint256 assetId,
        bytes memory fingerprint
    ) external onlyRole(DEFAULT_ADMIN_ROLE) onlyExistingModelId(assetId) {
        // Check if the new model fingerprint is valid, if not, revert the transaction
        if (fingerprint.length == 0) revert InvalidMetadata(assetId);

        // Increment the version of the model
        assets[assetId].metadata.version++;
        // Update the model fingerprint with the new one
        assets[assetId].metadata.fingerprint = fingerprint;

        // Emit an event to log the model upgrade
        emit ModelUpgraded(assetId, assets[assetId].metadata);
    }

    /**
     * @dev See {ITIExBaseIPAllocation-updateModelMetadata}.
     */
    function updateAssetMetadata(
        uint256 __modelId,
        Metadata calldata __modelMetadata
    ) external onlyRole(DEFAULT_ADMIN_ROLE) onlyExistingModelId(__modelId) {
        // Check if the model metadata is valid
        bool validForMetadata = bytes(__modelMetadata.name).length > 0 &&
            bytes(__modelMetadata.description).length > 0 &&
            __modelMetadata.version > 0 &&
            __modelMetadata.fingerprint.length > 0 &&
            __modelMetadata.watermark.length > 0 &&
            __modelMetadata.performance > 0;

        if (!validForMetadata) revert InvalidMetadata(__modelId);
        // Update the model metadata
        assets[__modelId].metadata = __modelMetadata;

        // Emit an event to log the update of model metadata
        emit AssetMetadataUpdated(__modelId, assets[__modelId].metadata);
    }

    /**
     * @dev See {ITIExBaseIPAllocation-giveCreatorTIExIP}.
     */
    function createAsset(
        uint256 assetId,
        address creator,
        string calldata ipfsHash,
        Contribution[] calldata contributions,
        Metadata calldata metadata
    ) external onlyRole(DEFAULT_ADMIN_ROLE) onlyNotExistingModelId(assetId) {
        // Check if the creator address is valid
        if (creator == address(0)) {
            revert InvalidCreator(address(0));
        }

        // Add the model ID to the list of all model IDs
        _addModelToAllModelsEnumeration(assetId);
        // Add the model ID to the list of model IDs owned by the creator
        _addModelToCreatorEnumeration(creator, assetId);

        // Increase the balance of model IDs owned by the creator
        unchecked {
            // Will not overflow unless all 2**256 model ids are allocated to the same creator.
            // Given that models are allocated one by one, it is impossible in practice that
            // this ever happens. Might change if we allow batch allocating.
            _modelBalances[creator] += 1;
        }

        // Set the creator of the model ID
        assets[assetId].creator = creator;
        // Set the IPFS hash of the model's metadata
        assets[assetId].uri = ipfsHash;

        // If there are contributors, calculate the total contribution rate and add each contributor to the list of contributors for the model ID
        if (contributions.length > 0) {
            uint256 contributionRate = 0;
            // Iterate over each contributor
            for (uint256 i; i < contributions.length; i++) {
                // If the model does not exist, revert the transaction
                if (!assetExists(contributions[i].modelId))
                    revert AssetNotFound(contributions[i].modelId);
                // AdassetExistsibution rate of the current contributor to the total contribution rate
                contributionRate = contributionRate.add(
                    contributions[i].contributionRate
                );
                // Add the current contributor to the list of contributors for the model
                assets[assetId].contributedModels.push(contributions[i]);
            }

            // If the total contribution rate is not 10000 (representing 100%), revert the transaction
            if (contributionRate != 10000)
                revert InvalidContributionRate(contributionRate);
        } else {
            // If there are no new contributors, add a default contribution of 10000 (representing 100%) for the model itself
            assets[assetId].contributedModels.push(
                Contribution({modelId: assetId, contributionRate: 10000})
            );
        }

        // Check if the model metadata is valid
        bool validForMetadata = bytes(metadata.name).length > 0 &&
            bytes(metadata.description).length > 0 &&
            metadata.version == 1 &&
            metadata.fingerprint.length > 0 &&
            metadata.watermark.length > 0 &&
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
     * @dev See {ITIExBaseIPAllocation-updateContributionRates}.
     */
    function updateContributionRates(
        uint256 modelId,
        Contribution[] calldata contributions
    ) external onlyRole(DEFAULT_ADMIN_ROLE) onlyExistingModelId(modelId) {
        // Delete the existing contributions for the model
        delete assets[modelId].contributedModels;

        // If there are new contributors
        if (contributions.length > 0) {
            uint256 contributionRate = 0;
            // Iterate over each contributor
            for (uint256 i; i < contributions.length; i++) {
                // If the model does not exist, revert the transaction
                if (!assetExists(contributions[i].modelId))
                    revert AssetNotFound(contributions[i].modelId);
                // AdassetExistsibution rate of the current contributor to the total contribution rate
                contributionRate = contributionRate.add(
                    contributions[i].contributionRate
                );
                // Add the current contributor to the list of contributors for the model
                assets[modelId].contributedModels.push(contributions[i]);
            }

            // If the total contribution rate is not 10000 (representing 100%), revert the transaction
            if (contributionRate != 10000)
                revert InvalidContributionRate(contributionRate);
        } else {
            // If there are no new contributors, add a default contribution of 10000 (representing 100%) for the model itself
            assets[modelId].contributedModels.push(
                Contribution({modelId: modelId, contributionRate: 10000})
            );
        }

        // Emit an event to log the update of contribution rates
        emit ContributationRatesUpdated(
            modelId,
            assets[modelId].contributedModels
        );
    }

    /**
     * @dev See {ITIExBaseIPAllocation-removeModel}.
     */
    function removeAsset(
        uint256 assetId
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        address __creator = creatorOf(assetId);

        _removeModelFromCreatorEnumeration(__creator, assetId);
        _removeModelFromAllModelsEnumeration(assetId);

        // Decrease balance with checked arithmetic, because an `creatorOf` override may
        // invalidate the assumption that `_modelBalances[from] >= 1`.
        _modelBalances[__creator] -= 1;

        delete assets[assetId];

        tiexShareCollections.afterRemoveModel(assetId);

        emit AssetRemoved(__creator, address(0), assetId, block.timestamp);
    }

    /**
     * @dev See {ITIExBaseIPAllocation-editURI}.
     */
    function editUri(
        uint256 assetId,
        string calldata ipfsHash
    ) external onlyRole(DEFAULT_ADMIN_ROLE) onlyExistingModelId(assetId) {
        assets[assetId].uri = ipfsHash;

        emit AssetUriUpdated(assetId, ipfsHash);
    }

    ////////////////////////////////////////////////////////////////////////////
    // READ
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @dev See {ITIExBaseIPAllocation-getTIExModel}.
     */
    function getAsset(uint256 assetId) external view returns (Asset memory) {
        return assets[assetId];
    }

    /**
     * @dev See {ITIExBaseIPAllocation-modelBalanceOf}.
     */
    function assetBalanceOf(address creator) public view returns (uint256) {
        if (creator == address(0)) {
            revert InvalidCreator(address(0));
        }
        return _modelBalances[creator];
    }

    /**
     * @dev See {ITIExBaseIPAllocation-creatorOf}.
     */
    function creatorOf(uint256 assetId) public view returns (address) {
        address creator = assets[assetId].creator;
        if (creator == address(0)) {
            revert AssetNotFound(assetId);
        }
        return creator;
    }

    /**
     * @dev See {ITIExBaseIPAllocation-modelExists}.
     */
    function assetExists(uint256 assetId) public view returns (bool) {
        return assets[assetId].creator != address(0);
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
        return _ownedModels[creator][index];
    }

    /**
     * @dev See {ITIExBaseIPAllocation-totalModelSupply}.
     */
    function assetAmount() public view returns (uint256) {
        return _allModels.length;
    }

    /**
     * @dev See {ITIExBaseIPAllocation-modelByIndex}.
     */
    function assetByIndex(uint256 index) public view returns (uint256) {
        if (index >= assetAmount()) {
            revert OutOfBounds(address(0), index);
        }
        return _allModels[index];
    }

    /**
     * @dev See {ITIExBaseIPAllocation-modelsOfCreator}.
     */
    function creatorAssets(
        address creator
    ) public view returns (uint256[] memory) {
        uint256 modelCount = assetBalanceOf(creator);

        uint256[] memory modelsId = new uint256[](modelCount);
        for (uint256 i; i < modelCount; i++) {
            modelsId[i] = creatorAssetByIndex(creator, i);
        }
        return modelsId;
    }

    ////////////////////////////////////////////////////////////////////////////
    // PRIVATE
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Private function to add a model to this extension's model tracking data structures.
     * @param __modelId uint256 ID of the model to be added to the models list
     *
     */
    function _addModelToAllModelsEnumeration(uint256 __modelId) private {
        assets[__modelId].allAssetsIndex = _allModels.length;
        _allModels.push(__modelId);
    }

    /**
     * @notice Private function to add a model to this extension's ownership-tracking data structures.
     * @param __to address representing the new owner of the given model ID
     * @param __modelId uint256 ID of the model to be added to the models list of the given address
     *
     */
    function _addModelToCreatorEnumeration(
        address __to,
        uint256 __modelId
    ) private {
        uint256 length = assetBalanceOf(__to);
        _ownedModels[__to][length] = __modelId;
        assets[__modelId].ownedAssetsIndex = length;
    }

    /**
     * @notice Private function to remove a model from this extension's model tracking data structures.
     * This has O(1) time complexity, but alters the order of the _allModels array.
     * @param __modelId uint256 ID of the model to be removed from the models list
     *
     */
    function _removeModelFromAllModelsEnumeration(uint256 __modelId) private {
        // To prevent a gap in the models array, we store the last model in the index of the model to delete, and
        // then delete the last slot.

        uint256 lastModelIndex = _allModels.length - 1;
        uint256 modelIndex = assets[__modelId].allAssetsIndex;

        // When the model to delete is the last model. However, since this occurs so
        // an 'if' statement (like in _removeModelFromCreatorEnumeration)
        uint256 lastModelId = _allModels[lastModelIndex];

        _allModels[modelIndex] = lastModelId; // Move the last model to the slot of the to-delete model
        assets[lastModelId].allAssetsIndex = modelIndex; // Update the moved model's index

        // This also deletes the contents at the last position of the array
        delete assets[__modelId].allAssetsIndex;
        _allModels.pop();
    }

    /**
     * @notice Private function to remove a model from this extension's ownership-tracking data structures. Note that
     * while the model is not assigned a new creator, the `_ownedModelsIndex` mapping is _not_ updated: this allows for
     * gas optimizations e.g. when performing a allocate operation (avoiding double writes).
     * This has O(1) time complexity, but alters the order of the _ownedModels array.
     * @param __from address representing the previous creator of the given model ID
     * @param __modelId uint256 ID of the model to be removed from the models list of the given address
     *
     */
    function _removeModelFromCreatorEnumeration(
        address __from,
        uint256 __modelId
    ) private {
        // To prevent a gap in from's models array, we store the last model in the index of the model to delete, and
        // then delete the last slot

        uint256 lastModelIndex = assetBalanceOf(__from) - 1;
        uint256 modelIndex = assets[__modelId].ownedAssetsIndex;

        // When the model to delete is the last model
        if (modelIndex != lastModelIndex) {
            uint256 lastModelId = _ownedModels[__from][lastModelIndex];

            _ownedModels[__from][modelIndex] = lastModelId; // Move the last model to the slot of the to-delete model
            assets[lastModelId].ownedAssetsIndex = modelIndex; // Update the moved model's index
        }

        // This also deletes the contents at the last position of the array
        delete assets[__modelId].ownedAssetsIndex;
        delete _ownedModels[__from][lastModelIndex];
    }
}
