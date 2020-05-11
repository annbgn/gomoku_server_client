//server

import std.stdio;
import std.string;
import std.algorithm;
import core.stdc.stdlib;
import vibe.d;
import std.datetime.timezone : LocalTime;
import std.regex;
import std.array : array;
import std.array : replicate;
import std.algorithm : canFind;

struct EstimationElem {
    int weight;
    string pattern;
}

//dfmt off
const EstimationElem[] GlobalEstimationChart = [
    EstimationElem(10000, "*****"),
	EstimationElem(1000, " **** "),
    EstimationElem(500, "**** "),
	EstimationElem(500, " ****"),
	EstimationElem(400, "* ***"),
	EstimationElem(400, "*** *"),
	EstimationElem(400, "** **"),
    EstimationElem(100, "  ***  "),
	EstimationElem(80, "  *** "),
    EstimationElem(80, " ***  "),
	EstimationElem(50, " *** "),
	EstimationElem(50, "***  "),
	EstimationElem(50, "  ***"),
    EstimationElem(25, "* ** "),
	EstimationElem(25, " * **"),
	EstimationElem(25, "** * "),
	EstimationElem(25, " ** *"),
	EstimationElem(25,  "*  **"),
	EstimationElem(25,  "**  *"),
	EstimationElem(25,  "* * *"),
	EstimationElem(5, " **  "),
	EstimationElem(5, "  ** "),
	EstimationElem(5, " * * "),
	EstimationElem(5, "**   "),
	EstimationElem(5, "   **"),
	EstimationElem(1, "*    "),
	EstimationElem(1, " *   "),
	EstimationElem(1, "  *  "),
	EstimationElem(1, "   * "),
	EstimationElem(1, "    *")
];
//dfmt on

const string GlobalEmptyPattern = "    *    ";

class Tree {
    char[15][15] fld;
    int estimation = 0;
    Position chosen_move;
    Tree[] children = [];
    Tree root;
}

char[15][15]  init_field() {char[15][15] fld; for(int i = 0; i < 15;i++){for (int j = 0; j < 15; j++)fld[i][j] = ' ';} return fld;}

class Game {
    const uint rows = 15;
    const uint cols = 15;
    char[rows][cols] field = init_field();
    char current = 'X';
    char server_mark;
    char client_mark;
    Direction[] allDirections = [
        Direction(1, 0), Direction(0, 1), Direction(1, 1), Direction(1, -1)
    ];

	

    void render() @safe {
        write("  ");
        char letter = 'A';
        for (int i = 0; i < cols; i++) {
            write("|");
            write(letter);
            letter++;
        }
        write("|\n");

        char letter2 = 'a';
        for (int i = 0; i < rows; i++) {
            write("  ");
            for (int j = 0; j < cols; j++) {
                write("+-");
            }
            write("+\n ");
            write(letter2);
            for (int j = 0; j < cols; j++) {
                write("|");
                if ((field[i][j] != 'X') && (field[i][j] != 'O'))
                    write(" ");
                else
                    write(field[i][j]);
            }
            write("|\n");
            letter2++;
        }
        write("  ");
        for (int j = 0; j < cols; j++) {
            write("+-");
        }
        write("+\n");
    }

    void changeCurrent() @safe {
        current = reverse_mark(current);
    }

    string cellsAround(Position pos, Direction d, char[rows][cols] fld) {
        // d - is an element of  alldirections so it might be Direction(1,0), Direction(0,1), Direction(1,1), Direction(1,-1)
        auto helperfunc = (Position p) {
            if ((p.i < rows) && (p.j < cols))
                return fld[p.i][p.j];
            return '\0';
        }; //allows not to get rangeerror and not affect hassequence logic
        auto res = around(pos, d, 4).map!(p => helperfunc(p));
        return to!string(res.array); // mapResult -> char[] -> string
    }

    bool gameOver(Position pos, char mark) {
        bool ended = allDirections.any!(d => cellsAround(pos, d, field).hasSequence(mark, 5)); //point pos(i,j) in any of direcrions of alldirections has 5X sequence ( BUT CAN IT BE 0????)
        bool draw = is_draw();
        return (ended || draw);
    }

	bool is_skip(Position pos, char[rows][cols] fld) {
		auto helperfunc = (Direction d) {auto str = (cellsAround(pos, d, fld)); return (str == to!string(replicate(" ", str.length)));}; // bc isWhite works only with char, not string		
        bool empty = allDirections.all!(helperfunc);
        return empty;
    }

    bool is_draw() {
        //simply check that there are no empty cells
        //due to lazy evaluations it'll work ok only if called after checking for win/lose, because even fully occupied board might be not draw
        /*for (int i = 0; i < rows; i++) {
            for (int j = 0; j < cols; j++) {
                if ((field[i][j] != 'X') || (field[i][j] != 'O'))
                    return true;
            }
        }*/
        return false;
    }

    void setInput(Position pos) @safe {
        field[pos.i][pos.j] = current;
    }

    int estimate_state(char player_mark, char[rows][cols] fld) {
        //counts matches for evety point for every regex pattern
        //i don't even wanna think what nesting depth is. it'd been a total mistake to implement trees
        int result = 0;
        string pattern;
		string line;
        for (int i = 0; i < rows; i++) {
            for (int j = 0; j < cols; j++) {
                foreach (Direction d; allDirections) {
                    line = cellsAround(Position(i, j), d, fld);
                    foreach (EstimationElem weight_regex; GlobalEstimationChart) {
                        pattern = replace(weight_regex.pattern, '*', player_mark);
                        if (!matchAll(line, pattern).empty) {
                            result += weight_regex.weight;
                        }
						pattern = replace(weight_regex.pattern, '*', reverse_mark(player_mark));
                        if (!matchAll(line, pattern).empty) {
                            result -= weight_regex.weight;
                        }
                    }
                }
            }
        }
        return result;
    }
	
    Position[] get_empty_positions(char[rows][cols] fld) {
		
        Position[] res = [];
        for (int i = 0; i < rows; i++) {
            for (int j = 0; j < cols; j++) {
                if (fld[i][j] == ' ')
                    res ~= [Position(i,j)];
            }
        }
		// sort to start as close to the center as possible, but it works weirdly.
		// i expect smth like (7,7), (6,7), (7,6), (7,8), (8,7), (6,6) ...
		// but i get Position(0, 14), Position(1, 13), Position(14, 0), Position(2, 12), Position(13, 1), Position(3, 11), Position(12, 2), Position(4, 10)
		// solved: it was magic of uint
		// todo: rewrite Position(uint i, uint j) to ints  and remove to!int below
        return res.sort!("(abs(7-to!int(a.i)) + abs(7-to!int(a.j))) < (abs(7-to!int(b.i)) + abs(7-to!int(b.j)))").array;  
    }    

    Position where_to_move(int depth, int width) {
		// no matter what depth is
		// but width is what  matters. it limits availiable and empty cells by <width> closest to center	
        auto root = new Tree;
        root.fld = field;
        auto possibilities = get_empty_positions(field);
		writeln(possibilities);
		auto tmp = new Tree;

		if (possibilities.length == rows*cols) return Position(to!int(rows /2), to!int(cols/2));

        // let depth = 4, bc i REALLY  can't imagine how to write a loop which can generate possibilities.length nodes on 1 step, possibilities.length - i nodes on i-th step, where i stands for depth. And how to fill in this structure after it is initialized :(
        // i guess it might work if d had smth like __getattr__('children') for lvl in range(depth)

		// todo rewrite it in evals :smartass: :smiling_imp:
		// :sad_imp: it seems there's no eval() func in D except arith-eval lib, but this one supports only math operaors

        foreach (Position pos; possibilities[0..min(possibilities.length-1, width)]) {
            if (is_skip(pos, field)) continue;
			tmp = new Tree;
			tmp.fld = field;				
			tmp.root = root;
            tmp.chosen_move = pos;
            tmp.fld[pos.i][pos.j] = server_mark;
            root.children ~= [tmp];
        }
		writeln ("here ", root.children.length); // 1 - 12-32, 2 < 64
		int cntr = 0;
		int cntr2 = 0;
        foreach (Tree child; root.children) {
			auto empties =  get_empty_positions(child.fld);
            foreach (Position pos; empties[0..min(empties.length-1, to!int(width*0.75))]) {
				cntr ++;
                if (is_skip(pos, child.fld)) continue;
				cntr2++;
				tmp = new Tree;
				tmp.fld = child.fld;
                tmp.root = child;
                tmp.chosen_move = pos;
                tmp.fld[pos.i][pos.j] = client_mark;
				tmp.estimation = estimate_state(server_mark, tmp.fld);
                child.children ~= [tmp];
            }
        }
		writeln ("here2 ",  cntr, " ", cntr2);  // 20 * 15  
		/*
        foreach (Tree child1; root.children) {
            foreach (Tree child2; child1.children) {
                foreach (Position pos; get_empty_positions(child2.fld)) {
                    if (is_skip(pos, child2.fld)) continue;
					tmp = new Tree;
                    tmp.fld = child2.fld;
					tmp.root = child2;
                    tmp.chosen_move = pos;
                    tmp.fld[pos.i][pos.j] = server_mark;
					//tmp.estimation = estimate_state(server_mark, tmp.fld);
                    child2.children ~= [tmp];
                }
            }
        }
		writeln ("here3");
		
        foreach (Tree child1; root.children) {
            foreach (Tree child2; child1.children) {
                foreach (Tree child3; child2.children) {
                    foreach (Position pos; get_empty_positions(child3.fld)) {
                        if (is_skip(pos, child3.fld)) continue;
						tmp = new Tree;
                        tmp.fld = child3.fld;
                        tmp.root = child3;
                        tmp.chosen_move = pos;
                        tmp.fld[pos.i][pos.j] = client_mark;
                        child3.children ~= [tmp];
                    }
                }
            }
        }
		writeln ("here4");
        foreach (Tree child1; root.children) {
            foreach (Tree child2; child1.children) {
                foreach (Tree child3; child2.children) {
                    foreach (Tree child4; child3.children) {
                        foreach (Position pos; get_empty_positions(child4.fld)) {
                            if (is_skip(pos, child4.fld)) continue;
							tmp = new Tree;
                            tmp.fld = child4.fld;
                            tmp.root = child4;
                            tmp.chosen_move = pos;
                            tmp.fld[pos.i][pos.j] = server_mark;
                            tmp.estimation = estimate_state(server_mark, tmp.fld);
                            child4.children ~= [tmp];
                        }
                    }
                }
            }
        }
		*/
        // and now reduce :)

        auto helpermax = (Tree t1, Tree t2) {
            if (t1.estimation > t2.estimation)
                return t1;
            return t2;
        };
        auto helpermin = (Tree t1, Tree t2) {
            if (t1.estimation < t2.estimation)
                return t1;
            return t2;
        };
		/*
		writeln ("here5");
        foreach (Tree child1; root.children) {
            foreach (Tree child2; child1.children) {
                foreach (Tree child3; child2.children) {
                    child3.estimation = child3.children.fold!(helpermax).estimation;
                    child3.children = []; // no strong refs for children, hope gc works well
                }
            }
        }
		writeln ("here6");
        foreach (Tree child1; root.children) {
            foreach (Tree child2; child1.children) {
                child2.estimation = child2.children.fold!(helpermin).estimation;
                child2.children = [];
            }
        }*/
		writeln ("here7");
        foreach (Tree child1; root.children) {
            child1.estimation = child1.children.fold!(helpermax).estimation;
            child1.children = [];
        }

        return root.children.fold!(helpermin).chosen_move;
    }
}

bool hasSequence(Range, V)(Range r, V val, size_t target) {
    size_t counter = 0;
    foreach (e; r) {
        if (e == val) {
            counter++;
            // cool place to embed ai logic
            if (counter == target)
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

    bool empty() {
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
    auto res = PosToDirRange(Position(center.i - dir.i * left,
            center.j - dir.j * left), Position(center.i + dir.i * right,
            center.j + dir.j * right), dir);
    return res;
}

uint borderDistance(uint p, int d) {
    // 14 is field rows(=cols) -1
    if (d < 0)
        return p;
    else if (d == 0)
        return 14;
    else
        return 14 - p;
}

uint borderDistance(Position pos, Direction dir) {
    return min(borderDistance(pos.i, dir.i), borderDistance(pos.j, dir.j));
}

struct Position {
    uint i;
    uint j;
}

struct Direction {
    uint i, j;

}

Direction minusDir(Direction d) {
    Direction dir;
    dir.i = -d.i;
    dir.j = -d.j;
    return dir;
}

Position readInput(string s) {
    int x = s[0] - 'a';
    int y = s[1] - 'A';
    Position input;
    input.i = x;
    input.j = y;
    return input;
}

string writeInput(Position pos) {
    char i = to!char(pos.i + 'a');
    char j = to!char(pos.j + 'A');
    string s = "";
    s ~= i;
    s ~= j;
    return s;
}

char reverse_mark(char mark) @safe {
    if (mark == 'X')
        return 'O';
    return 'X';
}

struct GoodPositionToMove {
    Position pos;
    int weight = int.min;
}

void main() @trusted {
    listenTCP(7000, (conn) {
        Game game = new Game;
        game.render();
        string inputString = "";
        bool gameOver = false;
        Position inputPosition;

        // send client it's mark
        SysTime today = Clock.currTime();
        if (today.dayOfYear % 2 == 0) {
            conn.write("O\r\n");
            game.server_mark = 'X';
        }
        else {
            conn.write("X\r\n");
            game.server_mark = 'O';
        }
        game.client_mark = reverse_mark(game.server_mark);

        writeln("client: ", game.client_mark, " server: ", game.server_mark);

        while (!gameOver) {

            writeln();
            if (game.current == game.server_mark) {
                /*
                while (1) {
                    write("Hi, Server (", game.server_mark, ")! hint: type aA: ");
                    inputString = readln();
                    inputPosition = readInput(inputString);
                    if ((inputString.length != 2 + 1) || (inputPosition.i > game.rows)
                        || (inputPosition.j > game.cols)
                        || (game.field[inputPosition.i][inputPosition.j] == game.client_mark)
                        || (game.field[inputPosition.i][inputPosition.j] == game.server_mark))
                        write("bad move!\n");
                    else
                        break;
                }
				game.setInput(inputPosition);
                inputString = inputString ~ "\r\n";
                conn.write(inputString);
                gameOver = game.gameOver(inputPosition, game.server_mark);
				*/
                Position move = game.where_to_move(4, 20);
                writeln("Hi, Server (", game.server_mark,
                    ")! AI chose to move to position ", move);
                game.setInput(move);
                inputString = writeInput(move) ~ "\r\n";
                conn.write(inputString);
                gameOver = game.gameOver(move, game.server_mark);

            }
            else {
                write("Waiting for Client (", game.client_mark, ")'s turn..\n");
                string opponentInputString = cast(string) conn.readLine();
                writeln("received ", opponentInputString);
                auto opponentInputPosition = readInput(opponentInputString);
                game.setInput(opponentInputPosition);
                gameOver = game.gameOver(opponentInputPosition, game.client_mark);

            }
            if (!gameOver)
                game.changeCurrent();
            //system("cls");
            game.render();
        }
        writeln("Congratulations, ", game.current, " !");
    });
    runApplication();
}


unittest {
char[15][15] fld = init_field();
fld[0][0] = 'X';
auto game =  new Game;

assert (15 == game.estimate_state('X', fld));
}



unittest {
char[15][15] fld = init_field();
fld[0][0] = 'X';
fld[14][14] = 'O';
auto game =  new Game;

assert (0 == game.estimate_state('X', fld));
}

unittest {
char[15][15] fld = init_field();
fld[0][0] = 'X';
int counter = 0;

auto game = new Game;
for (int i = 0;  i< 15; i++){
for (int j = 0; j < 15; j++){
if ((i==0) && (j==0)) continue;
counter = counter +to!int(game.is_skip(Position(i,j), fld));}}
writeln (counter);
assert (counter == 3*4);
}