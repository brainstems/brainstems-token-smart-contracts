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

import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./interface/IMembership.sol";

contract Membership is
    Initializable,
    AccessControlEnumerableUpgradeable,
    IMembership
{
    mapping(uint256 => Unit) private ecosystems;
    mapping(string => bool) private ecosystemRegisteredNames;
    
    mapping(uint256 => Unit) private companies;
    
    mapping(address => mapping(uint256 => mapping(uint256 => bool))) ecosystemCompanyUsers;
    mapping(uint256 => mapping(uint256 => Unit)) private ecosystemCompanies;

    function initialize(
        address _admin
    ) public initializer {
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
    }

    function createEcosystem(Unit calldata ecosystem) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(ecosystem.id != 0, "ecosystem id cannot be 0");
        require(ecosystemRegisteredNames[ecosystem.name] == false, "ecosystem name already registered");
        require(ecosystems[ecosystem.id].id == 0, "ecosystem id already registered");
        ecosystems[ecosystem.id] = ecosystem;
        ecosystemRegisteredNames[ecosystem.name] = true;

        emit EcosystemCreated(ecosystem.id, ecosystem);
    }

    function createCompany(Unit calldata company) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(company.id != 0, "company id cannot be 0");
        require(companies[company.id].id == 0, "company id already registered");
        companies[company.id] = company;

        emit CompanyCreated(company.id, company);
    }

    function addMember(uint256 ecosystemId, uint256 memberId) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(ecosystems[ecosystemId].id != 0, "ecosystem id not found");
        require(companies[memberId].id != 0, "company id not found");
        require(ecosystemCompanies[ecosystemId][memberId].id == 0, "company already part of ecosystem");
        ecosystemCompanies[ecosystemId][memberId] = companies[memberId];

        emit MemberAdded(ecosystemId, memberId);
    }

    function removeMember(uint256 ecosystemId, uint256 memberId) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(ecosystems[ecosystemId].id != 0, "ecosystem id not found");
        require(companies[memberId].id != 0, "company id not found");
        require(ecosystemCompanies[ecosystemId][memberId].id != 0, "company not part of ecosystem");
        delete ecosystemCompanies[ecosystemId][memberId];

        emit MemberRemoved(ecosystemId, memberId);
    }

    function addUser(
        uint256 ecosystemId,
        uint256 memberId,
        address user
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(ecosystems[ecosystemId].id != 0, "ecosystem id not found");
        require(companies[memberId].id != 0, "company id not found");
        require(ecosystemCompanies[ecosystemId][memberId].id != 0, "company not part of ecosystem");
        require(!ecosystemCompanyUsers[user][ecosystemId][memberId], "user already part of company");
        ecosystemCompanyUsers[user][ecosystemId][memberId] = true;

        emit UserAdded(ecosystemId, memberId, user);
    }

    function removeUser(
        uint256 ecosystemId,
        uint256 memberId,
        address user
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        require(ecosystems[ecosystemId].id != 0, "ecosystem id not found");
        require(companies[memberId].id != 0, "company id not found");
        require(ecosystemCompanies[ecosystemId][memberId].id != 0, "company not part of ecosystem");
        require(ecosystemCompanyUsers[user][ecosystemId][memberId], "user not part of company");
        delete ecosystemCompanyUsers[user][ecosystemId][memberId];

        emit UserRemoved(ecosystemId, memberId, user);
    }

    function getEcosystem(uint256 id) external view override returns (Unit memory) {
        return ecosystems[id];
    }

    function getCompany(uint256 id) external view override returns (Unit memory) {
        return companies[id];
    }

    function getActiveUser(uint256 ecosystemId, uint256 memberId, address user) external view override returns (bool) {
        return ecosystemCompanyUsers[user][ecosystemId][memberId];
    }

    function getEcosystemCompanies(uint256 ecosystemId, uint256 memberId) external view override returns (Unit memory) {
        return ecosystemCompanies[ecosystemId][memberId];
    }
}
