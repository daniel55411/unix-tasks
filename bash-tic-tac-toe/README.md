## Tic-tac-toe game
Tic-tac-toe game on _Bash_ is __localhost game__ because of using local fifo file

Example of game field:
```
 X |   |            X |   |
---+---+---        ---+---+---
   |   |              |   |
---+---+---        ---+---+---
   | O |              | O |
Your turn: 2 3     Wait your opponent...
```

## How to play
1. Ensure fifo `tic-tac-toe-fifo` doesn't exist. 
Fifo is located in the same directory where is script of game
2. Give permissions to the script with command: `chmod +x tic-tac-toe.sh`
3. Start from first console, then do it from another one
4. When game is over fifo will be deleted automatically

If first step won't be executed both consoles will have to wait

## Caution
Game is only for two players and trying to connect by third player will cause the game to malfunction
