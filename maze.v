`timescale 1ns / 1ps
module maze(
    input clk,
    input [5:0] starting_col, starting_row,
    input maze_in,
    output reg [5:0] row, col,
    output reg maze_oe,	
    output reg maze_we,
    output reg done 
);

// definirea starilor automatului
`define DO_RIGHT 0
`define MOVE_RIGHT 1
`define MOVE_FWD 2
`define MOVE_LEFT 3
`define DONE 4


// definirea directiilor de inaintare prin labirint
`define UP 0
`define RIGHT 1
`define DOWN 2
`define LEFT 3

reg [1:0] dir = `UP; // directia curenta de navigare
reg [5:0] x = 6'd0, y = 6'd0; // pozitia curenta in labirint
reg [5:0] prev_x = 6'd0, prev_y = 6'd0; // ultima pozitie marcata
reg [4:0] state, next_state = `DO_RIGHT; // starea curenta si urmatoarea

// flags
reg wall_flag = 1'b0; // stocare temporara pentru maze_in
reg init_flag = 1'b0; // flag pentru initializarea automatului

// initiaza verificarea wall-ului din fata
task is_wall_front(); begin
    maze_oe = 1'b1;

    // in functie de directia curenta se verifica pozitii diferite
    case(dir)
        `UP: begin
            row = y - 1;
            col = x;
        end
        `RIGHT: begin
            row = y;
            col = x + 1;
        end
        `DOWN: begin
            row = y + 1;
            col = x;
        end
        `LEFT: begin
            row = y;
            col = x - 1;
        end
    endcase
end endtask

// initiaza verificarea wall-ului din dreapta
task is_wall_right(); begin
    maze_oe = 1'b1;

    case(dir)
        `UP: begin
            row = y;
            col = x + 1;
        end
        `RIGHT: begin
            row = y + 1;
            col = x;
        end
        `DOWN: begin
            row = y;
            col = x - 1;
        end
        `LEFT: begin
            row = y - 1;
            col = x;
        end
    endcase
end endtask

// initiaza verificarea wall-ului din stanga
task is_wall_left(); begin
    maze_oe = 1'b1;

    case(dir)
        `UP: begin
            row = y;
            col = x - 1;
        end
        `RIGHT: begin
            row = y - 1;
            col = x;
        end
        `DOWN: begin
            row = y;
            col = x + 1;
        end
        `LEFT: begin
            row = y + 1;
            col = x;
        end
    endcase
end endtask

// finalizeaza verificarea wall-ului
// aceasta operatiune a fost initiata de una din task-urile precedente
task check_wall(); begin
    wall_flag = maze_in;
    maze_oe = 1'b0;
end endtask

// roteste directia de navigare spre dreapta (ex: up -> right; +90 grade)
task turn_right(); begin
    if(dir == 3) begin
        dir = 0;
    end else begin
        dir = dir + 1;
    end
end endtask

// roteste directia de navigare spre stanga (ex: up -> left; -90 grade)
task turn_left(); begin
    if(dir == 0) begin
        dir = 3;
    end else begin
        dir = dir - 1;
    end
end endtask

// seteaza directia de navigare opusa (ex: up -> down; +180 grade)
task turn_arround(); begin
    turn_right();
    turn_right();
end endtask

// marcheaza pozitia curenta ca fiind parcursa
task mark_path(); begin
    row = y;
    col = x;

    maze_we = 1'b1;
end endtask

// navigheaza o unitate inainte in functie de directia curenta de navigare
task move_forward(); begin
    mark_path();

    // stocam ultima pozitie inainte de a naviga; necesar in cazul in care intr-o stare se vor face 2 scrieri
    prev_x = x;
    prev_y = y;

    case(dir)
        `UP: begin
            y = y - 1;
        end
        `RIGHT: begin
            x = x + 1;
        end
        `DOWN: begin
            y = y + 1;
        end
        `LEFT: begin
            x = x - 1;
        end
    endcase
end endtask

// verifica daca s-a ajuns la sfarsitul labirintului
task check_end(); begin
    if(x == 6'd0 || x == 6'd63 || y == 6'd0 || y == 6'd63) begin
        mark_path();
        next_state = `DONE;
    end else begin
        next_state = `DO_RIGHT;
    end
end endtask

always @(posedge clk) begin
    // pentru fiecare clock rising edge se face tranzitia la urmatoarea stare
    state <= next_state;
end

always @(*) begin
    maze_we = 1'b0; // se reseteaza flag-ul de scriere
    check_wall(); // se finalizeaza verificarea wall-ului (in cazul in care a fost initiata)

    case(state)
        `DO_RIGHT: begin
            // initializare automat; se intampla o singura data
            if(init_flag == 1'b0) begin
                init_flag = 1'b1;

                x = starting_col;
                y = starting_row;
            end

            is_wall_right();
            next_state = `MOVE_RIGHT;
        end
        `MOVE_RIGHT: begin
            if(wall_flag == 1'b1) begin
                is_wall_front();
                next_state = `MOVE_FWD;
            end else begin
                turn_right();
                move_forward();
                check_end();
            end
        end
        `MOVE_FWD: begin
            if(wall_flag == 1'b1) begin
                is_wall_left();
                next_state = `MOVE_LEFT;
            end else begin
                move_forward();
                check_end();
            end
        end
        `MOVE_LEFT: begin
            if(wall_flag == 1'b1) begin
                turn_arround();
                move_forward();
                check_end();
            end else begin
                turn_left();
                move_forward();
                check_end();
            end
        end
        `DONE: begin
            // in starea trecuta s-au facut 2 mark_path (ultimul move, si check_end), deci prima dintre ele nu a putut fi finalizata
            // se face o noua scriere la pozitia care nu a putut fi finalizata
            row = prev_y;
            col = prev_x;
            maze_we = 1'b1;

            done = 1'b1;
        end
    endcase
end

endmodule