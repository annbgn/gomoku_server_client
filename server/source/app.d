//server

import std.stdio;
import std.string;
import std.algorithm;
import core.stdc.stdlib;
import vibe.d;

class Game { 
	const uint rows = 15;
	const uint cols = 15;
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
	// d - is an element of  alldirections so it might be Direction(1,0), Direction(0,1), Direction(1,1), Direction(1,-1)
	auto helperfunc = (Position p) {if ((p.i < rows) &&(p.j < cols)) return field[p.i][p.j]; return '\0';}; //allows not to get rangeerror and not affect hassequence logic
	auto res = around(pos, d, 4).map!(p=> helperfunc(p)); 
	writeln(res);
	return res;
  }

	bool gameOver(Position pos, char mark){
		bool ended = 
			allDirections.any!(d => cellsAround(pos, d).hasSequence(mark, 5)); //point pos(i,j) in any of direcrions of alldirections has 5X sequence ( BUT CAN IT BE 0????)
		bool draw = is_draw();
		return (ended||draw);
	}

	bool is_draw (){return false;}

	void setInput(Position pos)  @safe {
		field[pos.i][pos.j] = current;
	}
	
}
bool hasSequence(Range, V) (Range r, V val, size_t target) {
	size_t counter = 0;
	foreach(e; r){
		if(e == val){
			counter++;
			// cool place to embed ai logic
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
	// returns radius(4) nearest points to center(i,j) in chosen direction
	// if near border, then less than 4
	uint left = min(radius, borderDistance(center, minusDir(dir)));
	uint right = min(radius, borderDistance(center, dir)) + 1;
	auto res = PosToDirRange(
		Position(center.i - dir.i*left, center.j - dir.j*left),
		Position(center.i + dir.i*right, center.j + dir.j*right),
		dir
	);
	writeln(res);
	return res;
}




uint borderDistance(uint p, int d) {
	if(d<0) {
		return p;
	}
	else if( d== 0) {
		return 18;  //why 18? 14+4?
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

void main (	) @trusted {
	listenTCP(7000,(conn) {
		Game game = new Game;
		game.render();
		string inputString = "";
		bool gameOver = false;
		Position inputPosition;

		// send client it's mark
		conn.write("O\r\n");  // todo randomize (based on mod2 of time)
		while(!gameOver) {

			writeln();
			if(game.current == 'X') {

				while(1) {
					write("Hi, Server (X)! hint: type aA: ");
					inputString = readln();
					inputPosition = readInput(inputString); 
					if((inputString.length != 2+1 )|| (inputPosition.i > game.rows ) || (inputPosition.j > game.cols)||(game.field[inputPosition.i][inputPosition.j]=='X')|| (game.field[inputPosition.i][inputPosition.j]=='O'))
						write("bad move!\n");
					else break;
				}
				game.setInput(inputPosition);
				inputString = inputString ~ "\r\n";
				conn.write(inputString);
				gameOver = game.gameOver(inputPosition, 'X');
				
				
			}
			else {
				write("Waiting for Client (O)'s turn..\n");
				string opponentInputString = cast(string)conn.readLine();
				writeln("received ", opponentInputString);
				auto opponentInputPosition = readInput(opponentInputString);
				game.setInput(opponentInputPosition);
				gameOver = game.gameOver(opponentInputPosition, 'O');
				
			}
			if(!gameOver) game.changeCurrent();
				system("cls");
				game.render();
		}
		writeln("Congratulations, ", game.current, " !");
	});
	runApplication();
}
/*
	unittest {
	// test case when any input with letter bigger than k causes range error
		char[14][14] field;
		Position pos;
		pos  = readInput("kK\0");


}
*/