### a client and a server for gomoku game

##### input format

aA
where first letter should be lowercase and it stands for row and second letter schould be uppercase and stands for column
// todo make case insensitive
the field is 15x15 so last letter is nN

#####how to run

######server

dub
no cli args for server. it always starts at 127.0.0.1:7000
######client

dub -- --hostport "<host> <port>"
if this complex argument cannot be parsed, client connects to 127.0.0.1:7000