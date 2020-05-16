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
import std.datetime.systime : SysTime, Clock;
import std.algorithm.searching;

struct MarkedPosition {
    Position pos;
    char mark;
}

class Tree {
    MarkedPosition[] moves = [];
    int estimation = 0;
    Tree[] children = [];
    Tree root;
}

char[15][15] init_field() {
    char[15][15] fld;
    for (int i = 0; i < 15; i++) {
        for (int j = 0; j < 15; j++)
            fld[i][j] = ' ';
    }
    return fld;
}

char[15][15] fill_field(MarkedPosition[] moves) {
    auto fld = init_field();
    foreach (MarkedPosition mp; moves)
        fld[mp.pos.i][mp.pos.j] = mp.mark;
    return fld;
}

char[15][15] fill_field(char[15][15] already_filled, MarkedPosition[] moves) {
    auto fld = already_filled;
    foreach (MarkedPosition mp; moves)
        fld[mp.pos.i][mp.pos.j] = mp.mark;
    return fld;
}

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
        auto helperfunc = (Position p) {
            if ((p.i < rows) && (p.j < cols))
                return fld[p.i][p.j];
            return '\0';
        };
        auto res = around(pos, d, 4).map!(p => helperfunc(p));
        return to!string(res.array); // mapResult -> char[] -> string
    }

    bool gameOver(Position pos, char mark) {
        bool ended = allDirections.any!(d => cellsAround(pos, d, field).hasSequence(mark, 5)); //point pos(i,j) in any of direcrions of alldirections has 5X sequence ( BUT CAN IT BE 0????)
        bool draw = is_draw();
        return (ended || draw);
    }

    bool is_skip(Position pos, MarkedPosition[] moves) {
        auto fld = fill_field(field, moves);
        foreach (Direction d; allDirections) {
            auto str = (cellsAround(pos, d, fld));
            if (!(str == to!string(replicate(" ", str.length))))
                return false;
        }
        return true;
    }

    bool is_draw() {

        return false;
    }

    void setInput(Position pos) @safe {
        field[pos.i][pos.j] = current;
    }

    int estimate_state(char player_mark, MarkedPosition[] moves) {
        char[rows][cols] fld = fill_field(moves);
        auto filled = get_non_empty_positions(fld);
        int result = 0;
        string pattern;
        string line;
		string line_potential;
        ulong c;
        foreach (Position p; filled) {
            foreach (Direction d; allDirections) {
				line_potential = cellsAround(p, d, fld);
                line = cellsAround(p, d, field);
                
				//it's good to count both what we have already on field and what we would gain if move in this direction
                result += 3 * count(line_potential, player_mark) +  2* (count(line_potential, player_mark) - count(line, player_mark)); // accent in attacking
                result += count(line_potential, " ");
                result -= 2 * count(line_potential, reverse_mark(player_mark));
            }
        }
        return result;
    }

    Position[] get_empty_positions(char[rows][cols] fld) {
        Position[] res = [];
        for (int i = 0; i < rows; i++) {
            for (int j = 0; j < cols; j++) {
                if (fld[i][j] == ' ')
                    res ~= [Position(i, j)];
            }
        }
        // sort to start as close to the center as possible
        return res.sort!("(abs(7-to!int(a.i)) + abs(7-to!int(a.j))) < (abs(7-to!int(b.i)) + abs(7-to!int(b.j)))")
            .array;
    }

    Position[] get_non_empty_positions(char[rows][cols] fld) {
        Position[] res = [];
        for (int i = 0; i < rows; i++) {
            for (int j = 0; j < cols; j++) {
                if (fld[i][j] != ' ')
                    res ~= [Position(i, j)];
            }
        }
        return res;
    }

    Position[] position_difference(Position[] empties, Position[] nonempties) {
        Position[] result = [];
        foreach (Position elem; empties) {
            if (!nonempties.canFind(elem)) {
                result ~= elem;
            }

        }
        return result;
    }

    Position[] toPositionType(MarkedPosition[] input) {
        Position[] res = [];
        foreach (MarkedPosition elem; input)
            res ~= [elem.pos];
        return res;
    }

    Position where_to_move(int depth, int width) {
        auto root = new Tree;
        auto possibilities = get_empty_positions(field);
        auto tmp = new Tree;

        if (possibilities.length == rows * cols)
            return Position(to!int(rows / 2), to!int(cols / 2));

        SysTime startTime = Clock.currTime();

        foreach (Position pos; possibilities) {
            if (is_skip(pos, root.moves))
                continue;
            tmp = new Tree;
            tmp.moves ~= MarkedPosition(pos, server_mark);
            tmp.root = root;
            root.children ~= [tmp];
        }

        foreach (Tree child; root.children) {
            auto empties = position_difference(get_empty_positions(field),
                    toPositionType(child.moves));
            foreach (Position pos; empties) {
                if (is_skip(pos, child.moves))
                    continue;
                tmp = new Tree;
                tmp.moves = child.moves ~ [MarkedPosition(pos, client_mark)];
                tmp.root = child;
                //tmp.estimation = estimate_state(server_mark, tmp.moves);
                child.children ~= [tmp];
            }
        }

        foreach (Tree child1; root.children) {
            foreach (Tree child2; child1.children) {
                auto empties = position_difference(get_empty_positions(field),
                        toPositionType(child2.moves));
                foreach (Position pos; empties) {
                    if (is_skip(pos, child2.moves))
                        continue;
                    tmp = new Tree;
                    tmp.moves = child2.moves ~ [
                        MarkedPosition(pos, server_mark)
                    ];
                    tmp.root = child2;
                    tmp.estimation = estimate_state(server_mark, tmp.moves);
                    child2.children ~= [tmp];
                }
            }
        }

        writeln("processed in ", Clock.currTime() - startTime);

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

        foreach (Tree child1; root.children) {
            foreach (Tree child2; child1.children) {
                child2.estimation = child2.children.fold!(helpermax).estimation;
                child2.children = [];
            }

        }

        foreach (Tree child1; root.children) {
            child1.estimation = child1.children.fold!(helpermin).estimation;
            child1.children = [];
        }
        return root.children.fold!(helpermax).moves[0].pos;
    }
}

bool hasSequence(Range, V)(Range r, V val, size_t target) {
    size_t counter = 0;
    foreach (e; r) {
        if (e == val) {
            counter++;
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
        if (today.dayOfYear % 2 != 0) {
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
            system("cls");
            game.render();
        }
        writeln("Congratulations, ", game.current, " !");
    });
    runApplication();
}

unittest {
    char[15][15] fld = init_field();
    fld[0][0] = 'X';
    auto game = new Game;

    assert(15 == game.estimate_state('X', fld));
}

unittest {
    char[15][15] fld = init_field();
    fld[0][0] = 'X';
    fld[14][14] = 'O';
    auto game = new Game;

    assert(0 == game.estimate_state('X', fld));
}

unittest {
    char[15][15] fld = init_field();
    fld[0][0] = 'X';
    int counter = 0;

    auto game = new Game;
    for (int i = 0; i < 15; i++) {
        for (int j = 0; j < 15; j++) {
            if ((i == 0) && (j == 0))
                continue;
            counter = counter + to!int(game.is_skip(Position(i, j), fld));
        }
    }
    writeln(counter);
    assert(counter == 3 * 4);
}

