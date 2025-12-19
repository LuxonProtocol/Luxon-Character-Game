// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


import {Test} from "forge-std/Test.sol";
import {LuxonCharacter} from "../src/LuxonCharacter.sol";

contract LuxonCharacterTest is Test {
    LuxonCharacter internal game;

    address internal owner;
    address internal player1;
    address internal player2;

    uint256 internal constant MINT_PRICE = 0.01 ether;
    uint256 internal constant COOLDOWN = 1 hours;

    function setUp() public {
        owner = address(this);
        player1 = makeAddr("player1");
        player2 = makeAddr("player2");

        vm.deal(player1, 10 ether);
        vm.deal(player2, 10 ether);

        game = new LuxonCharacter();
    }

    /*//////////////////////////////////////////////////////////////
                              MINTING
    //////////////////////////////////////////////////////////////*/

    function testMintCharacter_Success() public {
        vm.prank(player1);
        uint256 tokenId = game.mintCharacter{value: MINT_PRICE}();

        assertEq(tokenId, 0);
        assertEq(game.ownerOf(tokenId), player1);

        LuxonCharacter.CharacterStats memory stats =
            game.getCharacterStats(tokenId);

        assertEq(stats.level, 1);
        assertEq(stats.health, 100);
        assertEq(stats.attack, 10);
        assertEq(stats.defense, 5);
        assertEq(stats.experience, 0);
    }

    function testMintCharacter_RevertOnInsufficientPayment() public {
        vm.prank(player1);
        vm.expectRevert("Insufficient payment");
        game.mintCharacter{value: 0.001 ether}();
    }

    /*//////////////////////////////////////////////////////////////
                              BATTLE
    //////////////////////////////////////////////////////////////*/

    function testBattle_SuccessAndXPIncrease() public {
        uint256 char1 = _mint(player1);
        uint256 char2 = _mint(player2);

        vm.prank(player1);
        game.battle(char1, char2);

        LuxonCharacter.CharacterStats memory stats =
            game.getCharacterStats(char1);

        assertTrue(stats.experience > 0);
    }

    function testBattle_RevertIfOnCooldown() public {
        uint256 char1 = _mint(player1);
        uint256 char2 = _mint(player2);

        vm.prank(player1);
        game.battle(char1, char2);

        vm.prank(player1);
        vm.expectRevert("Character is resting");
        game.battle(char1, char2);
    }

    function testBattle_AllowsAfterCooldown() public {
        uint256 char1 = _mint(player1);
        uint256 char2 = _mint(player2);

        vm.prank(player1);
        game.battle(char1, char2);

        vm.warp(block.timestamp + COOLDOWN + 1);

        vm.prank(player1);
        game.battle(char1, char2);
    }

    function testBattle_RevertIfBattlingSelf() public {
        uint256 char1 = _mint(player1);

        vm.prank(player1);
        vm.expectRevert("Cannot battle yourself");
        game.battle(char1, char1);
    }

    function testBattle_RevertIfNotOwner() public {
        uint256 char1 = _mint(player1);
        uint256 char2 = _mint(player2);

        vm.prank(player2);
        vm.expectRevert("Not your character");
        game.battle(char1, char2);
    }

    /*//////////////////////////////////////////////////////////////
                              PROGRESSION
    //////////////////////////////////////////////////////////////*/

    function testCharacterLevelsUpAfterBattles() public {
        uint256 char1 = _mint(player1);
        uint256 char2 = _mint(player2);

        for (uint256 i = 0; i < 6; i++) {
            vm.warp(block.timestamp + COOLDOWN + 1);
            vm.prank(player1);
            game.battle(char1, char2);
        }

        LuxonCharacter.CharacterStats memory stats =
            game.getCharacterStats(char1);

        assertTrue(stats.level >= 2);
    }

    function testTrain_IncreasesExperience() public {
        uint256 char1 = _mint(player1);

        vm.prank(player1);
        game.train(char1);

        LuxonCharacter.CharacterStats memory stats =
            game.getCharacterStats(char1);

        assertTrue(stats.experience > 0);
    }

    /*//////////////////////////////////////////////////////////////
                              VIEWS
    //////////////////////////////////////////////////////////////*/

    function testGetOwnedCharacters() public {
        uint256 char1 = _mint(player1);
        uint256 char2 = _mint(player1);

        uint256[] memory owned = game.getOwnedCharacters(player1);

        assertEq(owned.length, 2);
        assertEq(owned[0], char1);
        assertEq(owned[1], char2);
    }

    function testCanBattle_ViewFunction() public {
        uint256 char1 = _mint(player1);
        uint256 char2 = _mint(player2);

        assertTrue(game.canBattle(char1));

        vm.prank(player1);
        game.battle(char1, char2);

        assertFalse(game.canBattle(char1));

        vm.warp(block.timestamp + COOLDOWN + 1);
        assertTrue(game.canBattle(char1));
    }

    /*//////////////////////////////////////////////////////////////
                              WITHDRAW
    //////////////////////////////////////////////////////////////*/

    function testWithdraw_SendsFundsToOwner() public {
        _mint(player1);

        uint256 balanceBefore = owner.balance;
        game.withdraw();
        uint256 balanceAfter = owner.balance;

        assertEq(balanceAfter - balanceBefore, MINT_PRICE);
    }

    /*//////////////////////////////////////////////////////////////
                              HELPERS
    //////////////////////////////////////////////////////////////*/

    function _mint(address user) internal returns (uint256) {
        vm.prank(user);
        return game.mintCharacter{value: MINT_PRICE}();
    }

    receive() external payable {}
}
