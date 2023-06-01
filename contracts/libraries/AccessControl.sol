pragma solidity 0.8.16;


abstract contract AccessControl {

    address public owner;

    function _setOwner() internal {
        owner = msg.sender;
    }

}
