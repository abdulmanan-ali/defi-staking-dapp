// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./ERC20.sol";

contract MTKPay is ERC20, ERC20Burnable, Ownable, AccessControl {
    MTKRewards public mtk;

    mapping(address => uint256) private _balances;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    constructor(MTKRewards _mtk) {
        mtk = _mtk;
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        _setupRole(MANAGER_ROLE, _msgSender());
    }

    function safeMtkTransfer(address _to, uint256 _amount) external {
        require(hasRole(MANAGER_ROLE, _msgSender()), "Not allowed");
        uint256 mtkBal = mtk.balanceOf(address(this));
        if (_amount > mtkBal) {
            mtk.transfer(_to, mtkBal);
        } else {
            mtk.transfer(_to, _amount);
        }
    }
}
