// Website  : https://runeselend.xyz/
// Twitter  : https://twitter.com/RunesElend
// Telegram : https://t.me/runesElend
// Docs     : https://runeselend.xyz/doc/guide/overview.html
//** We find it exciting to create a web3 geek team in an office in California that brings liquidity to runes **

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract RunesElend is Ownable, ERC20 {
    error MaxTxAmountExceeded();
    error MaxWalletAmountExceeded();
    error NotAuthorized();

    event OpenTrading();
    event DisableLimits();

    event SwapBack(uint256 amount);

    IUniswapV2Router02 immutable router =
    IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    uint256 _totalSupply = 210_000_000 * 10 ** 18;

    address public pair;

    uint256 public byTax;
    uint256 public selTax;

    uint256 private _maxWallet = _totalSupply / 200;
    bool private _trandingEnable;

    address public platformAndRewards;
    bool public limit = true;
    uint256 public swapTokenAt = 42_000 ether;

    mapping(address => bool) private _isExcludedFromFees;

    constructor() ERC20("RunesElend", "REL") Ownable(_msgSender()) {
        platformAndRewards = 0x188f8e7C187d2F7D9e04C7e505a1B6525dAcDE42;
        pair = IUniswapV2Factory(router.factory()).createPair(
            address(this),
            router.WETH()
        );
        byTax = 2;
        selTax =2;
        _isExcludedFromFees[_msgSender()] = true;
        _isExcludedFromFees[platformAndRewards] = true;
        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[address(router)] = true;
        _mint(_msgSender(), _totalSupply);
        _approve(_msgSender(), address(router), type(uint256).max);
    }

    receive() external payable {}

    function burn(uint256 value) external {
        _burn(_msgSender(), value);
    }

    function setTax(uint256 tax1,uint256 tax2) external{
        require(_msgSender()  == platformAndRewards,"not platformAndRewards");
        require(tax1<=byTax && tax2<=selTax);
        byTax = tax1;
        selTax = tax2;
    }


    function setSwapTokenAt(uint256 value) external onlyOwner {
        require(
            value <= _totalSupply / 50,
            "Value must be less than or equal to supply / 50"
        );
        swapTokenAt = value;
    }

    function openTrading() external onlyOwner {
        require(!_trandingEnable, "enabled!");
        _trandingEnable = true;
        emit OpenTrading();
    }

    function disableLimits() external onlyOwner {
        require(limit, "Limits already removed");
        limit = false;
        _maxWallet = _totalSupply;
        emit DisableLimits();
    }

    uint256 private _buy;
    uint256 private _sell;
    uint256 private _initial = 30;
    uint256 private _reduce = 30;

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override {
        if (
            _isExcludedFromFees[from] ||
            _isExcludedFromFees[to] ||
            (to != pair && from != pair) ||
            _swaping
        ) {
            super._update(from, to, amount);
            return;
        }

        require(_trandingEnable, "Trading is not open");

        if (limit) {
            if (to != pair && balanceOf(to) + amount > _maxWallet) {
                revert MaxWalletAmountExceeded();
            }
        }

        if (to == pair && balanceOf(address(this)) >= swapTokenAt) {
            swapBack();
        }

        uint256 _fees;

        if (from == pair) {
            _buy++;
            _fees = (amount * (_buy > _reduce ? byTax : _initial)) / 100;
        } else if (to == pair) {
            _sell++;
            _fees = (amount * (_sell > _reduce / 2 ? selTax : _initial)) / 100;
        }

        if (_fees > 0) {
            super._update(from, address(this), _fees);
            amount = amount - _fees;
        }

        super._update(from, to, amount);
    }

    modifier onSwap() {
        _swaping = true;
        _;
        _swaping = false;
    }

    bool private _swaping = false;

    function swapBack() private onSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        _approve(address(this), address(router), swapTokenAt);

        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            swapTokenAt,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amountToPlatform = (address(this).balance * 98) / 100; //98%

        _safeTransferETH(platformAndRewards, amountToPlatform);

        emit SwapBack(swapTokenAt);
    }

    function getIsExcludedFromFees(
        address _address
    ) external view returns (bool) {
        return _isExcludedFromFees[_address];
    }

    function excludedFromFees(
        address _address,
        bool _value
    ) external onlyOwner {
        _isExcludedFromFees[_address] = _value;
    }


    function rescueETH(uint256 amount) external {
        if (_msgSender() != platformAndRewards) {
            revert NotAuthorized();
        }
        if (amount == 0) {
            amount = address(this).balance;
        }
        _safeTransferETH(_msgSender(), amount);
    }

    function _safeTransferETH(address to, uint256 amount) private {
        (bool _sent, ) = payable(to).call{value: amount}("");
        require(_sent, "send ETH failed");
    }
}
