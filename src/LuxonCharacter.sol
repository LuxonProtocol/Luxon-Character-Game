// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title LuxonCharacter
 * @author Luxon Protocol Team
 * @notice NFT-based RPG game characters with battle mechanics
 * @dev Implements ERC-721 with custom game logic
 */
contract LuxonCharacter is ERC721, ERC721URIStorage, Ownable {
    
    /// @notice Protocol version
    string public constant VERSION = "1.0.0";
    
    // Character stats structure
    struct CharacterStats {
        uint8 level;
        uint16 health;
        uint16 attack;
        uint16 defense;
        uint32 experience;
        uint32 battlesWon;
        uint64 lastBattleTime;
    }

    // Token ID counter
    uint256 private _nextTokenId;

    // Mapping from token ID to character stats
    mapping(uint256 => CharacterStats) public characterStats;

    // Game constants
    uint256 public constant MINT_PRICE = 0.01 ether;
    uint32 public constant BATTLE_COOLDOWN = 1 hours;
    uint32 public constant XP_PER_BATTLE = 100;
    uint32 public constant XP_TO_LEVEL = 500;

    // Events
    event CharacterMinted(
        address indexed owner,
        uint256 indexed tokenId,
        uint8 level
    );
    event BattleCompleted(
        uint256 indexed attackerId,
        uint256 indexed defenderId,
        bool attackerWon
    );
    event LevelUp(uint256 indexed tokenId, uint8 newLevel);

    constructor() ERC721("Luxon Character", "LUXCHAR") Ownable(msg.sender) {}

    /**
     * @notice Mint a new Luxon Character NFT
     * @return tokenId The ID of the newly minted character
     */
    function mintCharacter() public payable returns (uint256) {
        require(msg.value >= MINT_PRICE, "Insufficient Payment");

        uint256 tokenId = _nextTokenId++;
        _safeMint(msg.sender, tokenId);

        // Initialize character with base stats
        characterStats[tokenId] = CharacterStats({
            level: 1,
            health: 100,
            attack: 10,
            defense: 5,
            experience: 0,
            battlesWon: 0,
            lastBattleTime: 0
        });

        emit CharacterMinted(msg.sender, tokenId, 1);
        return tokenId;
    }

    /**
     * @notice Battle between two characters
     * @param attackerId Token ID of attacking character
     * @param defenderId Token ID of defending character
     */
    function battle(uint256 attackerId, uint256 defenderId) public {
        require(ownerOf(attackerId) == msg.sender, "Not Your Character");
        require(_exists(defenderId), "Defender does not exist");
        require(attackerId != defenderId, "Cannot battle self");

        CharacterStats storage attacker = characterStats[attackerId];
        CharacterStats storage defender = characterStats[defenderId];

        require(
            block.timestamp >= attacker.lastBattleTime + BATTLE_COOLDOWN,
            "Character is Resting"
        );

        uint256 attackerPower = uint256(attacker.attack) *
            uint256(attacker.level);
        uint256 defenderPower = uint256(defender.defense) *
            uint256(defender.level);

        uint256 randomness = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.prevrandao,
                    attackerId,
                    defenderId
                )
            )
        ) % 100;

        bool attackerWon = (attackerPower + randomness) > defenderPower;

        if (attackerWon) {
            attacker.battlesWon++;
            attacker.experience += XP_PER_BATTLE;

            if (attacker.experience >= XP_TO_LEVEL * uint32(attacker.level)) {
                _levelUp(attackerId);
            }
        } else {
            defender.experience += XP_PER_BATTLE / 2;

            if (defender.experience >= XP_TO_LEVEL * uint32(defender.level)) {
                _levelUp(defenderId);
            }
        }
        
        attacker.lastBattleTime = uint64(block.timestamp);
        emit BattleCompleted(attackerId, defenderId, attackerWon);
    }

    

    /**
     * @notice Train character (alternative XP gain without battling)
     * @param tokenId Token ID of character to train
     */
    function train(uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender, "Not Your Character");

        CharacterStats storage stats = characterStats[tokenId];
        require(
            block.timestamp >= stats.lastBattleTime + BATTLE_COOLDOWN,
            "Character is Resting"
        );

        stats.experience += XP_PER_BATTLE / 2;
        stats.lastBattleTime = uint64(block.timestamp);

        if (stats.experience >= XP_TO_LEVEL * uint32(stats.level)) {
            _levelUp(tokenId);
        }
    }

    /**
     * @notice Get character stats
     * @param tokenId Token ID of character
     * @return CharacterStats memory struct with all stats
     */
    function getCharacterStats(uint256 tokenId)
        public
        view
        returns (CharacterStats memory)
    {
        require(_exists(tokenId), "Character does not exist");
        return characterStats[tokenId];
    }

    /**
     * @notice Check if character can battle (cooldown passed)
     * @param tokenId Token ID of character
     * @return bool True if character can battle
     */
    function canBattle(uint256 tokenId) public view returns (bool) {
        if (!_exists(tokenId)) return false;
        CharacterStats memory stats = characterStats[tokenId];
        return block.timestamp >= stats.lastBattleTime + BATTLE_COOLDOWN;
    }

    /**
     * @notice Get all characters owned by an address
     * @param owner Address to query
     * @return uint256[] Array of token IDs
     */
    function getOwnedCharacters(address owner)
        public
        view
        returns (uint256[] memory)
    {
        uint256 balance = balanceOf(owner);
        uint256[] memory ownedTokens = new uint256[](balance);
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < _nextTokenId && currentIndex < balance; i++) {
            if (_exists(i) && ownerOf(i) == owner) {
                ownedTokens[currentIndex] = i;
                currentIndex++;
            }
        }

        return ownedTokens;
    }

    /**
     * @notice Withdraw contract balance (owner only)
     */
    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "No Funds to withdraw");

        (bool success, ) = payable(owner()).call{value: balance}("");
        require(success, "Withdraw failed");
    }

    // Override required functions
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev Internal helper to check if token exists
     */
    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }

    /**
     * @dev Internal function to level up a character
     */
    function _levelUp(uint256 tokenId) internal {
        CharacterStats storage stats = characterStats[tokenId];
        stats.level++;
        stats.health += 20;
        stats.attack += 5;
        stats.defense += 3;
        emit LevelUp(tokenId, stats.level);
    }
}