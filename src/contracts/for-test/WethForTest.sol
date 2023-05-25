pragma solidity 0.6.7;

contract WethForTest {
  /*///////////////////////////////////////////////////////////////
                             METADATA STORAGE
    //////////////////////////////////////////////////////////////*/

  string public name;

  string public symbol;

  uint8 public decimals;

  /*///////////////////////////////////////////////////////////////
                              ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

  uint256 public totalSupply;

  mapping(address => uint256) public balanceOf;

  mapping(address => mapping(address => uint256)) public allowance;

  event Deposit(address indexed from, uint256 amount);

  event Withdrawal(address indexed to, uint256 amount);

  function deposit() public payable virtual {
    _mint(msg.sender, msg.value);
  }

  function withdraw(uint256 amount) public virtual {
    _burn(msg.sender, amount);

    payable(msg.sender).transfer(amount);
  }

  receive() external payable virtual {
    deposit();
  }

  /*///////////////////////////////////////////////////////////////
                              ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

  function approve(address spender, uint256 amount) public virtual returns (bool) {
    allowance[msg.sender][spender] = amount;

    return true;
  }

  function transfer(address to, uint256 amount) public virtual returns (bool) {
    balanceOf[msg.sender] -= amount;

    // Cannot overflow because the sum of all user
    // balances can't exceed the max uint256 value.
    balanceOf[to] += amount;

    return true;
  }

  function transferFrom(address from, address to, uint256 amount) public virtual returns (bool) {
    uint256 allowed = allowance[from][msg.sender]; // Saves gas for limited approvals.

    if (allowed != uint256(-1)) allowance[from][msg.sender] = allowed - amount;

    balanceOf[from] -= amount;

    // Cannot overflow because the sum of all user
    // balances can't exceed the max uint256 value.
    balanceOf[to] += amount;

    return true;
  }

  /*///////////////////////////////////////////////////////////////
                       INTERNAL MINT/BURN LOGIC
    //////////////////////////////////////////////////////////////*/

  function _mint(address to, uint256 amount) internal virtual {
    totalSupply += amount;

    // Cannot overflow because the sum of all user
    // balances can't exceed the max uint256 value.
    balanceOf[to] += amount;
  }

  function _burn(address from, uint256 amount) internal virtual {
    balanceOf[from] -= amount;

    // Cannot underflow because a user's balance
    // will never be larger than the total supply.
    totalSupply -= amount;
  }
}
