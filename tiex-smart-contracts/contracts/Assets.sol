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
        if (!modelExists(assetId)) {
            revert ErrorAssetNotFound(assetId);
        }
        _;
    }

    /**
     * @notice Checks if modelId allocated exists.
     * @param __modelId uint256 must be of existing ID of model.
     */
    modifier onlyNotExistingModelId(uint256 __modelId) {
        if (modelExists(__modelId)) {
            revert ErrorAlreadyAllocated(__modelId);
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
        uint256 __modelId,
        bytes memory __newModelFingerprint
    ) external onlyRole(DEFAULT_ADMIN_ROLE) onlyExistingModelId(__modelId) {
        // Check if the model is already trained, if so, revert the transaction
        if (assets[__modelId].metadata.trained)
            revert ErrorAlreadyTrained(__modelId);

        // Check if the new model fingerprint is valid, if not, revert the transaction
        if (__newModelFingerprint.length == 0)
            revert ErrorInvalidMetadata(__modelId);

        // Set the model as trained
        assets[__modelId].metadata.trained = true;
        // Set the model version to 1
        assets[__modelId].metadata.version = 1;
        // Update the model fingerprint with the new one
        assets[__modelId].metadata.fingerprint = __newModelFingerprint;

        // Emit an event to log the model upgrade
        emit UpgradeAsset(__modelId, assets[__modelId].metadata);
    }

    /**
     * @dev See {ITIExBaseIPAllocation-upgradeModel}.
     */
    function upgradeAsset(
        uint256 __modelId,
        bytes memory __newModelFingerprint
    ) external onlyRole(DEFAULT_ADMIN_ROLE) onlyExistingModelId(__modelId) {
        // Check if the new model fingerprint is valid, if not, revert the transaction
        if (__newModelFingerprint.length == 0)
            revert ErrorInvalidMetadata(__modelId);

        // Increment the version of the model
        assets[__modelId].metadata.version++;
        // Update the model fingerprint with the new one
        assets[__modelId].metadata.fingerprint = __newModelFingerprint;

        // Emit an event to log the model upgrade
        emit UpgradeAsset(__modelId, assets[__modelId].metadata);
    }

    /**
     * @dev See {ITIExBaseIPAllocation-updateModelMetadata}.
     */
    function updateModelMetadata(
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

        if (!validForMetadata) revert ErrorInvalidMetadata(__modelId);
        // Update the model metadata
        assets[__modelId].metadata = __modelMetadata;

        // Emit an event to log the update of model metadata
        emit UpdateAssetMetadata(__modelId, assets[__modelId].metadata);
    }

    /**
     * @dev See {ITIExBaseIPAllocation-giveCreatorTIExIP}.
     */
    function giveCreatorTIExIP(
        uint256 __modelId,
        address __creator,
        string calldata __ipfsHash,
        Contribution[] calldata __contributors,
        Metadata calldata __modelMetadata
    ) external onlyRole(DEFAULT_ADMIN_ROLE) onlyNotExistingModelId(__modelId) {
        // Check if the creator address is valid
        if (__creator == address(0)) {
            revert ErrorInvalidCreator(address(0));
        }

        // Add the model ID to the list of all model IDs
        _addModelToAllModelsEnumeration(__modelId);
        // Add the model ID to the list of model IDs owned by the creator
        _addModelToCreatorEnumeration(__creator, __modelId);

        // Increase the balance of model IDs owned by the creator
        unchecked {
            // Will not overflow unless all 2**256 model ids are allocated to the same creator.
            // Given that models are allocated one by one, it is impossible in practice that
            // this ever happens. Might change if we allow batch allocating.
            _modelBalances[__creator] += 1;
        }

        // Set the creator of the model ID
        assets[__modelId].creator = __creator;
        // Set the IPFS hash of the model's metadata
        assets[__modelId].uri = __ipfsHash;

        // If there are contributors, calculate the total contribution rate and add each contributor to the list of contributors for the model ID
        if (__contributors.length > 0) {
            uint256 contributionRate = 0;
            // Iterate over each contributor
            for (uint256 i; i < __contributors.length; i++) {
                // If the model does not exist, revert the transaction
                if (!modelExists(__contributors[i].modelId))
                    revert ErrorAssetNotFound(__contributors[i].modelId);
                // Add the contribution rate of the current contributor to the total contribution rate
                contributionRate = contributionRate.add(
                    __contributors[i].contributionRate
                );
                // Add the current contributor to the list of contributors for the model
                assets[__modelId].contributedModels.push(__contributors[i]);
            }

            // If the total contribution rate is not 10000 (representing 100%), revert the transaction
            if (contributionRate != 10000)
                revert ErrorInvalidContributionRate(contributionRate);
        } else {
            // If there are no new contributors, add a default contribution of 10000 (representing 100%) for the model itself
            assets[__modelId].contributedModels.push(
                Contribution({modelId: __modelId, contributionRate: 10000})
            );
        }

        // Check if the model metadata is valid
        bool validForMetadata = bytes(__modelMetadata.name).length > 0 &&
            bytes(__modelMetadata.description).length > 0 &&
            __modelMetadata.version == 1 &&
            __modelMetadata.fingerprint.length > 0 &&
            __modelMetadata.watermark.length > 0 &&
            __modelMetadata.performance > 0;

        if (!validForMetadata) revert ErrorInvalidMetadata(__modelId);
        // Set the model metadata
        assets[__modelId].metadata = __modelMetadata;

        // Emit an event to log the allocation of the model ID
        emit AllocateIP(
            msg.sender,
            __modelId,
            assets[__modelId],
            block.timestamp
        );
    }

    /**
     * @dev See {ITIExBaseIPAllocation-updateContributionRates}.
     */
    function updateContributionRates(
        uint256 __modelId,
        Contribution[] calldata __contributors
    ) external onlyRole(DEFAULT_ADMIN_ROLE) onlyExistingModelId(__modelId) {
        // Delete the existing contributions for the model
        delete assets[__modelId].contributedModels;

        // If there are new contributors
        if (__contributors.length > 0) {
            uint256 contributionRate = 0;
            // Iterate over each contributor
            for (uint256 i; i < __contributors.length; i++) {
                // If the model does not exist, revert the transaction
                if (!modelExists(__contributors[i].modelId))
                    revert ErrorAssetNotFound(__contributors[i].modelId);
                // Add the contribution rate of the current contributor to the total contribution rate
                contributionRate = contributionRate.add(
                    __contributors[i].contributionRate
                );
                // Add the current contributor to the list of contributors for the model
                assets[__modelId].contributedModels.push(__contributors[i]);
            }

            // If the total contribution rate is not 10000 (representing 100%), revert the transaction
            if (contributionRate != 10000)
                revert ErrorInvalidContributionRate(contributionRate);
        } else {
            // If there are no new contributors, add a default contribution of 10000 (representing 100%) for the model itself
            assets[__modelId].contributedModels.push(
                Contribution({modelId: __modelId, contributionRate: 10000})
            );
        }

        // Emit an event to log the update of contribution rates
        emit ContributationRatesUpdated(
            __modelId,
            assets[__modelId].contributedModels
        );
    }

    /**
     * @dev See {ITIExBaseIPAllocation-removeModel}.
     */
    function removeModel(
        uint256 __modelId
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        address __creator = creatorOf(__modelId);

        _removeModelFromCreatorEnumeration(__creator, __modelId);
        _removeModelFromAllModelsEnumeration(__modelId);

        // Decrease balance with checked arithmetic, because an `creatorOf` override may
        // invalidate the assumption that `_modelBalances[from] >= 1`.
        _modelBalances[__creator] -= 1;

        delete assets[__modelId];

        tiexShareCollections.afterRemoveModel(__modelId);

        emit RemoveIP(__creator, address(0), __modelId, block.timestamp);
    }

    /**
     * @dev See {ITIExBaseIPAllocation-editURI}.
     */
    function editURI(
        uint256 __modelId,
        string calldata __ipfsHash
    ) external onlyRole(DEFAULT_ADMIN_ROLE) onlyExistingModelId(__modelId) {
        assets[__modelId].uri = __ipfsHash;

        emit assetUriUpdated(__modelId, __ipfsHash);
    }

    ////////////////////////////////////////////////////////////////////////////
    // READ
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @dev See {ITIExBaseIPAllocation-getTIExModel}.
     */
    function getAsset(uint256 __modelId) external view returns (Asset memory) {
        return assets[__modelId];
    }

    /**
     * @dev See {ITIExBaseIPAllocation-modelBalanceOf}.
     */
    function assetBalanceOf(address __creator) public view returns (uint256) {
        if (__creator == address(0)) {
            revert ErrorInvalidCreator(address(0));
        }
        return _modelBalances[__creator];
    }

    /**
     * @dev See {ITIExBaseIPAllocation-creatorOf}.
     */
    function creatorOf(uint256 __modelId) public view returns (address) {
        address creator = assets[__modelId].creator;
        if (creator == address(0)) {
            revert ErrorAssetNotFound(__modelId);
        }
        return creator;
    }

    /**
     * @dev See {ITIExBaseIPAllocation-modelExists}.
     */
    function modelExists(uint256 __modelId) public view returns (bool) {
        return assets[__modelId].creator != address(0);
    }

    /**
     * @dev See {ITIExBaseIPAllocation-modelOfCreatorByIndex}.
     */
    function modelOfCreatorByIndex(
        address __creator,
        uint256 __index
    ) public view returns (uint256) {
        if (__index >= assetBalanceOf(__creator)) {
            revert ErrorOutOfBounds(__creator, __index);
        }
        return _ownedModels[__creator][__index];
    }

    /**
     * @dev See {ITIExBaseIPAllocation-totalModelSupply}.
     */
    function totalModelSupply() public view returns (uint256) {
        return _allModels.length;
    }

    /**
     * @dev See {ITIExBaseIPAllocation-modelByIndex}.
     */
    function modelByIndex(uint256 __index) public view returns (uint256) {
        if (__index >= totalModelSupply()) {
            revert ErrorOutOfBounds(address(0), __index);
        }
        return _allModels[__index];
    }

    /**
     * @dev See {ITIExBaseIPAllocation-modelsOfCreator}.
     */
    function modelsOfCreator(
        address __creator
    ) public view returns (uint256[] memory) {
        uint256 modelCount = assetBalanceOf(__creator);

        uint256[] memory modelsId = new uint256[](modelCount);
        for (uint256 i; i < modelCount; i++) {
            modelsId[i] = modelOfCreatorByIndex(__creator, i);
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
