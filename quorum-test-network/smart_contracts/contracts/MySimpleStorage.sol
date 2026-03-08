// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract MySimpleStorage {
    string private message;

    constructor(string memory initMessage) {
        message = initMessage;
    }

    function updateMessage(string memory newMessage) public {
        message = newMessage;
    }

    function readMessage() public view returns (string memory) {
        return message;
    }
}