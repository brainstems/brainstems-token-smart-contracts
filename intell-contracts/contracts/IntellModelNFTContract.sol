// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interface/IIntellModelNFT.sol";
import "./interface/IIntellSetting.sol";

contract IntellModelNFTContract is
    ERC721Enumerable,
    ReentrancyGuard,
    IIntellModelNFT
{
    using Strings for uint256;
    using SafeMath for uint256;

    string _baseTokenURI;
    mapping(uint256 => uint256) private _modelIdByTokenId;
    mapping(uint256 => uint256) private _tokenIdByModelId;

    IIntellSetting private _intellSetting;

    event UpdateMintPrice(uint256 oldMintPrice, uint256 newMintPrice);
    event UpdatePause(bool oldVal, bool newVal);
    event UpdatePaymentToken(address oldPaymentToken, address newPaymentToken);
    event NewModelMint(
        address creator,
        uint256 price,
        uint256 tokenId,
        uint256 modelId,
        uint256 timestamp,
        uint256 blocknumber
    );
    
    constructor(
        string memory baseURI,
        IIntellSetting _intellSetting_
    ) ERC721("IntellModelNFT", "IMN") {
        _baseTokenURI = baseURI;
        _intellSetting = _intellSetting_;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     */
    modifier whenNotPaused() {
        require(!_intellSetting.paused(), "Pausable: paused");
        _;
    }

    // Checks if the caller is admin
    modifier onlyAdmin() {
        require(
            _intellSetting.admin() == _msgSender(),
            "Ownable: caller is not the admin"
        );
        _;
    }

    modifier onlyUnlock() {
        require(_intellSetting.unlocked(), "Lock: Locked");
        _;
    }

    // Gets model id from token id
    function modelIdByTokenId(
        uint256 _tokenId
    ) external view override returns (uint256) {
        return _modelIdByTokenId[_tokenId];
    }

    // Sets intellSetting contract
    function setIntellSetting(
        IIntellSetting _intellSetting_
    ) external onlyAdmin onlyUnlock {
        _intellSetting = _intellSetting_;
    }

    // Gets intellSetting contract
    function intellSetting() external view returns (IIntellSetting) {
        return _intellSetting;
    }

    // Gets token id from model id
    function tokenIdByModelId(
        uint256 _modelId
    ) external view override returns (uint256) {
        return _tokenIdByModelId[_modelId];
    }

    // Sets base uri for metadata
    function setBaseURI(string memory baseURI) public onlyAdmin onlyUnlock whenNotPaused {
        _baseTokenURI = baseURI;
    }

    // Renounces ownership of copyright/Base IP
    function burn(uint256 tokenId) public virtual whenNotPaused {
        //solhint-disable-next-line max-line-length
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            "ERC721: CALLER IS NOT TOKEN OWNER OR APPROVED"
        );
        _burn(tokenId);
    }

    // Get IERC20 instance for payment token
    function paymentToken() public view override returns (IERC20) {
        return IERC20(_intellSetting.intellTokenAddr());
    }

    // Recovers singer
    function recoverSigner(
        bytes32 hash,
        bytes memory signature
    ) private pure returns (address) {
        bytes32 messageDigest = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", hash)
        );
        return ECDSA.recover(messageDigest, signature);
    }

    // Verifies bytes message
    function verifyMessage(
        bytes memory message,
        bytes memory signature
    ) private view returns (bool) {
        bytes32 hash = keccak256(message);
        return recoverSigner(hash, signature) == _intellSetting.truthHolder();
    }

    // Checks if user account and model status is valid
    function checkStatus(
        bytes calldata statusMessage
    ) internal view returns (bool) {

        require(statusMessage.length > 0, "INVALID MESSAGE");
        
        (
            // model identification number from backend (off-chain)
            uint256 _MODEL_ID,
            // user account address from backend and database
            address _USER_ADDR,
            // if releasing is approved from TIEX
            bool _APPROVED
        ) = abi.decode(
                statusMessage,
                (uint256, address, bool)
            );

        // Checks if user account is valid and not bot
        require(_USER_ADDR == msg.sender && msg.sender == tx.origin, "NO BOT");

        // Checks if user account and model status is valid
        require(
            _APPROVED,
            "NOT APPROVED FROM TIEX DAO"
        );

        // Checks if the model already was registered
        require(
            _tokenIdByModelId[_MODEL_ID] == 0 && _MODEL_ID > 0,
            "MODEL ID WAS REGISTERED ALREADY."
        );

        return true;
    }

    // Registers AI/Model on chain by data scientist(creator)
    function adopt(
        bytes calldata statusMessage,
        bytes calldata statusSignature
    ) external nonReentrant whenNotPaused {
        // next model identification number (token id) in on-chain
        uint256 nextTokenId = totalSupply() + 1;

        // Should set payment token (INTELL) address in intellSetting contract first.
        require(
            address(paymentToken()) != address(0),
            "SET PAYMENT TOKEN IN INTELLSETTING"
        );

        // Verifies message from off-chain (backend) through ECDSA on chain
        require(
            verifyMessage(statusMessage, statusSignature),
            "ONLY ACCEPT TRUTHHOLDER SIGNED MESSAGE"
        );

        // model identification number from backend and database in off-chain
        uint256 _MODEL_ID = abi.decode(statusMessage, (uint256));

        //Checks if user (creator) and AI/Model from off-chain(backend) is valid to launch
        require(checkStatus(statusMessage), "THE STATUS IS INVALID");

        // mapping of model id (off-chain) and token id(on-chain)
        _tokenIdByModelId[_MODEL_ID] = nextTokenId;
        _modelIdByTokenId[nextTokenId] = _MODEL_ID;

        //Registers model on chain and mints new token id for data scientist(creator)
        _safeMint(msg.sender, nextTokenId);

        // Commission to register the model and get the NFT token for proving ownership of copyright/Base IP
        uint256 paymentTokenAmount = _intellSetting.modelRegisterationPrice();

        //Checks if user account has enough payment tokens to register
        require(
            paymentToken().balanceOf(msg.sender) >= paymentTokenAmount,
            "THE ERC20 TOKEN AMOUNT SENT IS NOT CORRECT OR INSUFFIENT ERC20 TOKEN AMOUNT SENT."
        );

        // Pays commission
        paymentToken().transferFrom(
            msg.sender,
            address(this),
            paymentTokenAmount
        );

        emit NewModelMint(
            msg.sender, // user account address
            paymentTokenAmount, // commission paid
            nextTokenId, // issued token id from on-chain
            _MODEL_ID, // issued model id from off-chain
            block.timestamp, // date and time when issued
            block.number // block number when issued
        );
    }

    // Gets nft token ids minted from user account
    function walletOfOwner(
        address _owner
    ) public view override returns (uint256[] memory) {
        uint256 tokenCount = balanceOf(_owner);

        uint256[] memory tokensId = new uint256[](tokenCount);
        for (uint256 i; i < tokenCount; i++) {
            tokensId[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokensId;
    }

    // Gets metadata uri
    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    //Withdraws payment tokens to TIEX admin
    function withdraw(address __recipient) external onlyAdmin onlyUnlock {
        paymentToken().transfer(
            __recipient,
            paymentToken().balanceOf(address(this))
        );
    }
}
