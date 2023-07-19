// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./interface/IIntellSetting.sol";

pragma experimental ABIEncoderV2;

contract IntellSetting is Context, IIntellSetting {
    using SafeMath for uint256;

    address private _admin;
    address private _truthHolder;
    address private _intellTokenAddr;
    address private _intellShareCollectionContractAddr;
    address private _intellModelNFTContractAddr;
    uint256 private _modelRegisterationPrice;
    uint256 private _intellShareCollectionLaunchPrice;

<<<<<<< HEAD
    uint256 public constant UNLOCK_DURATION = 15 minutes;
    address private _unlocker;
    uint256 private _unlockTimestamp;
    bool public paused = false;

    event Pause();
    event Unpause();
    event UpdateIntellModelNFTContractAddr(address __old, address __new);
    event UpdateIntellShareCollectionContractAddr(address __old, address __new);
    event UpdateAdmin(address __old, address __new);
    event UpdateIntellShareCollectionLaunchPrice(uint256 __old, uint256 __new);
    event UpdateIntellTokenAddr(address __old, address __new);
    event UpdateModelRegisterationPrice(uint256 __old, uint256 __new);
    event UpdateTruthHolder(address __old, address __new);
    event Unlocked(uint256 __until);
    event UpdateUnlocker(address __old, address __new);


    constructor(address __admin, address __truthHolder, address __unlocker) {
        _unlocker = __unlocker;
        _admin = __admin;
        _truthHolder = __truthHolder;
    }

    // Checks if the caller is admin
    modifier onlyAdmin() {
        require(
            _admin == _msgSender(),
            "Ownable: caller is not the admin"
        );
        _;
    }

    modifier onlyUnlocker() {
        require(_unlocker == _msgSender(), "Lockable: caller is not the unlocker");
        _;
    }

    modifier onlyUnlock() {
        require(unlocked(), "Lock: Locked");
        _;
    }

    /**
     * @dev called by the owner to pause, triggers stopped state
     */
    function pause() external onlyAdmin onlyUnlock {
        paused = true;
        emit Pause();
    }

    /**
     * @dev called by the owner to unpause, returns to normal state
     */
    function unpause() external onlyAdmin onlyUnlock {
        paused = false;
        emit Unpause();
    }

    function setUnlocker(address __newUnlocker) external onlyAdmin onlyUnlock {
        require(__newUnlocker != address(0), "address zero is not a valid address");

        emit UpdateUnlocker(_unlocker, __newUnlocker);
        _unlocker = __newUnlocker;
    }

    function unlockTimestamp() external view override returns(uint256) {
        return _unlockTimestamp;
    }

    function unlocked() public view override returns(bool) {
        return _unlockTimestamp >= block.timestamp;
    }

    function unlocker() external view override returns(address) {
        return _unlocker;
    }

    function unlock() external onlyUnlocker {
        require(_unlockTimestamp < block.timestamp, "LOCK: Unlocked Already");

        _unlockTimestamp = block.timestamp.add(UNLOCK_DURATION);
        
        emit Unlocked(_unlockTimestamp);
    }
=======
    constructor() {}
>>>>>>> 21f20f6b09b6cbc76023ef5178af522db82146ad

    function truthHolder() external view override returns (address) {
        return _truthHolder;
    }

    function setTruthHolder(address __truthHolder) external onlyAdmin onlyUnlock {
        require(__truthHolder != address(0), "address zero is not a valid address");

        emit UpdateTruthHolder(_truthHolder, __truthHolder);
        _truthHolder = __truthHolder;
    }

    function modelRegisterationPrice()
        external
        view
        override
        returns (uint256)
    {
        return _modelRegisterationPrice;
    }

    function setModelRegisterationPrice(uint256 __val) external onlyAdmin onlyUnlock {
        require(__val > 0, "launch commission not greater than 0");

        emit UpdateModelRegisterationPrice(_modelRegisterationPrice, __val);
        _modelRegisterationPrice = __val;
    }

    function intellShareCollectionLaunchPrice()
        external
        view
        override
        returns (uint256)
    {
        return _intellShareCollectionLaunchPrice;
    }

    function setIntellShareCollectionLaunchPrice(
<<<<<<< HEAD
        uint256 __val
    ) external onlyAdmin onlyUnlock {
        require(__val > 0, "Launch commission not greater than 0");

        emit UpdateIntellShareCollectionLaunchPrice(_intellShareCollectionLaunchPrice, __val);
        _intellShareCollectionLaunchPrice = __val;
=======
        uint256 _newLaunchPrice
    ) external onlyOwner {
        _intellShareCollectionLaunchPrice = _newLaunchPrice;
>>>>>>> 21f20f6b09b6cbc76023ef5178af522db82146ad
    }

    function admin() external view override returns (address) {
        return _admin;
    }

    function setAdmin(address __newAdmin) external onlyAdmin onlyUnlock {
        require(__newAdmin != address(0), "address zero is not a valid address");

        emit UpdateAdmin(_admin, __newAdmin);
        _admin = __newAdmin;
    }

    function intellTokenAddr() external view override returns (address) {
        return _intellTokenAddr;
    }

    function setIntellTokenAddr(address __newAddr) external onlyAdmin onlyUnlock {
        require(__newAddr != address(0), "address zero is not a valid contract address");

        emit UpdateIntellTokenAddr(_intellTokenAddr, __newAddr);
        _intellTokenAddr = __newAddr;
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
        address __newAddr
    ) external onlyAdmin onlyUnlock {
        require(__newAddr != address(0), "address zero is not a valid contract address");
        
        emit UpdateIntellShareCollectionContractAddr(_intellShareCollectionContractAddr, __newAddr);
        _intellShareCollectionContractAddr = __newAddr;
    }

    function intellModelNFTContractAddr()
        external
        view
        override
        returns (address)
    {
        return _intellModelNFTContractAddr;
    }

    function setIntellModelNFTContractAddr(address __newAddr) external onlyAdmin onlyUnlock {
        require(__newAddr != address(0), "address zero is not a valid contract address");

        emit UpdateIntellModelNFTContractAddr(_intellModelNFTContractAddr, __newAddr);
        _intellModelNFTContractAddr = __newAddr;

    }
}
