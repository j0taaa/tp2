(* Scanner-oriented test deck for PA2.
   This file mixes valid tokens and recoverable lexical errors so that
   running ./lexer shows both normal tokenization and error recovery. *)

cLaSs Main InHeRiTs IO {
    main() : SELF_TYPE {
        {
            let obj : Main <- new Main,
                flag : Bool <- true,
                count : Int <- 12345
            in {
                if not false then
                    obj@Main.main()
                else
                    self
                fi;

                case count of
                    value : Int => value + 1;
                esac;
            };

            TypeName objectName SELF_TYPE self true false tRuE fAlSe True False;
            x <- y <= z;
            a + b / c - d * e = f < g . h ~ i, j;

            "plain string";
            "escape\n\t\b\f\"\\\0";

            (* outer comment
               (* nested comment *)
               still inside outer comment *)

            *)
            #
            "unterminated

            self;
        }
    };
};
