//server

import std.stdio;
import std.string;
import std.algorithm;
import core.stdc.stdlib;
import vibe.d;
import std.datetime.timezone : LocalTime;
import std.regex;
import std.array : array;
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
	EstimationElem(400, "* ***"),
	EstimationElem(400, "** **"),
    EstimationElem(100, "  ***   "),
	EstimationElem(80, "  ***  "),
    EstimationElem(75, " ***  "),
	EstimationElem(50, " *** "),
	EstimationElem(50, "***  "),
    EstimationElem(25, "* ** "),
	EstimationElem(25, "** * "),
	EstimationElem(25,  "*  **"),
    EstimationElem(10, "   ***   "),
	EstimationElem(5, " ** ")
];
//dfmt on

const string GlobalEmptyPattern = "    *    ";

class Game {
    const uint rows = 15;
    const uint cols = 15;
    char[rows][cols] field;
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
                if (field[i][j] != 'X' && field[i][j] != 'O')
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

    string cellsAround(Position pos, Direction d) {
        // d - is an element of  alldirections so it might be Direction(1,0), Direction(0,1), Direction(1,1), Direction(1,-1)
        auto helperfunc = (Position p) {
            if ((p.i < rows) && (p.j < cols))
                return field[p.i][p.j];
            return '\0';
        }; //allows not to get rangeerror and not affect hassequence logic
        auto res = around(pos, d, 4).map!(p => helperfunc(p));
        return to!string(res.array); // mapResult -> char[] -> string
    }

    bool gameOver(Position pos, char mark) {
        bool ended = allDirections.any!(d => cellsAround(pos, d).hasSequence(mark, 5)); //point pos(i,j) in any of direcrions of alldirections has 5X sequence ( BUT CAN IT BE 0????)
        bool draw = is_draw();
        return (ended || draw);
    }

    bool is_draw() {
        //simply check that there are no empty cells
        int counter = 0;
        for (int i = 0; i < rows; i++) {
            for (int j = 0; j < cols; j++) {
                if ((field[i][j] == 'X') || (field[i][j] == 'O'))
                    counter++;
            }
        }
        if (counter == rows * cols)
            return true;
        return false;
    }

    void setInput(Position pos) @safe {
        field[pos.i][pos.j] = current;
    }

    GoodPositionToMove[] getGoodPositionsToMove(Position[] possible_moves, int depth) { //maximin
        // not implemented!!
        // get all empty cells
        // get array of weight for every cell 
        // recursively call this function <depth times> for player and opponent for every cell
        // 
        Position p;
        GoodPositionToMove[] result = [];
        int[rows][cols] cell_weights;
        for (int i = 0; i < rows; i++) {
            for (int j = 0; j < cols; j++)
                cell_weights[i][j] = 0;
        }
        for (int i = 0; i < rows; i++) {
            for (int j = 0; j < cols; j++) {

                foreach (Direction d; allDirections) {
                    string line = cellsAround(Position(i, j), d);
                    foreach (EstimationElem weight_regex; GlobalEstimationChart) {
                        string pattern = replace(weight_regex.pattern, '*', current);
                        if (!matchAll(line, pattern).empty) {
                            cell_weights[i][j] = cell_weights[i][j] + weight_regex.weight;
                        }
                    }
                }
                p.i = i;
                p.j = j;
                if (possible_moves.canFind(p))
                    result ~= [GoodPositionToMove(p, cell_weights[i][j])];
            }
        }
        return result;
    }

    Position where_to_move(int depth) {
        Position[] possible_moves = [];

        //todo replace loop with any! or map! for short
        for (int i = 0; i < rows; i++) {
            for (int j = 0; j < cols; j++) {
                if ((field[i][j] != 'X') && (field[i][j] != 'O'))
                    possible_moves ~= [Position(i, j)];
            }
        }
        if (possible_moves.length == rows * cols)
            return Position(to!int(rows / 2), to!int(cols / 2));
        else {
            GoodPositionToMove[] good = getGoodPositionsToMove(possible_moves, depth);
            return good.sort!("a.weight > b.weight")[0].pos;
        }
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
    int weight; // = int.min;
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
                Position move = game.where_to_move(1);
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
            system("cls");
            game.render();
        }
        writeln("Congratulations, ", game.current, " !");
    });
    runApplication();
}