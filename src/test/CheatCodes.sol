// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.0 <0.9.0;

interface CheatCodes {

    function warp(uint256) external;
    // Set block.timestamp

    function roll(uint256) external;
    // Set block.number

    function fee(uint256) external;
    // Set block.basefee

    function load(address account, bytes32 slot) external returns (bytes32);
    // Loads a storage slot from an address

    function store(address account, bytes32 slot, bytes32 value) external;
    // Stores a value to an address' storage slot

    function sign(uint256 privateKey, bytes32 digest) external returns (uint8 v, bytes32 r, bytes32 s);
    // Signs data

    function addr(uint256 privateKey) external returns (address);
    // Computes address for a given private key

    function ffi(string[] calldata) external returns (bytes memory);
    // Performs a foreign function call via terminal

    function prank(address) external;
    // Sets the *next* call's msg.sender to be the input address

    function startPrank(address) external;
    // Sets all subsequent calls' msg.sender to be the input address until `stopPrank` is called

    function prank(address, address) external;
    // Sets the *next* call's msg.sender to be the input address, and the tx.origin to be the second input

    function startPrank(address, address) external;
    // Sets all subsequent calls' msg.sender to be the input address until `stopPrank` is called, and the tx.origin to be the second input

    function stopPrank() external;
    // Resets subsequent calls' msg.sender to be `address(this)`

    function deal(address who, uint256 newBalance) external;
    // Sets an address' balance

    function etch(address who, bytes calldata code) external;
    // Sets an address' code

    function expectRevert() external;
    function expectRevert(bytes calldata) external;
    function expectRevert(bytes4) external;
    // Expects an error on next call

    function record() external;
    // Record all storage reads and writes

    function accesses(address) external returns (bytes32[] memory reads, bytes32[] memory writes);
    // Gets all accessed reads and write slot from a recording session, for a given address

    function expectEmit(bool, bool, bool, bool) external;
    // Prepare an expected log with (bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData).
    // Call this function, then emit an event, then call a function. Internally after the call, we check if
    // logs were emitted in the expected order with the expected topics and data (as specified by the booleans)

    function mockCall(address, bytes calldata, bytes calldata) external;
    // Mocks a call to an address, returning specified data.
    // Calldata can either be strict or a partial match, e.g. if you only
    // pass a Solidity selector to the expected calldata, then the entire Solidity
    // function will be mocked.

    function clearMockedCalls() external;
    // Clears all mocked calls

    function expectCall(address, bytes calldata) external;
    // Expect a call to an address with the specified calldata.
    // Calldata can either be strict or a partial match

    function getCode(string calldata) external returns (bytes memory);
    // Gets the bytecode for a contract in the project given the path to the contract.

    function label(address addr, string calldata label) external;
    // Label an address in test traces

    function assume(bool) external;
    // When fuzzing, generate new inputs if conditional not met
}
