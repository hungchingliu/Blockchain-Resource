pragma solidity 0.8.19;

import "forge-std/Test.sol";

contract CompoundPracticeSetUp is Test {
  address borrowerAddress;
  string public RPC_URL = "https://eth-mainnet.g.alchemy.com/v2/Ea1NmKEyxzz-p3O_4WZFu5apdNXGtV0l";
  function setUp() public virtual {
    uint256 forkId = vm.createFork(RPC_URL);
    vm.selectFork(forkId);
    string memory path = string(
      abi.encodePacked(vm.projectRoot(), "/test/helper/Borrower.json")
    );
    string memory json = vm.readFile(path);
    bytes memory creationCode = vm.parseBytes(abi.decode(vm.parseJson(json, ".bytecode"), (string)));

    address addr;
    assembly {
      addr := create(0, add(creationCode, 0x20), mload(creationCode))
    }
    require(addr != address(0), "Borrower deploy failed");

    borrowerAddress = addr;
  }
}
