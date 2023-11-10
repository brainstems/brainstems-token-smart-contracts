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

interface ITIExBaseIPAllocation {
    // Struct to represent a contribution to a model
    // TODO: revise this
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

    struct Asset {
        address creator;
        Contribution[] contributedModels;
        ModelMetadata modelMetadata;
        uint256 allModelsIndex;
        uint256 ownedModelsIndex;
        string modelURI;
    }

    // Event emitted when a new TIEx IP is allocated to a creator
    event AllocateTIExIP(
        address provider,
        uint256 indexed modelId,
        Asset TIExModel,
        uint256 startTime
    );

    // Event emitted when a TIEx IP is removed
    event RemoveTIExIP(
        address creator,
        address to,
        uint256 indexed modelId,
        uint256 removedTime
    );

    // Event emitted when the URI of a TIEx model is updated
    event TIExModelURIUpdated(uint256 indexed modelId, string ipfsHash);

    // Event emitted when the contribution rates of a model are updated
    event ContributationRatesUpdated(
        uint256 indexed modelId,
        Contribution[] contributionRates
    );

    // Event emitted when a model is upgraded
    event UpgradeModel(uint256 indexed modelId, ModelMetadata newModelMetadata);

    // Event emitted when the metadata of a model is updated
    event UpdateModelMetadata(
        uint256 indexed modelId,
        ModelMetadata newModelMetadata
    );

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
    function upgradeStubbedModelToTrainedModel(
        uint256 __modelId,
        bytes memory __newModelFingerprint
    ) external;

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
    function upgradeModel(
        uint256 __modelId,
        bytes memory __newModelFingerprint
    ) external;

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
    function updateModelMetadata(
        uint256 __modelId,
        ModelMetadata calldata __modelMetadata
    ) external;

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
    ) external;

    /**
     * @notice Updates the contribution rates of a model.
     *
     * Emits a {ContributationRatesUpdated} event.
     *
     * Requirements:
     * - Must be called by an address with the `DEFAULT_ADMIN_ROLE` role.
     * - The model with the given `__modelId` must exist.
     */
    function updateContributionRates(
        uint256 __modelId,
        Contribution[] calldata __contributors
    ) external;

    /**
     * @notice Destroys `modelId`.
     * @param __modelId must exist.
     *
     * Emits a {RemoveTIExIP} event.
     *
     * Requirement:
     * - Must be called by an address with the `DEFAULT_ADMIN_ROLE` role.
     */
    function removeModel(uint256 __modelId) external;

    /**
     * @notice Used to edit the model URI.
     *
     * Emits a {TIExModelURIUpdated} event.
     *
     * Requirements:
     * - Must be called by an address with the `DEFAULT_ADMIN_ROLE` role.
     * - The model with the given `__modelId` must exist.
     */
    function editURI(uint256 __modelId, string calldata __ipfsHash) external;

    /**
     * @notice Used to get the detail of model
     * @param __modelId uint256 must exist
     */
    function getAsset(
        uint256 __modelId
    ) external view returns (Asset memory);

    /**
     * @notice Returns the number of models in ``creator``'s account.
     */
    function assetBalanceOf(address __creator) external view returns (uint256);

    /**
     * @notice Returns the creator of the `modelId` model.
     * @param __modelId uint256 ID of the model must exist.
     */
    function creatorOf(uint256 __modelId) external view returns (address);

    /**
     * @notice Returns whether `__modelId` exists.
     *
     * Models start existing when TIEx are allocated,
     * and stop existing when TIEx are removed (`removeModel`).
     */
    function modelExists(uint256 __modelId) external view returns (bool);

    /**
     * @notice Returns a model ID owned by `creator` at a given `index` of its model list.
     * Use along with {modelBalanceOf} to enumerate all of ``creator``'s models.
     */
    function modelOfCreatorByIndex(
        address __creator,
        uint256 __index
    ) external view returns (uint256);

    /**
     * @notice Returns the total amount of models stored by the contract.
     */
    function totalModelSupply() external view returns (uint256);

    /**
     * @notice Returns a model ID at a given `index` of all the models stored by the contract.
     * Use along with {totalModelSupply} to enumerate all models.
     */
    function modelByIndex(uint256 __index) external view returns (uint256);

    /**
     * @notice Returns model ids allocated from account of creator.
     */
    function modelsOfCreator(
        address __creator
    ) external view returns (uint256[] memory);
}
