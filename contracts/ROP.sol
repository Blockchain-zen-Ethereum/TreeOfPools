//SPDX-License-Identifier: GNU GPLv3
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../contracts/Ranking.sol";
import "../contracts/BOP.sol";

/// @title The root of the poole tree. Allows you to close control of a large
/// number of pools to 1 address. Simplifies user interaction with a large number of pools.
/// @author Nethny
/// @dev Must be the owner of child contracts, to short-circuit the administrative
/// rights to one address.
contract RootOfPools_v013 is Initializable, OwnableUpgradeable {
    using AddressUpgradeable for address;
    using Strings for uint256;

    struct Pool {
        address pool;
        string name;
    }

    Pool[] Pools;

    mapping(string => address) private _poolsTable;

    address public _usdAddress;
    address public _rankingAddress;

    event PoolCreated(string name, address pool);

    /// @notice Replacement of the constructor to implement the proxy
    function initialize(address usdAddress, address rankingAddress)
        external
        initializer
    {
        __Ownable_init();
        _usdAddress = usdAddress;
        _rankingAddress = rankingAddress;
    }

    /// @notice Returns the address of the usd token in which funds are collected
    function getUSDAddress() public view returns (address) {
        return _usdAddress;
    }

    /// @notice Returns the linked branch contracts
    function getPools() public view returns (Pool[] memory) {
        return Pools;
    }

    /// @notice Allows you to attach a new pool (branch contract)
    function createPool(string calldata name, address pool) public onlyOwner {
        require(isContract(pool), "ROOT: Pool must be a contract!");
        require(
            _poolsTable[name] == address(0),
            "ROOT: Pool with this name already exists!"
        );

        _poolsTable[name] = pool;

        Pool memory poolT = Pool(pool, name);
        Pools.push(poolT);

        emit PoolCreated(name, pool);
    }

    /// @notice The following functions provide access to the functionality of linked branch contracts
    function changeTargetValue(string calldata name, uint256 value)
        public
        onlyOwner
    {
        require(
            _poolsTable[name] != address(0),
            "ROOT: Selected pool does not exist!"
        );

        BranchOfPools(_poolsTable[name]).changeTargetValue(value);
    }

    function changeStepValue(string calldata name, uint256 step)
        public
        onlyOwner
    {
        require(
            _poolsTable[name] != address(0),
            "ROOT: Selected pool does not exist!"
        );

        BranchOfPools(_poolsTable[name]).changeStepValue(step);
    }

    function changeDevAddress(string calldata name, address developers)
        public
        onlyOwner
    {
        require(
            _poolsTable[name] != address(0),
            "ROOT: Selected pool does not exist!"
        );

        BranchOfPools(_poolsTable[name]).changeDevAddress(developers);
    }

    function startFundraising(string calldata name) public onlyOwner {
        require(
            _poolsTable[name] != address(0),
            "ROOT: Selected pool does not exist!"
        );

        BranchOfPools(_poolsTable[name]).startFundraising();
    }

    function collectFunds(string calldata name) public onlyOwner {
        require(
            _poolsTable[name] != address(0),
            "ROOT: Selected pool does not exist!"
        );

        BranchOfPools(_poolsTable[name]).collectFunds();
    }

    function stopFundraising(string calldata name) public onlyOwner {
        require(
            _poolsTable[name] != address(0),
            "ROOT: Selected pool does not exist!"
        );

        BranchOfPools(_poolsTable[name]).stopFundraising();
    }

    function stopEmergency(string calldata name) public onlyOwner {
        require(
            _poolsTable[name] != address(0),
            "ROOT: Selected pool does not exist!"
        );

        BranchOfPools(_poolsTable[name]).stopEmergency();
    }

    function paybackEmergency(string calldata name) public {
        require(
            _poolsTable[name] != address(0),
            "ROOT: Selected pool does not exist!"
        );

        BranchOfPools(_poolsTable[name]).paybackEmergency();
    }

    function deposit(string calldata name, uint256 amount) public {
        require(
            _poolsTable[name] != address(0),
            "ROOT: Selected pool does not exist!"
        );

        BranchOfPools(_poolsTable[name]).deposit(amount);
    }

    function entrustToken(
        string calldata name,
        address token,
        uint256 amount
    ) public {
        require(
            _poolsTable[name] != address(0),
            "ROOT: Selected pool does not exist!"
        );

        BranchOfPools(_poolsTable[name]).entrustToken(token, amount);
    }

    function claimName(string calldata name) public payable {
        require(
            _poolsTable[name] != address(0),
            "ROOT: Selected pool does not exist!"
        );

        BranchOfPools(_poolsTable[name]).claim();
    }

    function claimAddress(address pool) internal {
        require(pool != address(0), "ROOT: Selected pool does not exist!");

        BranchOfPools(pool).claim();
    }

    function claimAll() public payable {
        for (uint256 i = 0; i < Pools.length; i++) {
            if (BranchOfPools(Pools[i].pool).isClaimable(tx.origin)) {
                claimAddress(Pools[i].pool);
            }
        }
    }

    function checkAllClaims(address user) public view returns (bool) {
        uint256 temp = 0;
        for (uint256 i = 0; i < Pools.length; i++) {
            temp += (BranchOfPools(Pools[i].pool).myCurrentAllocation(user));
        }

        if (temp > 0) {
            return true;
        } else {
            return false;
        }
    }

    function getAllocations(address user, uint256 step)
        public
        view
        returns (uint256[10] memory)
    {
        uint256[10] memory amounts;
        for (
            uint256 i = 0;
            (i + 10 * step < (step + 1) * 10) && (i + 10 * step < Pools.length);
            i++
        ) {
            amounts[i] = (BranchOfPools(Pools[i].pool).myAllocation(user));
        }
        return amounts;
    }

    function getState(string calldata name)
        public
        view
        returns (BranchOfPools.State)
    {
        require(
            _poolsTable[name] != address(0),
            "ROOT: Selected pool does not exist!"
        );

        return BranchOfPools(_poolsTable[name]).getState();
    }

    function getRanks() public view returns (address) {
        return _rankingAddress;
    }

    function isContract(address account) internal view returns (bool) {
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        assembly {
            codehash := extcodehash(account)
        }
        return (codehash != accountHash && codehash != 0x0);
    }
}
