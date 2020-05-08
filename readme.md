### a client and a server for gomoku game

#### basics

#### input format
- server sends client "X\r\n" or "O\r\n". it determines client's mark. 

- aA

where first letter should be lowercase and it stands for row and second letter schould be uppercase and stands for column
// todo make case insensitive
the field is 15x15 so last letter is oO
if input is wrong, you'll be prompted to reinput

- game terminates when server replies with "WON\r\n" or "LOST\r\n" or "DRAW\r\n"

#### how to run

##### server

`dub`
no cli args for server. it always starts at 127.0.0.1:7000
##### client

`dub -- --hostport "<host> <port>"`
if this complex argument cannot be parsed, client connects to 127.0.0.1:7000
