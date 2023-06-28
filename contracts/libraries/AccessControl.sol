pragma solidity 0.8.16;


abstract contract AccessControl {

    address public owner;

    modifier Ownable() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    function _setOwner() internal {
        owner = msg.sender;
    }

}
