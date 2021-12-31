// SPDX-License-Identifier: GPLv3
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

// Built on OpenZeppelin Contracts v4.4.0 (token/ERC20/ERC20.sol)
contract Happy is Ownable {
    /* ========== STATE VARIABLES ========== */

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _burnTaxWhitelist;

    uint256 public timelockEnd;

    address[] public minters;
    address[] public pendingMinters;

    uint256 private constant _TIMELOCK = 2 weeks;

    uint256 public totalSupply;
    uint256 public burnedSupply;
    uint256 public burnPercent;
    uint256 public constant maxSupply = 10000000 ether;

    string public constant name = "Happiness";
    string public constant symbol = "HAPPY";

    uint8 public constant decimals = 18;

    /* ========== VIEWS ========== */

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender)
        public
        view
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    /* ========== MUTATIVE FUNCTIONS ========== */

    function transfer(address recipient, uint256 amount) public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public setAllowance(sender, msg.sender, amount) returns (bool) {
        _transfer(sender, recipient, amount);
        return true;
    }

    function burnFrom(address account, uint256 amount)
        public
        setAllowance(account, msg.sender, amount)
    {
        _burn(account, amount);
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        returns (bool)
    {
        _approve(
            msg.sender,
            spender,
            _allowances[msg.sender][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        setAllowance(msg.sender, spender, subtractedValue)
        returns (bool)
    {
        return true;
    }

    /* ========== RESTRICTED FUNCTIONS ========== */

    function mint(address account, uint256 amount) public {
        bool isMinter = false;
        for (uint256 i; i < minters.length; i++) {
            if (minters[i] == msg.sender) {
                isMinter = true;
                break;
            }
        }
        require(isMinter, "Happy: sender is not allowed to mint");
        assert(maxSupply >= totalSupply + amount);
        _mint(account, amount);
    }

    function changeBurnPercent(uint256 _burnPercent) public onlyOwner {
        require(_burnPercent < 5, "Happy: Cannot set burn percent above 4");
        burnPercent = _burnPercent;
    }

    function manageWhitelist(address _contract, bool isWhitelisted)
        public
        onlyOwner
    {
        _burnTaxWhitelist[_contract] = isWhitelisted;
    }

    function setPendingMinters(address[] memory _minters) public onlyOwner {
        pendingMinters = _minters;
        timelockEnd = block.timestamp + _TIMELOCK;
        emit PendingMinters(pendingMinters, timelockEnd);
    }

    function cancelPendingMinters() public onlyOwner clearTimelock {}

    function setMinters() public onlyOwner clearTimelock {
        require(
            minters.length != 0 ||
                (timelockEnd != 0 && block.timestamp >= timelockEnd),
            "Happy: cannot change minter contracts before timelock end"
        );
        minters = pendingMinters;
    }

    /* ========== INTERNAL FUNCTIONS ========== */

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        if (
            burnPercent > 0 &&
            _isContract(recipient) &&
            !_burnTaxWhitelist[recipient]
        ) {
            uint256 burnAmount = (amount * burnPercent) / 100;
            _burn(sender, burnAmount);
            amount -= burnAmount;
        }
        uint256 senderBalance = _balances[sender];
        require(
            senderBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");
        totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");
        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        totalSupply -= amount;
        burnedSupply += amount;
        emit Transfer(account, address(0), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /* ========== MODIFIERS ========== */

    modifier setAllowance(
        address account,
        address sender,
        uint256 amount
    ) {
        uint256 currentAllowance = allowance(account, sender);
        require(
            currentAllowance >= amount,
            "ERC20: spend amount exceeds allowance"
        );
        unchecked {
            _approve(account, sender, currentAllowance - amount);
        }
        _;
    }

    modifier clearTimelock() {
        _;
        delete pendingMinters;
        timelockEnd = 0;
        emit SetMinters(minters);
    }

    /* ========== EVENTS ========== */

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
    event PendingMinters(address[] pendingMinters, uint256 timelockEnd);
    event SetMinters(address[] minters);
}
