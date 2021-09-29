include Camlboy_lib
open Uints

let addr = Uint16.of_int 0xFF47

let%expect_test "test create then read" =
  let t = Pallete.create ~addr in

  Pallete.read_byte t addr
  |> Uint8.show
  |> print_endline;

  (* $E4 = 0b11100100 *)
  [%expect {| $E4 |}]

let%expect_test "lookup" =
  let t = Pallete.create ~addr in

  [ID_00; ID_01; ID_10; ID_11]
  |> List.map (Pallete.lookup t)
  |> List.map Color.show
  |> List.iter print_endline;

  [%expect {|
    Color.White
    Color.Light_gray
    Color.Dark_gray
    Color.Black |}]

let%expect_test "write then read" =
  let t = Pallete.create ~addr in

  Pallete.write_byte t ~addr ~data:Uint8.(of_int 0b00011011);
  Pallete.read_byte t addr
  |> Uint8.show
  |> print_endline;

  (* 0b00011011 = $1B*)
  [%expect {| $1B |}]
