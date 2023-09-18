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


contract TIExBaseIPAllocationUpgradeable is Initializable, AccessControlEnumerableUpgradeable {

    using Strings for uint256;
    using SafeMath for uint256;
    
    // Struct to represent a contribution to a model
    struct Contribution {
        uint256 modelId; // The ID of the model
        uint256 contributionRate; // The rate of the contribution
    }

    // Struct to represent the metadata of a model
    struct ModelMetadata {
        string name; // The name of the model
        bytes32 ecosystemId; // The ID of the ecosystem the model belongs to
        uint256 version; // The version of the model
        string description; // A description of the model
        bytes modelFingerprint; // The fingerprint of the model
        bool trained; // Whether the model is trained or not
        bytes watermarkFingerprint; // The fingerprint of the watermark
        bytes watermarkSequence; // The sequence of the watermark
        uint256 performance; // The performance of the model
    }

    // Mapping from model ID to its metadata
    mapping(uint256 => ModelMetadata) private _modelMetadata;


    // Event emitted when a new TIEx IP is allocated to a creator
    event AllocateTIExIP(address provider, address indexed creator, uint256 indexed modelId, ModelMetadata modelMetadata, Contribution[] contribution, uint256 startTime);
    
    // Event emitted when a TIEx IP is removed
    event RemoveTIExIP(address creator, address to, uint256 indexed modelId, uint256 removedTime);
    
    // Event emitted when the URI of a TIEx model is updated
    event TIExModelURIUpdated(uint256 indexed modelId, string ipfsHash);
    
    // Event emitted when the contribution rates of a model are updated
    event ContributationRatesUpdated(uint256 indexed modelId, Contribution[] contributionRates);
    
    // Event emitted when a model is upgraded
    event UpgradeModel(uint256 indexed modelId, ModelMetadata oldModelMetadata, ModelMetadata newModelMetadata);
    
    // Event emitted when the metadata of a model is updated
    event UpdateModelMetadata(uint256 indexed modelId, ModelMetadata oldModelMetadata, ModelMetadata newModelMetadata);

    // Error thrown when an invalid creator address is provided
    error ErrorTIExIPInvalidCreator(address creator);
    
    // Error thrown when a model ID that is already allocated is used
    error ErrorTIExIPAllocatedAlready(uint256 modelId);
    
    // Error thrown when an invalid provider address is provided
    error ErrorTIExIPInvalidProvider(address provider);
    
    // Error thrown when an out of bounds index is used for a creator
    error ErrorTIExIPOutOfBoundsIndex(address creator, uint256 index);
    
    // Error thrown when a non-existent model ID is used
    error ErrorTIExIPModelIdNotFound(uint256 modelId);
    
    // Error thrown when an invalid contribution rate is used
    error ErrorTIExIPContributionRateInvalid(uint256 contributionRate);
    
    // Error thrown when a model that is already trained is used
    error ErrorTIExIPTrainedAlready(uint256 modelId);
    
    // Error thrown when invalid metadata is provided for a model
    error ErrorTIExIPInvalidMetadata(uint256 modelId);



    /// @notice Mapping from model ID to creator address
    mapping(uint256 => address) private _creators;

    /// @notice Mapping from creator to list of owned model IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedModels;

    /// @notice Mapping from model ID to index of the creator models list
    mapping(uint256 => uint256) private _ownedModelsIndex;

    /// @notice Array with all model ids, used for enumeration
    uint256[] private _allModels;

    /// @notice Mapping from model id to position in the allModels array
    mapping(uint256 => uint256) private _allModelsIndex;

    /// @notice Mapping creator address to model count
    mapping(address => uint256) private _modelBalances;

    /// @notice Mapping modelId to metadata(IPFS)
    mapping(uint256 => string) internal  _modelURIs;

    /// @notice Mapping model id to contriuted model list
    mapping(uint256 => Contribution[]) private _contributedModels;

    function __TIExBaseIPAllocation_init() internal onlyInitializing {
        __AccessControl_init_unchained();
		__AccessControlEnumerable_init_unchained();
        __TIExBaseIPAllocation_init_unchained();
    }

    function __TIExBaseIPAllocation_init_unchained() internal onlyInitializing { }

    ////////////////////////////////////////////////////////////////////////////
    // MODIFIERS
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Checks if modelId allocated exists.
     * @param __modelId must be of existing ID of model.
     */
    modifier onlyExistingModelId(uint256 __modelId) {
        if (!modelExists(__modelId)) {
            revert ErrorTIExIPModelIdNotFound(__modelId);
        }
        _;
    }

    /**
     * @notice Checks if modelId allocated exists.
     * @param __modelId uint256 must be of existing ID of model.
     */
    modifier onlyNotExistingModelId(uint256 __modelId) {
        if (modelExists(__modelId)) {
            revert ErrorTIExIPAllocatedAlready(__modelId);
        }
        _;
    }

    ////////////////////////////////////////////////////////////////////////////
    // ADMIN
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Upgrades a stubbed model to a trained model.
     * @param __modelId uint256 must exist.
     * @param __newModelFingerprint bytes is the new fingerprint of the model.
     *
     * Emits a {UpgradeModel} event.
     *
     * Requirements:
     * - Must be called by an address with the `DEFAULT_ADMIN_ROLE` role.
     * - The model with the given `__modelId` must not be trained already.
     * - The `__newModelFingerprint` must not be empty.
     */
    function upgradeStubbedModelToTrainedModel(uint256 __modelId, bytes memory __newModelFingerprint) external onlyRole(DEFAULT_ADMIN_ROLE) onlyExistingModelId(__modelId) {
        // Check if the model is already trained, if so, revert the transaction
        if(_modelMetadata[__modelId].trained) revert ErrorTIExIPTrainedAlready(__modelId);
        
        // Check if the new model fingerprint is valid, if not, revert the transaction
        if (__newModelFingerprint.length == 0) revert ErrorTIExIPInvalidMetadata(__modelId);
        
        // Store the old model metadata before the upgrade
        ModelMetadata memory oldModelMetadata = _modelMetadata[__modelId];

        // Set the model as trained
        _modelMetadata[__modelId].trained = true;
        // Set the model version to 1
        _modelMetadata[__modelId].version = 1;
        // Update the model fingerprint with the new one
        _modelMetadata[__modelId].modelFingerprint = __newModelFingerprint;

        // Emit an event to log the model upgrade
        emit UpgradeModel(__modelId, oldModelMetadata, _modelMetadata[__modelId]);
    }


    /**
     * @notice Upgrades a model by updating its fingerprint and incrementing its version.
     * @param __modelId The ID of the model to be upgraded.
     * @param __newModelFingerprint The new fingerprint of the model.
     *
     * Emits an {UpgradeModel} event.
     *
     * Requirements:
     * - The caller must have the `DEFAULT_ADMIN_ROLE`.
     * - The model with the given `__modelId` must exist.
     * - The `__newModelFingerprint` must not be empty.
     */
    function upgradeModel(uint256 __modelId, bytes memory __newModelFingerprint) external onlyRole(DEFAULT_ADMIN_ROLE) onlyExistingModelId(__modelId) {
        // Store the old model metadata before the upgrade
        ModelMetadata memory oldModelMetadata = _modelMetadata[__modelId];
        
        // Check if the new model fingerprint is valid, if not, revert the transaction
        if (__newModelFingerprint.length == 0) revert ErrorTIExIPInvalidMetadata(__modelId);

        // Increment the version of the model
        _modelMetadata[__modelId].version++;
        // Update the model fingerprint with the new one
        _modelMetadata[__modelId].modelFingerprint = __newModelFingerprint;

        // Emit an event to log the model upgrade
        emit UpgradeModel(__modelId, oldModelMetadata, _modelMetadata[__modelId]);
    }

    /**
     * @notice Updates the metadata of a model.
     * @param __modelId The ID of the model to be updated.
     * @param __modelMetadata The new metadata of the model.
     *
     * Emits an {UpdateModelMetadata} event.
     *
     * Requirements:
     * - The caller must have the `DEFAULT_ADMIN_ROLE`.
     * - The model with the given `__modelId` must exist.
     * - The `__modelMetadata` must be valid.
     */
    function updateModelMetadata(uint256 __modelId, ModelMetadata calldata __modelMetadata) external onlyRole(DEFAULT_ADMIN_ROLE) onlyExistingModelId(__modelId) {
        // Store the old model metadata before the update
        ModelMetadata memory oldModelMetadata = _modelMetadata[__modelId];
        // Check if the model metadata is valid
        bool validForMetadata = bytes(__modelMetadata.name).length > 0 
            && bytes(__modelMetadata.description).length > 0 
            && __modelMetadata.ecosystemId.length > 0 
            && __modelMetadata.version > 0
            && __modelMetadata.modelFingerprint.length > 0
            && __modelMetadata.watermarkFingerprint.length > 0
            && __modelMetadata.watermarkSequence.length > 0
            && __modelMetadata.performance > 0;

        if (!validForMetadata) revert ErrorTIExIPInvalidMetadata(__modelId);
        // Update the model metadata
        _modelMetadata[__modelId] = __modelMetadata;

        // Emit an event to log the update of model metadata
        emit UpdateModelMetadata(__modelId, oldModelMetadata, _modelMetadata[__modelId]);
    }

    /**
     * @notice Allocates `modelId` as TIEx IP to `creator`.
     * @param __modelId uint256 must not exist.
     * @param __creator address cannot be the zero address.
     * @param __ipfsHash string is for Metadata of model
     * @param __contributors Contribution struct is for contribution rate of each model
     *
     * Emits a {AllocateTIExIP} event.
     *
     * Requirements:
     * - Must be called by an address with the `DEFAULT_ADMIN_ROLE` role.
     * - The model with the given `__modelId` must not exist.
     */
    function giveCreatorTIExIP(
        uint256 __modelId,
        address __creator,
        string calldata __ipfsHash,
        Contribution[] calldata __contributors,
        ModelMetadata calldata __modelMetadata
    ) external onlyRole(DEFAULT_ADMIN_ROLE) onlyNotExistingModelId(__modelId) {

        // Check if the creator address is valid
        if (__creator == address(0)) {
            revert ErrorTIExIPInvalidCreator(address(0));
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
        _creators[__modelId] = __creator;
        // Set the IPFS hash of the model's metadata
        _modelURIs[__modelId] = __ipfsHash;
        
        // If there are contributors, calculate the total contribution rate and add each contributor to the list of contributors for the model ID
        if (__contributors.length > 0) {
            uint256 contributionRate = 0;
            // Iterate over each contributor
            for(uint256 i; i < __contributors.length; i++) {
                // If the model does not exist, revert the transaction
                if(!modelExists(__contributors[i].modelId)) revert ErrorTIExIPModelIdNotFound(__contributors[i].modelId);
                // Add the contribution rate of the current contributor to the total contribution rate
                contributionRate = contributionRate.add(__contributors[i].contributionRate);
                // Add the current contributor to the list of contributors for the model
                _contributedModels[__modelId].push(__contributors[i]);
            }

            // If the total contribution rate is not 10000 (representing 100%), revert the transaction
            if(contributionRate != 10000) revert ErrorTIExIPContributionRateInvalid(contributionRate);

        } else {
            // If there are no new contributors, add a default contribution of 10000 (representing 100%) for the model itself
            _contributedModels[__modelId].push(Contribution({
                modelId: __modelId,
                contributionRate: 10000
            }));

        }

        // Check if the model metadata is valid
        bool validForMetadata = bytes(__modelMetadata.name).length > 0 
            && bytes(__modelMetadata.description).length > 0 
            && __modelMetadata.ecosystemId.length > 0 
            && __modelMetadata.version == 1
            && __modelMetadata.modelFingerprint.length > 0
            && __modelMetadata.watermarkFingerprint.length > 0
            && __modelMetadata.watermarkSequence.length > 0
            && __modelMetadata.performance > 0;

        if (!validForMetadata) revert ErrorTIExIPInvalidMetadata(__modelId);
        // Set the model metadata
        _modelMetadata[__modelId] = __modelMetadata;

        // Emit an event to log the allocation of the model ID
        emit AllocateTIExIP(msg.sender, __creator, __modelId, __modelMetadata, _contributedModels[__modelId], block.timestamp);

    }

    /**
     * @notice Updates the contribution rates of a model.
     *
     * Emits a {ContributationRatesUpdated} event.
     *
     * Requirements:
     * - Must be called by an address with the `DEFAULT_ADMIN_ROLE` role.
     * - The model with the given `__modelId` must exist.
     */
    function updateContributionRates(uint256 __modelId, Contribution[] calldata __contributors) external onlyRole(DEFAULT_ADMIN_ROLE) onlyExistingModelId(__modelId) {
        // Delete the existing contributions for the model
        delete _contributedModels[__modelId];

        // If there are new contributors
        if (__contributors.length > 0) {
            uint256 contributionRate = 0;
            // Iterate over each contributor
            for(uint256 i; i < __contributors.length; i++) {
                // If the model does not exist, revert the transaction
                if(!modelExists(__contributors[i].modelId)) revert ErrorTIExIPModelIdNotFound(__contributors[i].modelId);
                // Add the contribution rate of the current contributor to the total contribution rate
                contributionRate = contributionRate.add(__contributors[i].contributionRate);
                // Add the current contributor to the list of contributors for the model
                _contributedModels[__modelId].push(__contributors[i]);
            }

            // If the total contribution rate is not 10000 (representing 100%), revert the transaction
            if(contributionRate != 10000) revert ErrorTIExIPContributionRateInvalid(contributionRate);
        } else {
            // If there are no new contributors, add a default contribution of 10000 (representing 100%) for the model itself
            _contributedModels[__modelId].push(Contribution({
                modelId: __modelId,
                contributionRate: 10000
            }));
        }

        // Emit an event to log the update of contribution rates
        emit ContributationRatesUpdated(__modelId, _contributedModels[__modelId]);
    }

    /**
     * @notice Destroys `modelId`.
     * @param __modelId must exist.
     *
     * Emits a {RemoveTIExIP} event.
     * 
     * Requirement:
     * - Must be called by an address with the `DEFAULT_ADMIN_ROLE` role.
     */
    function removeModel(uint256 __modelId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        address __creator = creatorOf(__modelId);

        _removeModelFromCreatorEnumeration(__creator, __modelId);
        _removeModelFromAllModelsEnumeration(__modelId);

        // Decrease balance with checked arithmetic, because an `creatorOf` override may
        // invalidate the assumption that `_modelBalances[from] >= 1`.
        _modelBalances[__creator] -= 1;
        
        delete _contributedModels[__modelId];
        delete _creators[__modelId];

        _afterRemoveModel(__modelId);

        emit RemoveTIExIP(__creator, address(0), __modelId, block.timestamp);
    }

    /**
     * @notice Used to edit the model URI.
     *
     * Emits a {TIExModelURIUpdated} event.
     * 
     * Requirements:
     * - Must be called by an address with the `DEFAULT_ADMIN_ROLE` role.
     * - The model with the given `__modelId` must exist.
     */
    function editURI(uint256 __modelId, string calldata __ipfsHash)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        onlyExistingModelId(__modelId)
    {
        _modelURIs[__modelId] = __ipfsHash;

        emit TIExModelURIUpdated(__modelId, __ipfsHash);
    }

    ////////////////////////////////////////////////////////////////////////////
    // INTERNAL
    ////////////////////////////////////////////////////////////////////////////

    /**
     * @notice Returns the creator of the `__modelId`. Does NOT revert if model doesn't exist
     *
     */
    function _creatorOf(uint256 __modelId) internal view returns (address) {
        return _creators[__modelId];
    }

    /**
     * @notice Used to clean up data related to a model after it has been removed.
    */
    function _afterRemoveModel(
        uint256 __modelId
    ) internal virtual {}

    ////////////////////////////////////////////////////////////////////////////
    // READ
    ////////////////////////////////////////////////////////////////////////////

    /**
    * @notice Used to get the detail of model
    * @param __modelId uint256 must exist
    *
    */
    function getModelDetail(uint256 __modelId) public view returns(address creator, string memory ipfsHash, Contribution[] memory contributors) {
        creator = creatorOf(__modelId);
        ipfsHash = _modelURIs[__modelId];
        contributors = _contributedModels[__modelId];
    }

    /**
     * @notice Returns the number of models in ``creator``'s account.
     *
     */
    function modelBalanceOf(address __creator) public view returns (uint256) {
        if (__creator == address(0)) {
            revert ErrorTIExIPInvalidCreator(address(0));
        }
        return _modelBalances[__creator];
    }

    /**
     * @notice Returns the creator of the `modelId` model.
     * @param __modelId uint256 ID of the model must exist.
     *
     */
    function creatorOf(uint256 __modelId) public view returns (address) {
        address creator = _creatorOf(__modelId);
        if (creator == address(0)) {
            revert ErrorTIExIPModelIdNotFound(__modelId);
        }
        return creator;
    }

    /**
     * @notice Returns whether `__modelId` exists.
     *
     * Models start existing when TIEx are allocated,
     * and stop existing when TIEx are removed (`removeModel`).
     *
     */
    function modelExists(uint256 __modelId) public view returns (bool) {
        return _creatorOf(__modelId) != address(0);
    }

    /**
     * @notice Returns a model ID owned by `creator` at a given `index` of its model list.
     * Use along with {modelBalanceOf} to enumerate all of ``creator``'s models.
     *
     */
    function modelOfCreatorByIndex(address __creator, uint256 __index)
        public
        view
        returns (uint256)
    {
        if (__index >= modelBalanceOf(__creator)) {
            revert ErrorTIExIPOutOfBoundsIndex(__creator, __index);
        }
        return _ownedModels[__creator][__index];
    }

    /**
     * @notice Returns the total amount of models stored by the contract.
     *
     */
    function totalModelSupply() public view returns (uint256) {
        return _allModels.length;
    }

    /**
     * @notice Returns a model ID at a given `index` of all the models stored by the contract.
     * Use along with {totalModelSupply} to enumerate all models.
     *
     */
    function modelByIndex(uint256 __index) public view returns (uint256) {
        if (__index >= totalModelSupply()) {
            revert ErrorTIExIPOutOfBoundsIndex(address(0), __index);
        }
        return _allModels[__index];
    }

    /**
     * @notice Returns model ids allocated from account of creator.
     *
     */
    function modelsOfCreator(address __creator)
        public
        view
        returns (uint256[] memory)
    {
        uint256 modelCount = modelBalanceOf(__creator);

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
        _allModelsIndex[__modelId] = _allModels.length;
        _allModels.push(__modelId);
    }

    /**
     * @notice Private function to add a model to this extension's ownership-tracking data structures.
     * @param __to address representing the new owner of the given model ID
     * @param __modelId uint256 ID of the model to be added to the models list of the given address
     *
     */
    function _addModelToCreatorEnumeration(address __to, uint256 __modelId)
        private
    {
        uint256 length = modelBalanceOf(__to);
        _ownedModels[__to][length] = __modelId;
        _ownedModelsIndex[__modelId] = length;
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
        uint256 modelIndex = _allModelsIndex[__modelId];

        // When the model to delete is the last model. However, since this occurs so
        // an 'if' statement (like in _removeModelFromCreatorEnumeration)
        uint256 lastModelId = _allModels[lastModelIndex];

        _allModels[modelIndex] = lastModelId; // Move the last model to the slot of the to-delete model
        _allModelsIndex[lastModelId] = modelIndex; // Update the moved model's index

        // This also deletes the contents at the last position of the array
        delete _allModelsIndex[__modelId];
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
    function _removeModelFromCreatorEnumeration(address __from, uint256 __modelId)
        private
    {
        // To prevent a gap in from's models array, we store the last model in the index of the model to delete, and
        // then delete the last slot

        uint256 lastModelIndex = modelBalanceOf(__from) - 1;
        uint256 modelIndex = _ownedModelsIndex[__modelId];

        // When the model to delete is the last model
        if (modelIndex != lastModelIndex) {
            uint256 lastModelId = _ownedModels[__from][lastModelIndex];

            _ownedModels[__from][modelIndex] = lastModelId; // Move the last model to the slot of the to-delete model
            _ownedModelsIndex[lastModelId] = modelIndex; // Update the moved model's index
        }

        // This also deletes the contents at the last position of the array
        delete _ownedModelsIndex[__modelId];
        delete _ownedModels[__from][lastModelIndex];
    }

}
