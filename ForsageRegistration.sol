// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Forsage {
    struct User {
        uint256 id;
        address referrer;
        mapping(uint8 => bool) activeX3Levels;
        mapping(uint8 => bool) activeX6Levels;
        mapping(uint8 => uint8) x3ReinvestCount;
        mapping(uint8 => uint8) x6ReinvestCount;
        mapping(uint8 => uint8) x3CycleCount; // New: Tracks the number of cycles in X3 for each level
    }

    mapping(address => User) public users;
    mapping(uint256 => address) public idToAddress;
    mapping(address => uint256) public balances;

    uint256 public lastUserId = 2; // Start from 2 because 1 is reserved for the owner
    uint8 public constant LAST_LEVEL = 12;
    uint256 public constant INITIAL_LEVEL_PRICE = 5 ether; // Level 1 price is 5 ether

    event Registration(address indexed user, address indexed referrer, uint256 indexed userId);
    event Upgrade(address indexed user, uint8 matrix, uint8 level);
    event Reinvest(address indexed user, uint8 matrix, uint8 level);
    event CycleCompleted(address indexed user, uint8 matrix, uint8 level, uint8 cycle); // New: Event for X3 cycle completion

    constructor(address ownerAddress) {
        User storage user = users[ownerAddress];
        user.id = 1;
        user.referrer = address(0);

        for (uint8 i = 1; i <= LAST_LEVEL; i++) {
            user.activeX3Levels[i] = true;
            user.activeX6Levels[i] = true;
        }

        idToAddress[1] = ownerAddress;
    }

    function registration(address referrerAddress) external payable {
        require(msg.value == INITIAL_LEVEL_PRICE * 2, "Registration requires 10 Ether"); // 5 Ether for X3 and 5 Ether for X6
        require(!isUserExists(msg.sender), "User already registered");
        require(isUserExists(referrerAddress), "Referrer does not exist");

        uint256 userId = lastUserId;
        lastUserId++;

        User storage user = users[msg.sender];
        user.id = userId;
        user.referrer = referrerAddress;

        idToAddress[userId] = msg.sender;

        // Automatically activate the user in the first level of both X3 and X6
        user.activeX3Levels[1] = true;
        user.activeX6Levels[1] = true;

        emit Registration(msg.sender, referrerAddress, userId);
        emit Upgrade(msg.sender, 3, 1); // X3 Level 1 activation
        emit Upgrade(msg.sender, 6, 1); // X6 Level 1 activation

        distributePayment(msg.sender, 3, 1, msg.value / 2); // X3 payment
        distributePayment(msg.sender, 6, 1, msg.value / 2); // X6 payment
    }

    function upgradeLevel(uint8 matrix, uint8 level) external payable {
        require(isUserExists(msg.sender), "User is not registered");
        require(level > 1 && level <= LAST_LEVEL, "Invalid level");

        uint256 levelPrice = getLevelPrice(level);
        if (matrix == 3) {
            require(!users[msg.sender].activeX3Levels[level], "X3 Level already activated");
            require(msg.value == levelPrice, "Incorrect amount sent for X3 upgrade");

            users[msg.sender].activeX3Levels[level] = true;
            emit Upgrade(msg.sender, 3, level); // X3 level upgrade

            distributePayment(msg.sender, 3, level, msg.value);

        } else if (matrix == 6) {
            require(!users[msg.sender].activeX6Levels[level], "X6 Level already activated");
            require(msg.value == levelPrice, "Incorrect amount sent for X6 upgrade");

            users[msg.sender].activeX6Levels[level] = true;
            emit Upgrade(msg.sender, 6, level); // X6 level upgrade

            distributePayment(msg.sender, 6, level, msg.value);

        } else {
            revert("Invalid matrix type");
        }
    }

    function isUserExists(address user) public view returns (bool) {
        return (users[user].id != 0);
    }

    function getLevelPrice(uint8 level) public pure returns (uint256) {
        return INITIAL_LEVEL_PRICE * (2 ** (level - 1)); // Level price doubles at each level
    }

    function distributePayment(address user, uint8 matrix, uint8 level, uint256 amount) private {
        address referrer = users[user].referrer;

        if (matrix == 3) {
            // Handle X3 payments
            balances[referrer] += amount;

            // Increment the reinvest count
            users[referrer].x3ReinvestCount[level]++;
            
            // Check if the user has completed a cycle
            if (users[referrer].x3ReinvestCount[level] == 3) {
                users[referrer].x3ReinvestCount[level] = 0;
                users[referrer].x3CycleCount[level]++;
                emit Reinvest(referrer, 3, level);
                emit CycleCompleted(referrer, 3, level, users[referrer].x3CycleCount[level]); // New: Emit event for cycle completion
                // Implement reinvest logic here...
            }
        } else if (matrix == 6) {
            // Handle X6 payments
            balances[referrer] += amount;

            // Increment the reinvest count
            users[referrer].x6ReinvestCount[level]++;

            // Example logic for reinvest after a certain condition
            if (users[referrer].x6ReinvestCount[level] == 4) {
                users[referrer].x6ReinvestCount[level] = 0;
                emit Reinvest(referrer, 6, level);
                // Implement reinvest logic here...
            }
        }
    }

    function withdraw() external {
        uint256 balance = balances[msg.sender];
        require(balance > 0, "Insufficient balance");
        balances[msg.sender] = 0;
        payable(msg.sender).transfer(balance);
    }
}
