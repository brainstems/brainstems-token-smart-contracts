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

interface IMembership {
    struct Unit {
        uint256 id;
        string name;
    }

    event EcosystemCreated(uint256 indexed id, Unit ecosystem);
    event CompanyCreated(uint256 indexed id, Unit company);
    event MemberAdded(uint256 indexed ecosystemId, uint256 indexed memberId);
    event MemberRemoved(uint256 indexed ecosystemId, uint256 indexed memberId);
    event UserAdded(uint256 indexed ecosystemId, uint256 indexed memberId, address user);
    event UserRemoved(uint256 indexed ecosystemId, uint256 indexed memberId, address user);

    /**
     * @notice Registers an ecosystem in the contract.
     * @param ecosystem object properties for the ecosystem.
     */
    function createEcosystem(Unit calldata ecosystem) external;

    /**
     * @notice Registers a company in the contract.
     * @param member object properties for the company.
     */
    function createCompany(Unit calldata member) external;

    /**
     * @notice Attaches a Member to an Ecosystem.
     * @param ecosystemId identifier for the ecosystem.
     * @param memberId identifier for the member.
     */
    function addMember(uint256 ecosystemId, uint256 memberId) external;

    /**
     * @notice Removes a Member from an Ecosystem.
     * @param ecosystemId identifier for the ecosystem.
     * @param memberId identifier for the member.
     */
    function removeMember(uint256 ecosystemId, uint256 memberId) external;

    /**
     * @notice Adds a user to a company within an ecosystem.
     * @param ecosystemId identifier for the ecosystem.
     * @param memberId identifier for the member.
     * @param user address of the user.
     */
    function addUser(
        uint256 ecosystemId,
        uint256 memberId,
        address user
    ) external;

    /**
     * @notice Remove a user to a company within an ecosystem.
     * @param ecosystemId identifier for the ecosystem.
     * @param memberId identifier for the member.
     * @param user address of the user.
     */
    function removeUser(
        uint256 ecosystemId,
        uint256 memberId,
        address user
    ) external;

    /**
     * @notice Returns the detailed ecosystem identified by the provided id.
     */
    function getEcosystem(uint256 ecosystemId) external view returns (Unit memory);

    /**
     * @notice Returns the detailed company identified by the provided id.
     */
    function getCompany(uint256 companyId) external view returns (Unit memory);

    /**
     * @notice Returns the company of the user within the ecosystem.
     */
    function getActiveUser(uint256 ecosystemId, uint256 memberId, address user) external view returns (bool);

    /**
     * @notice Returns the company within the ecosystem.
     */
    function getEcosystemCompanies(uint256 ecosystemId, uint256 memberId) external view returns (Unit memory);
}
