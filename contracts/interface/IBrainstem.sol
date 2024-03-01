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

interface IBrainstem {
    struct Brainstem {
        uint256 id;
        uint256 name;
    }

    event BrainstemCreated(uint256 indexed id, Brainstem brainstem);
    event AssetRegistered(uint256 indexed brainstemId, uint256 indexed assetId);

    function createBrainstem(
        Brainstem calldata brainstem,
        uint256[] calldata companyIds
    ) external returns (uint256);

    function registerAsset(
        uint256 brainstemId,
        uint256 assetId,
        uint256[] calldata baseAssetIds
    ) external;

    function brainstemExists(uint256 brainstemId) external view returns (bool);
    function assetInBrainstem(uint256 assetId, uint256 brainstemId) external view returns (bool);
}
