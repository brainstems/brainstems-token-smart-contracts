// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interface/IIntellSetting.sol";

pragma experimental ABIEncoderV2;

contract IntellSetting is Ownable, IIntellSetting {
    address private _admin;
    address private _truthHolder;
    address private _intellTokenAddr;
    address private _intellShareCollectionContractAddr;
    address private _intellModelNFTContractAddr;
    uint256 private _modelRegisterationPrice;
    uint256 private _intellShareCollectionLaunchPrice;

    constructor() {
        _modelRegisterationPrice = 10000 * 10 ** 18;
        _intellShareCollectionLaunchPrice = 10000 * 10 ** 18;
    }

    function truthHolder() external view override returns (address) {
        return _truthHolder;
    }

    function setTruthHolder(address _newTruthHolder) external onlyOwner {
        _truthHolder = _newTruthHolder;
    }

    function modelRegisterationPrice() external view override returns (uint256) {
        return _modelRegisterationPrice;
    }

    function setModelRegisterationPrice(uint256 val) external onlyOwner {
        _modelRegisterationPrice = val;
    }

    function intellShareCollectionLaunchPrice()
        external
        view
        override
        returns (uint256)
    {
        return _intellShareCollectionLaunchPrice;
    }

    function setintellShareCollectionLaunchPrice(
        uint256 _newLaunchPrice
    ) external onlyOwner {
        _intellShareCollectionLaunchPrice = _newLaunchPrice;
    }

    function admin() external view override returns (address) {
        return _admin;
    }

    function setAdmin(address newAdmin) external onlyOwner {
        _admin = newAdmin;
    }

    function intellTokenAddr() external view override returns (address) {
        return _intellTokenAddr;
    }

    function setIntellTokenAddr(address newIntellTokenAddr) external onlyOwner {
        _intellTokenAddr = newIntellTokenAddr;
    }

    function intellShareCollectionContractAddr()
        external
        view
        override
        returns (address)
    {
        return _intellShareCollectionContractAddr;
    }

    function setIntellShareCollectionContractAddr(
        address _newAddr
    ) external onlyOwner {
        _intellShareCollectionContractAddr = _newAddr;
    }

    function intellModelNFTContractAddr()
        external
        view
        override
        returns (address)
    {
        return _intellModelNFTContractAddr;
    }

    function setIntellModelNFTContractAddr(address newAddr) external onlyOwner {
        _intellModelNFTContractAddr = newAddr;
    }
}
