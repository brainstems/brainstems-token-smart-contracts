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
    
    struct Contribution {
        uint256 modelId;
        uint256 contributionRate;
    }

    event AllocateTIExIP(address provider, address creator, uint256 modelId, Contribution[], uint256 startTime);
    event RemoveTIExIP(address creator, address to, uint256 modelId, uint256 removedTime);
    event TIExModelURIUpdated(uint256 modelId, string ipfsHash);
    event ContributationRatesUpdated(uint256 modelId, Contribution[] contributionRates);

    error ErrorTIExIPInvalidCreator(address creator);
    error ErrorTIExIPAllocatedAlready(uint256 modelId);
    error ErrorTIExIPInvalidProvider(address provider);
    error ErrorTIExIPOutOfBoundsIndex(address creator, uint256 index);
    error ErrorTIExIPModelIdNotFound(uint256 modelId);
    error ErrorTIExContributionRateInvalid(uint256 contributionRate);

    // Mapping from model ID to creator address
    mapping(uint256 => address) private _creators;

    // Mapping from creator to list of owned model IDs
    mapping(address => mapping(uint256 => uint256)) private _ownedModels;

    // Mapping from model ID to index of the creator models list
    mapping(uint256 => uint256) private _ownedModelsIndex;

    // Array with all model ids, used for enumeration
    uint256[] private _allModels;

    // Mapping from model id to position in the allModels array
    mapping(uint256 => uint256) private _allModelsIndex;

    /// @notice Mapping creator address to model count
    mapping(address => uint256) private _modelBalances;

    /// @notice Mapping modelId to metadata(IPFS)
    mapping(uint256 => string) internal  _modelURIs;

    // Mapping model id to contriuted model list
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
     * @notice Allocates `modelId` as TIEx IP to `creator`.
     * @param __modelId uint256 must not exist.
     * @param __creator address cannot be the zero address.
     * @param __ipfsHash string is for Metadata of model
     * @param __contributors Contribution struct is for contribution rate of each model
     *
     * Emits a {AllocateTIExIP} event.
     *
     */
    function giveCreatorTIExIP(
        uint256 __modelId,
        address __creator,
        string calldata __ipfsHash,
        Contribution[] calldata __contributors
    ) external onlyRole(DEFAULT_ADMIN_ROLE) onlyNotExistingModelId(__modelId) {
        if (__creator == address(0)) {
            revert ErrorTIExIPInvalidCreator(address(0));
        }

        _addModelToAllModelsEnumeration(__modelId);
        _addModelToCreatorEnumeration(__creator, __modelId);

        unchecked {
            // Will not overflow unless all 2**256 model ids are allocated to the same creator.
            // Given that models are allocated one by one, it is impossible in practice that
            // this ever happens. Might change if we allow batch allocating.
            _modelBalances[__creator] += 1;
        }


        _creators[__modelId] = __creator;
        _modelURIs[__modelId] = __ipfsHash;

        if (__contributors.length > 0) {
            uint256 contributionRate = 0;
            for(uint256 i; i < __contributors.length; i++) {
                if(!modelExists(__contributors[i].modelId)) revert ErrorTIExIPModelIdNotFound(__contributors[i].modelId);
                contributionRate = contributionRate.add(__contributors[i].contributionRate);
                _contributedModels[__modelId].push(__contributors[i]);
            }

            if(contributionRate != 10000) revert ErrorTIExContributionRateInvalid(contributionRate);

        } else {
            _contributedModels[__modelId].push(Contribution({
                modelId: __modelId,
                contributionRate: 10000
            }));

        }

        emit AllocateTIExIP(msg.sender, __creator, __modelId, _contributedModels[__modelId], block.timestamp);

    }

    /**
    * @notice Updates contribution rates of model
    *
    * Emits a {ContributationRatesUpdated} event.
    *
    */

    function updateContributionRates(uint256 __modelId, Contribution[] calldata __contributors) external onlyRole(DEFAULT_ADMIN_ROLE) onlyExistingModelId(__modelId) {
        delete _contributedModels[__modelId];

        if (__contributors.length > 0) {
            uint256 contributionRate = 0;
            for(uint256 i; i < __contributors.length; i++) {
                if(!modelExists(__contributors[i].modelId)) revert ErrorTIExIPModelIdNotFound(__contributors[i].modelId);
                contributionRate = contributionRate.add(__contributors[i].contributionRate);
                _contributedModels[__modelId].push(__contributors[i]);
            }

            if(contributionRate != 10000) revert ErrorTIExContributionRateInvalid(contributionRate);


        } else {
            _contributedModels[__modelId].push(Contribution({
                modelId: __modelId,
                contributionRate: 10000
            }));
        }

        emit ContributationRatesUpdated(__modelId, _contributedModels[__modelId]);
    }

    /**
     * @notice Destroys `modelId`.
     * @param __modelId must exist.
     *
     * Emits a {RemoveTIExIP} event.
     *
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
    * @notice Used to get detailed model information
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
