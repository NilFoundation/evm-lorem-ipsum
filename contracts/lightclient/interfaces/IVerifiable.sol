pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IVerifiable is Ownable {
    function setVerifier(address v) external onlyOwner;
}
