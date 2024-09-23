// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./KYCContract.sol";
import "./DocumentContract.sol";
import "./CSRContract.sol";

contract BondTokenContract is ERC1155, Ownable {

    constructor() ERC1155("https://github.com/DavidCisar/Forschungsprojekt/{id}.json") Ownable(_msgSender()) { 
        issuerAddress = msg.sender;
    }  

    event TokenMinted (
        uint _tokenID, 
        uint256 indexed _timestamp
        );

    event CouponPaid (
        uint _tokenID, 
        address _to, 
        uint256 _amouont, 
        uint256 indexed _timestamp
        );

    event RedemptionPaid (
        uint _tokenID, 
        address indexed _to, 
        uint256 _amouont, 
        uint256 indexed _timestamp
        );

    event TokenBought (
        uint _tokenID, 
        address indexed _to, 
        uint256 _amount, 
        uint256 indexed _timestamp
        );

    event TokenTransfered (
        uint _tokenID, 
        address indexed _to, 
        address indexed _from, 
        uint256 _amount, 
        uint256 indexed _timestamp
        );

    event RedemptionBuyBack (
        uint _tokenID, 
        address indexed _from, 
        uint256 _amount, 
        uint256 indexed _timestamp
        );

    event RequestForcedTransfer (
        uint indexed requestID, 
        uint _tokenID, 
        address _investor, 
        uint256 _amount
        );

    event ForcedTokenTransfered (
        uint _tokenID, 
        address indexed _to, 
        address indexed _from, 
        uint256 _amount, 
        uint256 indexed _timestamp
        );
    
    KYCContract KYC;
    CSRContract CSR;
    DocumentContract documentContract;
    IERC20 _stableCoin;

    function setKYCContract(address _addr)
        public
        onlyOwner
        {
        KYC = KYCContract(_addr);
    }

    function setCSRContract(address _addr)
        public
        onlyOwner
        {
        CSR = CSRContract(_addr);
    }

    function setDocumentContract(address _addr)
        public
        onlyOwner
        {
        documentContract = DocumentContract(_addr);
    }

    function setStableCoinContract(address _addr)
        public
        onlyOwner
        {
        _stableCoin = IERC20(_addr);
    }

    modifier onlyRegulator {
        require(
            _msgSender() == regulator, 
            "Only Regulator!"
            );
        _;
    }
    
    address public regulator;
    address public issuerAddress;
    
    function setRegulator(
        address _regulator) 
        public
        onlyOwner
        {
        regulator = _regulator;
    }
    
    mapping(uint => TokenDataStruct) private TokenData;

    struct TokenDataStruct {
        uint volume;
        uint parValueETHER;
        uint parValueEUR;
        uint coupon;
        uint issuedAmount;
        uint redemptionAmount;
        uint burnedAmount;
        uint256 settlementDate;
        uint256 maturityDate;
    }

    mapping(uint => InvestorData) Investor;

    struct InvestorData {
        address [] Investors;
        mapping(address => bool) isInvestor;
    }

    uint public requestID = 0;

    mapping(uint => ForcedTransferRequest) public RegulatoryRequests;

    struct ForcedTransferRequest{
        uint tokenID;
        uint amount;
        address investor;
        bool executed;
    }

    function tokenState(
        uint _tokenID)
        public
        view 
        returns(uint state)
        {
            
        if (block.timestamp > TokenData[_tokenID].maturityDate){
            return 2;
        }
        
        if (block.timestamp > TokenData[_tokenID].settlementDate && 
            block.timestamp < TokenData[_tokenID].maturityDate) {
            return 1;
        }
        
        if (block.timestamp < TokenData[_tokenID].settlementDate) {
            return 0;   
        }
    }
    
    function mintToken(
        uint _tokenID)
        public
        onlyOwner
        returns (bool)
        {
    
        require(
            CSR.isDataComplete(_tokenID),
            "CSR not initialized!"
            );
        
        (TokenData[_tokenID].volume, 
        TokenData[_tokenID].parValueETHER, 
        TokenData[_tokenID].parValueEUR, 
        TokenData[_tokenID].coupon) = CSR.returnTokenDataOne(_tokenID);
        
        (TokenData[_tokenID].settlementDate, 
        TokenData[_tokenID].maturityDate) = CSR.returnTokenDataTwo(_tokenID);
        
        _mint(
            issuerAddress, 
            _tokenID, 
            TokenData[_tokenID].volume, 
            ""
            );
        
        emit TokenMinted(
            _tokenID, 
            block.timestamp
            ); 
            
        return true;
    }

    function returnTokenData(
        uint _tokenID)
        public
        view
        returns (
            uint volume, 
            uint parValueETHER, 
            uint parValueEUR, 
            uint coupon, 
            uint issuedAmount, 
            uint redemptionAmount, 
            uint burnedAmount)
        {
            
        return(
            TokenData[_tokenID].volume,
            TokenData[_tokenID].parValueETHER,
            TokenData[_tokenID].parValueEUR,
            TokenData[_tokenID].coupon,
            TokenData[_tokenID].issuedAmount,
            TokenData[_tokenID].redemptionAmount,
            TokenData[_tokenID].burnedAmount
        );    
    }

    function returnTokenDates(
        uint _tokenID)
        public
        view
        returns(
            uint256 settlementDate, 
            uint256 maturityDate)
        {

        return(
            TokenData[_tokenID].settlementDate,
            TokenData[_tokenID].maturityDate
        );    
    }

    function returnInvestorLength(
        uint _tokenID)
        public
        view
        onlyOwner
        returns (uint investorLength)
        {
        return Investor[_tokenID].Investors.length;
    }

    function returnInvestorAddress(
        uint _tokenID,
        uint _index)
        public
        view
        onlyOwner
        returns (
            address investorAdress, 
            bool isInvestor)
        {
            
        return (
            Investor[_tokenID].Investors[_index], 
            Investor[_tokenID].isInvestor[Investor[_tokenID].Investors[_index]]); 
    }

    function payCoupon(
        uint _tokenID,
        address payable _to)
        public
        payable
        onlyOwner
        {
        
        _to.transfer(msg.value);
        
        emit CouponPaid(
            _tokenID, 
            _to, 
            msg.value, 
            block.timestamp);
    }

    mapping(uint => mapping(address => uint256)) public BuyBack;

    function redemptionBuyBack(
        address _from,
        uint _tokenID)
        public
        {
        require(
            block.timestamp > TokenData[_tokenID].maturityDate,
            "Bond not matured yet"
        );
        require(
            _from == _msgSender() || 
            isApprovedForAll(_from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );

        uint balance = balanceOf(_from, _tokenID);
        
        _safeTransferFrom(
            _from, 
            issuerAddress, 
            _tokenID, 
            balance, 
            "[]"
            );
            
        CSR.updateCSRbyContractSell(
            _tokenID, 
            _msgSender(),
            balance
            );
            
        BuyBack[_tokenID][_from] = balance;

        emit RedemptionBuyBack(
            _tokenID, 
            _from, 
            balance, 
            block.timestamp
            );
    }

    function returnRedemptionPTP(
        uint _tokenID,
        address _to)
        public
        view
        onlyOwner
        returns (uint256)
        {
        return returnPriceToPayETHER(
            _tokenID, 
            BuyBack[_tokenID][_to]) 
            * (10**18);    
    }

    function payRedemption(
        uint _tokenID,
        address payable _to)
        public
        payable
        onlyOwner
        {
        require(
            block.timestamp > TokenData[_tokenID].maturityDate,
            "Redemption not possible yet"
        );    
        
        require(
            msg.value == (returnPriceToPayETHER(_tokenID, BuyBack[_tokenID][_to]) * (10**18)),
            "Check msg.value"
            );
            
        _to.transfer(msg.value);
        
        TokenData[_tokenID].redemptionAmount += BuyBack[_tokenID][_to];
        
        emit RedemptionPaid(
            _tokenID, 
            _to, 
            msg.value, 
            block.timestamp
            );
    }

    function burn(
        uint _tokenID)
        public
        onlyOwner
        {
        uint256 balance = balanceOf(_msgSender(), _tokenID);
        _burn(_msgSender(), _tokenID, balance);
        TokenData[_tokenID].burnedAmount += balance;
    }

    function returnPriceToPayETHER(
        uint _tokenID, 
        uint _amount)
        public
        view
        returns(uint)
        {
        return(TokenData[_tokenID].parValueETHER * _amount);    
    }

    function returnPriceToPayEUR(
        uint _tokenID, 
        uint _amount)
        public
        view
        returns(uint)
        {
        return(TokenData[_tokenID].parValueEUR * _amount);    
    }

    function buyTokensETHER(
        uint _tokenID, 
        uint _amount)
        public 
        payable
        returns(bool)
        {
        require(
            tokenState(_tokenID) == 0,
            "TS closed."
        );
        require(
            KYC.kycCompleted(_msgSender()),
            "Not whitelisted."
        );
        require(
            msg.value == (returnPriceToPayETHER(_tokenID, _amount)*(10**18)),
            "Check msg.value"
        );
        
        payable(issuerAddress).transfer(msg.value);
        
        _safeTransferFrom(
            issuerAddress, 
            _msgSender(), 
            _tokenID, 
            _amount, 
            "[]"
            );
        
        if (!Investor[_tokenID].isInvestor[_msgSender()]) {
            Investor[_tokenID].Investors.push(_msgSender());
            Investor[_tokenID].isInvestor[_msgSender()] = true;
        }
        
        TokenData[_tokenID].issuedAmount += _amount;
        
        CSR.updateCSRbyContractBuy(
            _tokenID, 
            _msgSender(),
            _amount
            );
        
        emit TokenBought(
            _tokenID, 
            _msgSender(), 
            _amount, 
            block.timestamp
            );
            
        return true;
    }

    function buyTokensEUR(
        uint _tokenID, 
        uint _amount)
        public 
        payable
        returns(bool)
        {
        require(
            tokenState(_tokenID) == 0,
            "TS closed."
        );
        require(
            KYC.kycCompleted(_msgSender()),
            "Not whitelisted!"
        );
        
        address from = _msgSender();
        uint256 ptp = returnPriceToPayEUR(_tokenID, _amount);
        
        _stableCoin.transferFrom(from, issuerAddress, ptp);
        
        _safeTransferFrom(
            issuerAddress, 
            _msgSender(), 
            _tokenID, 
            _amount, 
            "[]"
            );
        
        if (!Investor[_tokenID].isInvestor[_msgSender()]) {
            Investor[_tokenID].Investors.push(_msgSender());
            Investor[_tokenID].isInvestor[_msgSender()] = true;
        }
        
        TokenData[_tokenID].issuedAmount += _amount;
        
        CSR.updateCSRbyContractBuy(
            _tokenID, 
            _msgSender(), 
            _amount
            );
        
        emit TokenBought(
            _tokenID, 
            _msgSender(), 
            _amount, 
            block.timestamp
            );
            
        return true;
    }
    
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
        )
        public
        virtual override
        {

        require(
            block.timestamp < TokenData[id].maturityDate,
            "MD reached!"
        );
        require(
            KYC.kycCompleted(to),
            "Not whitelisted!"
        );
        require(
            from == _msgSender() || 
            isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not owner nor approved"
        );
        
        _safeTransferFrom(
            from, 
            to, 
            id, 
            amount, 
            data
            );
        
        if (!Investor[id].isInvestor[to]) {
            Investor[id].Investors.push(to);
            Investor[id].isInvestor[to] = true;
        }
        
        CSR.updateCSRbyContractBuy(id, to, amount); 
        CSR.updateCSRbyContractSell(id, _msgSender(), amount);
        
        emit TokenTransfered(
            id, 
            to, 
            _msgSender(), 
            amount, 
            block.timestamp
            );
        
    }

    function requestForcedTransfer(
        uint _tokenID,
        address _investor,
        uint _amount)
        public
        onlyRegulator
        {
        RegulatoryRequests[requestID].tokenID = _tokenID;
        RegulatoryRequests[requestID].investor = _investor;
        RegulatoryRequests[requestID].amount = _amount;

        emit RequestForcedTransfer(
            requestID, 
            _tokenID, 
            _investor, 
            _amount
            );

        requestID++;
    }
    
    function forcedTransfer(
        uint _id)
        public
        onlyRegulator
        {
            
        require(RegulatoryRequests[_id].executed == false, "Request already executed");

        RegulatoryRequests[_id].executed = true;
        uint _tokenID = RegulatoryRequests[_id].tokenID;
        uint _amount = RegulatoryRequests[_id].amount;
        address _investor = RegulatoryRequests[_id].investor;
        
        _safeTransferFrom(_investor, issuerAddress, _tokenID, _amount, "[]");
        
        CSR.updateCSRbyContractSell(_tokenID, _investor, _amount);
        
        emit ForcedTokenTransfered(
            _tokenID, 
            issuerAddress, 
            _investor, 
            _amount, 
            block.timestamp
            );
    }
}
