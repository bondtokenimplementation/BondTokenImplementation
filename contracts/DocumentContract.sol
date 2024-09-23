// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./BondTokenContract.sol";

contract DocumentContract is Ownable {

    constructor() Ownable(_msgSender()) {}
    
    event DocumentUploaded(uint _timestamp, string _company, uint16 _year, bytes32 _documentHash);
    
    uint8 public hashFunction;  // First byte (2 characters) - 0x12 is sha2 & 0x20 is sha256 for example ("12" or "20" would then be stored)
    uint8 public size;          // Second byte (2 characters) 
    
    mapping (string => CompanyDocuments) ipfsHashes;
        
    struct CompanyDocuments {
        mapping(uint => SecuritiesInformation) securitiesInformation;
        mapping(uint16 => bytes32) annualReporting;
    }
    
    struct SecuritiesInformation {
        bytes32 prospectHash;
        bytes32 wibHash;
    }
    
    function setHashDetails(
        uint8 _hashFunction,
        uint8 _size)
        public
        onlyOwner
        {
        hashFunction = _hashFunction;
        size = _size;
    }
    
    // Functions for storing IPFS hashes
    
    function storeProspectHash(
        string memory _company,
        uint _tokenID,
        bytes32 _prospectHash)
        public
        onlyOwner
        {
        ipfsHashes[_company].securitiesInformation[_tokenID].prospectHash = _prospectHash;   
    }
    
    function storeWIBHash(
        string memory _company,
        uint _tokenID,
        bytes32 _wibHash)
        public
        onlyOwner
        {
        ipfsHashes[_company].securitiesInformation[_tokenID].wibHash = _wibHash;   
    }
    
    function storeAnnualReporting(
        string memory _company,
        uint16 _year,
        bytes32 _documentHash)
        external
        onlyOwner
        {
        ipfsHashes[_company].annualReporting[_year] = _documentHash;
        emit DocumentUploaded(block.timestamp, _company, _year, _documentHash);
    }
    
    function retreiveProspect(
        string memory _company,
        uint _tokenID)
        public
        view
        returns (uint8, uint8, bytes32)
        {
        return (hashFunction, size, ipfsHashes[_company].securitiesInformation[_tokenID].prospectHash);    
    }
    
    function retreiveWIB(
        string memory _company,
        uint _tokenID)
        public
        view
        returns (uint8, uint8, bytes32)
        {
        return (hashFunction, size, ipfsHashes[_company].securitiesInformation[_tokenID].wibHash);    
    }
    
    function retreiveReportingDocuments(
        string memory _company,
        uint16 _year)
        public
        view
        returns (uint8, uint8, bytes32)
        {
        return (hashFunction, size, ipfsHashes[_company].annualReporting[_year]);
    }

}
