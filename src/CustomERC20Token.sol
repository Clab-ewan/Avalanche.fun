// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/interfaces/IVRFCoordinatorV2Plus.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title CustomERC20Token
 * @dev ERC20 token with Chainlink VRF v2+ gambling functionality
 */
contract CustomERC20Token is ERC20, VRFConsumerBaseV2Plus {
    uint8 private _decimals;

    // Chainlink VRF variables
    IVRFCoordinatorV2Plus private COORDINATOR;
    uint256 private s_subscriptionId;
    bytes32 private keyHash;

    // VRF Configuration
    uint32 private callbackGasLimit = 100000;
    uint16 private requestConfirmations = 3;
    uint32 private numWords = 1; // We only need one random number for our gambling game

    // Gambling variables
    struct GambleBet {
        address player;
        uint256 betAmount;
        bool fulfilled;
        uint256 randomNumber;
        uint256 payout;
    }

    mapping(uint256 => GambleBet) public gambleBets;
    mapping(address => uint256[]) public playerBets;

    uint256 public minimumBet;
    uint256 public houseEdge = 500; // 5% house edge (500 basis points)
    uint256 public constant BASIS_POINTS = 10000;

    // Events
    event BetPlaced(address indexed player, uint256 indexed requestId, uint256 betAmount);
    event BetResult(address indexed player, uint256 indexed requestId, uint256 randomNumber, uint256 payout, bool won);
    event TokensBurned(address indexed player, uint256 amount);
    event TokensMinted(address indexed player, uint256 amount);
    event HouseEdgeUpdated(uint256 newHouseEdge);
    event MinimumBetUpdated(uint256 newMinimumBet);

    constructor(
        string memory name,
        string memory symbol,
        uint8 tokenDecimals,
        uint256 initialSupply,
        address owner,
        address vrfCoordinator,
        uint256 subscriptionId,
        bytes32 _keyHash
    ) ERC20(name, symbol) VRFConsumerBaseV2Plus(vrfCoordinator) {
        _decimals = tokenDecimals;
        _mint(owner, initialSupply * 10 ** tokenDecimals);

        COORDINATOR = IVRFCoordinatorV2Plus(vrfCoordinator);
        s_subscriptionId = subscriptionId;
        keyHash = _keyHash;
        minimumBet = 1 * 10 ** tokenDecimals; // 1 token minimum bet
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Allows owner to mint additional tokens
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @dev Allows owner to burn tokens from their balance
     */
    function burn(uint256 amount) external onlyOwner {
        _burn(msg.sender, amount);
    }

    /**
     * @dev Place a gambling bet using Chainlink VRF
     * @param betAmount Amount of tokens to bet
     * @param useNativePayment Whether to pay for VRF in native tokens (true) or LINK (false)
     */
    function placeBet(uint256 betAmount, bool useNativePayment) external returns (uint256 requestId) {
        require(betAmount >= minimumBet, "Bet amount too low");
        require(balanceOf(msg.sender) >= betAmount, "Insufficient balance");

        // Burn the bet tokens immediately
        _burn(msg.sender, betAmount);
        emit TokensBurned(msg.sender, betAmount);

        // Request randomness from Chainlink VRF v2+
        requestId = COORDINATOR.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: useNativePayment}))
            })
        );

        // Store bet information
        gambleBets[requestId] =
            GambleBet({player: msg.sender, betAmount: betAmount, fulfilled: false, randomNumber: 0, payout: 0});

        playerBets[msg.sender].push(requestId);

        emit BetPlaced(msg.sender, requestId, betAmount);

        return requestId;
    }

    /**
     * @dev Callback function used by VRF Coordinator
     */
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        require(gambleBets[requestId].player != address(0), "Request not found");
        require(!gambleBets[requestId].fulfilled, "Request already fulfilled");

        GambleBet storage bet = gambleBets[requestId];
        bet.randomNumber = randomWords[0];
        bet.fulfilled = true;

        // Calculate payout based on random number
        uint256 payout = calculatePayout(bet.betAmount, bet.randomNumber);
        bet.payout = payout;

        // Mint payout tokens to player (if they won anything)
        if (payout > 0) {
            _mint(bet.player, payout);
            emit TokensMinted(bet.player, payout);
        }

        emit BetResult(bet.player, requestId, bet.randomNumber, payout, payout > bet.betAmount);
    }

    /**
     * @dev Calculate payout based on random number
     * The gambling logic:
     * - 0-4999 (50%): Player loses everything (0x multiplier)
     * - 5000-7999 (30%): Player gets 1.5x their bet
     * - 8000-9499 (15%): Player gets 3x their bet
     * - 9500-9899 (4%): Player gets 10x their bet
     * - 9900-9999 (1%): Player gets 50x their bet
     */
    function calculatePayout(uint256 betAmount, uint256 randomNumber) internal pure returns (uint256) {
        uint256 roll = randomNumber % 10000; // Convert to 0-9999 range

        if (roll < 5000) {
            return 0; // Player loses
        } else if (roll < 8000) {
            return (betAmount * 15) / 10; // 1.5x multiplier
        } else if (roll < 9500) {
            return betAmount * 3; // 3x multiplier
        } else if (roll < 9900) {
            return betAmount * 10; // 10x multiplier
        } else {
            return betAmount * 50; // 50x multiplier
        }
    }

    /**
     * @dev Get player's bet history
     */
    function getPlayerBets(address player) external view returns (uint256[] memory) {
        return playerBets[player];
    }

    /**
     * @dev Get bet details
     */
    function getBetDetails(uint256 requestId)
        external
        view
        returns (address player, uint256 betAmount, bool fulfilled, uint256 randomNumber, uint256 payout)
    {
        GambleBet memory bet = gambleBets[requestId];
        return (bet.player, bet.betAmount, bet.fulfilled, bet.randomNumber, bet.payout);
    }



    /**
     * @dev Update minimum bet (only owner)
     */
    function setMinimumBet(uint256 newMinimumBet) external onlyOwner {
        minimumBet = newMinimumBet;
        emit MinimumBetUpdated(newMinimumBet);
    }

    /**
     * @dev Update VRF configuration (only owner)
     */
    function updateVRFConfig(
        uint256 subscriptionId,
        bytes32 _keyHash,
        uint32 _callbackGasLimit,
        uint16 _requestConfirmations,
        uint32 _numWords
    ) external onlyOwner {
        s_subscriptionId = subscriptionId;
        keyHash = _keyHash;
        callbackGasLimit = _callbackGasLimit;
        requestConfirmations = _requestConfirmations;
        numWords = _numWords;
    }

    /**
     * @dev Get VRF configuration
     */
    function getVRFConfig()
        external
        view
        returns (
            uint256 subscriptionId,
            bytes32 _keyHash,
            uint32 _callbackGasLimit,
            uint16 _requestConfirmations,
            uint32 _numWords
        )
    {
        return (s_subscriptionId, keyHash, callbackGasLimit, requestConfirmations, numWords);
    }

    /**
     * @dev Get contract's token balance (should always be 0 in burn/mint system)
     */
    function getHouseBalance() external view returns (uint256) {
        return balanceOf(address(this));
    }

    /**
     * @dev Emergency function (modified for burn/mint system)
     */
    function emergencyWithdraw() external onlyOwner {
        // In burn/mint system, contract shouldn't hold tokens
        // This function is kept for any edge cases where tokens might be stuck
        uint256 contractBalance = balanceOf(address(this));
        if (contractBalance > 0) {
            _transfer(address(this), owner(), contractBalance);
        }
    }
}
