//client

import std.stdio;
import std.string;
import std.algorithm;
import core.stdc.stdlib;
import vibe.d;

class Game { 
	const uint rows = 14;
	const uint cols = 14;
	char[rows][cols] field;
	char current = 'X'; 
	Direction[] allDirections = [Direction(1,0), Direction(0,1), Direction(1,1), Direction(1,-1)];

	
	void render () @safe {
		write("  ");
		char letter = 'A';
		for(int i = 0; i < cols; i++){
			write("|");
			write(letter);
			letter++;
		}
		write("|\n");

		char letter2 = 'a';
		for(int i = 0; i<rows; i++) {
			write("  ");
			for(int j = 0; j<cols;j++){
				write("+-");
			}
			write("+\n ");
			write(letter2);
			for(int j = 0; j<cols;j++){
				write("|");
				if(field[i][j]!= 'X' && field[i][j]!='O')
					write(" ");
				else
					write(field[i][j]);
			}
			write("|\n");
			letter2++;
			}
		write("  ");
		for(int j = 0; j<cols;j++){
				write("+-");
			}
			write("+\n");
	}

	void changeCurrent() @safe{
		if(current == 'X')
			current = 'O';
		else
			current = 'X';
	}


	auto cellsAround (Position pos, Direction d) {
	return around(pos, d, 4).map!(p=>field[p.i][p.j]);
  }

	bool gameOver(Position pos){
		bool ended = 
			allDirections.any!(d => cellsAround(pos, d).hasSequence('X', 5));
		
		return ended;
	}

	void setInput(Position pos)  @safe {
		field[pos.i][pos.j] = current;
	}
	
}
bool hasSequence(Range, V) (Range r, V val, size_t target) {
	size_t counter = 0;
	foreach(e; r){
		if(e == val){
			counter++;

			if(counter == target)
				return true;
		}
		else
			counter = 0;
	}
	return false;
}

struct PosToDirRange {
	Position front;
	Position end;
	Direction dir;

	bool empty () {
		return front == end;
	}

	void popFront() {
		front.i += dir.i;
		front.j += dir.j;
	}
}

PosToDirRange around(Position center, Direction dir, uint radius) {
	uint left = min(radius, borderDistance(center, minusDir(dir)));
	uint right = min(radius, borderDistance(center, dir)) + 1;
	return PosToDirRange(
		Position(center.i - dir.i*left, center.j - dir.j*left),
		Position(center.i + dir.i*right, center.j + dir.j*right),
		dir
	);
}




uint borderDistance(uint p, int d) {
	if(d<0) {
		return p;
	}
	else if( d== 0) {
		return 18;
	}
	else {
		return 18 -p;
	}
}

uint borderDistance(Position pos, Direction dir){
	return min(borderDistance(pos.i, dir.i),
			borderDistance(pos.j, dir.j));
}

struct Position {
	uint i;
	uint j;
}
struct Direction {
	uint i,j;
		
}
Direction minusDir(Direction d) {
	Direction dir;
	dir.i=-d.i;
	dir.j=-d.j;
	return dir;
}

Position readInput(string s){
	int x = s[0] - 'a';
	int y = s[1] - 'A';
	Position input;
	input.i = x;
	input.j = y;
	return input;
}
/*
interface IControlStream {
	Position read();
	void write(Position); 
}
class ConsoleStream : IControlStream {
	Position read() {
		string s = readln(); //aA
		int x = s[0] - 'a';
		int y = s[1] - 'A';
		Position input;
		input.i = x;
		input.j = y;
		return input;
	}
	void write(string input) {
		writeln("Your turn was ", input[0], ", ", input[1]);
		conn->write(input);
	}
	TCPConnection conn;
}
*/
void main () @trusted {
	runTask({ {
		writeln("start");
		auto conn = connectTCP("127.0.0.1", 7000);
		Game game = new Game;
		game.render();
		string inputString = "";
		bool gameOver = false;
		Position inputPosition;
		while(!gameOver) {

			writeln();
			if(game.current == 'O') {
				
				while(1) {
					write("Hi, O! hint: type aA: ");
					inputString = readln();
					inputPosition = readInput(inputString); 
					if((inputString.length != 2+1 )|| (inputPosition.i > game.rows ) || (inputPosition.j > game.cols)||(game.field[inputPosition.i][inputPosition.j]=='X')|| (game.field[inputPosition.i][inputPosition.j]=='O'))
						write("bad move! \n");
					else break;
				}
				game.setInput(inputPosition);
				inputString = inputString ~ "\r\n";
				conn.write(inputString);
				gameOver = game.gameOver(inputPosition);
				if(!gameOver) game.changeCurrent();
				system("cls");
				game.render();
			}
			else {
				write("Waiting for X's turn..\n");
				string opponentInputString = cast(string)conn.readLine();
				writeln("received ", opponentInputString);
				auto opponentInputPosition = readInput(opponentInputString);
				game.setInput(opponentInputPosition);
				gameOver = game.gameOver(opponentInputPosition);
				write("got the message");
				if(!gameOver) game.changeCurrent();
				system("cls");
				game.render();
			}
		}
		writeln("Congratulations, ", game.current, " !");
	}});
	runApplication();
	}
