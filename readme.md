### a client and a server for gomoku game

#### basics

the field is 15x15 (hardcoded) so last letter is oO

#### format
- server sends client "X\r\n" or "O\r\n", which determines client's mark. 

- aA

where first letter should be lowercase and it stands for row and second letter schould be uppercase and stands for column

// todo make case insensitive

if input is wrong, you'll be prompted to reinput

separator is \r\n, but u don't have to care about that in input

- game ends when server replies with "WON\r\n" or "LOST\r\n" or "DRAW\r\n"

but in reality both client and server have ther own check for game termination

#### how to run

##### server

`dub`
no cli args for server. it always starts at 127.0.0.1:7000
##### client

`dub -- --hostport "<host> <port>"`
if this complex argument cannot be parsed, client connects to 127.0.0.1:7000
