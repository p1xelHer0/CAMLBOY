open Camlboy_lib
open Uints

module Mmu = Mock_mmu
module Cpu = Cpu.Make(Mock_mmu)

let create_cpu
    ?(a = 0x00) ?(b = 0x00) ?(c = 0x00)
    ?(d = 0x00) ?(e = 0x00) ?(h = 0x00) ?(l = 0x00)
    ?(carry=false) ?(half_carry=false) ?(sub=false) ?(zero=false)
    ?(pc = 0x00) ?(sp = 0x00)
    ?(halted = false)
    ?(mmu = Mmu.create ~size:0x10)
    ?(ime = true) () =
  let registers = Registers.create () in
  Registers.write_r registers A (Uint8.of_int a);
  Registers.write_r registers B (Uint8.of_int b);
  Registers.write_r registers C (Uint8.of_int c);
  Registers.write_r registers D (Uint8.of_int d);
  Registers.write_r registers E (Uint8.of_int e);
  Registers.write_r registers H (Uint8.of_int h);
  Registers.write_r registers L (Uint8.of_int l);
  Registers.set_flags registers ~c:carry ~h:half_carry ~n:sub ~z:zero ();
  let zeros = Bytes.create 0x10 in
  Bytes.fill zeros 0 0x10 (Char.chr 0);
  Mmu.load mmu ~src:zeros ~dst_pos:Uint16.zero;
  Cpu.For_tests.create
    ~mmu
    ~registers
    ~pc:(Uint16.of_int pc)
    ~sp:(Uint16.of_int sp)
    ~halted
    ~ime

let execute_result t inst =
  let cycles = (1, 2) in
  inst
  |> Cpu.For_tests.execute t cycles
  |> (fun x -> ignore (x : int))


let print_execute_result t inst =
  execute_result t inst;

  Cpu.show t
  |> print_endline

let print_addr_content mmu addr =
  Mmu.read_byte mmu (Uint16.of_int addr)
  |> show_uint8
  |> print_endline


let%expect_test "NOP" =
  let t = create_cpu () in

  NOP
  |> print_execute_result t;

  [%expect {|
    A:00 F:---- BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "LD B, 0xAB" =
  let t = create_cpu () in

  LD8 (R B, Immediate8 (Uint8.of_int 0xAB))
  |> print_execute_result t;

  [%expect {|
    A:00 F:---- BC:ab00 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "LD8 BC, 0xAABB" =
  let t = create_cpu () in

  LD16 (RR BC, Immediate16 (Uint16.of_int 0x9988))
  |> print_execute_result t;

  [%expect {|
    A:00 F:---- BC:9988 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "LD8 (HL), B" =
  let mmu = Mmu.create ~size:0x10 in
  let t = create_cpu ~l:0x2 ~b:0xAB ~mmu () in

  LD8 (RR_indirect HL, R B)
  |> print_execute_result t;

  [%expect {|
    A:00 F:---- BC:ab00 DE:0000 HL:0002 SP:0000 PC:0000 |}];

  print_addr_content mmu 0x2;
  [%expect {|0xab|}]

let%expect_test "LD8 (HL+), B" =
  let mmu = Mmu.create ~size:0x10 in
  let t = create_cpu ~l:0x2 ~b:0xAB ~mmu () in

  LD8 (HL_inc, R B)
  |> print_execute_result t;

  [%expect{|
    A:00 F:---- BC:ab00 DE:0000 HL:0003 SP:0000 PC:0000 |}];

  print_addr_content mmu 0x2;
  [%expect {|0xab|}]

let%expect_test "LD8 (HL-), B" =
  let mmu = Mmu.create ~size:0x10 in
  let t = create_cpu ~l:0x2 ~b:0xAB ~mmu () in

  LD8 (HL_dec, R B)
  |> print_execute_result t;

  [%expect{|
    A:00 F:---- BC:ab00 DE:0000 HL:0001 SP:0000 PC:0000 |}];

  print_addr_content mmu 0x2;
  [%expect {|0xab|}]

let%expect_test "LD8 HL, SP+0x03" =
  let t = create_cpu ~sp:0x1234 () in

  LD16 (RR HL, SP_offset (Int8.of_int 0x03))
  |> print_execute_result t;

  [%expect{|
    A:00 F:---- BC:0000 DE:0000 HL:1237 SP:1234 PC:0000 |}]

let%expect_test "LD8 HL, SP-0x03" =
  let t = create_cpu ~sp:0x1234 () in

  LD16 (RR HL, SP_offset (Int8.of_int (-0x03)))
  |> print_execute_result t;

  [%expect{|
    A:00 F:---- BC:0000 DE:0000 HL:1231 SP:1234 PC:0000 |}]

let%expect_test "LD8 SP, 0xABCD" =
  let t = create_cpu () in

  LD16 (SP, Immediate16 (0xabcd |> Uint16.of_int))
  |> print_execute_result t;

  [%expect{|
    A:00 F:---- BC:0000 DE:0000 HL:0000 SP:abcd PC:0000 |}]

let%expect_test "ADD A, 0xA0 (no half-carry/carry)" =
  let t = create_cpu ~a:0x01 () in

  ADD8 (R A, Immediate8 (Uint8.of_int 0xA0))
  |> print_execute_result t;

  [%expect{|
    A:a1 F:---- BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "ADD A, 0x0F (half-carry)" =
  let t = create_cpu ~a:0x01 () in

  ADD8 (R A, Immediate8 (Uint8.of_int 0x0F))
  |> print_execute_result t;

  [%expect{|
    A:10 F:--H- BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "ADD A, 0xFF (half-carry + carry)" =
  let t = create_cpu ~a:0x1 () in

  ADD8 (R A, Immediate8 (Uint8.of_int 0xFF))
  |> print_execute_result t;

  [%expect{|
    A:00 F:Z-HC BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "ADD SP, 0x01" =
  let t = create_cpu ~sp:0xAAFF () in

  ADDSP (Uint8.of_int 0x01)
  |> print_execute_result t;

  [%expect{|
    A:00 F:--HC BC:0000 DE:0000 HL:0000 SP:ab00 PC:0000 |}]

let%expect_test "ADD HL, BC (half carry + carry)" =
  let t = create_cpu ~h:0xFF ~l:0x00 ~b:0x01 ~c:0x00 () in

  ADD16 (RR HL, RR BC)
  |> print_execute_result t;

  [%expect{|
    A:00 F:Z-HC BC:0100 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "ADC A, 0xFF (half-carry + carry)" =
  let t = create_cpu ~a:0x1 ~carry:true () in

  ADC (R A, Immediate8 (Uint8.of_int 0xFE))
  |> print_execute_result t;

  [%expect{|
    A:00 F:Z-HC BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "INC HL" =
  let t = create_cpu ~h:0xaa ~l:0xbb () in

  INC16 (RR HL)
  |> print_execute_result t;

  [%expect{|
    A:00 F:---- BC:0000 DE:0000 HL:aabc SP:0000 PC:0000 |}]


let%expect_test "RLCA" =
  let t = create_cpu ~a:0b10000001 () in

  RLCA
  |> print_execute_result t;

  [%expect {|
    A:03 F:---C BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "RLA when c=1" =
  let t = create_cpu ~a:0b00000001 ~carry:true () in

  RLA
  |> print_execute_result t;

  [%expect {|
    A:03 F:---- BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "RLA when c=0" =
  let t = create_cpu ~a:0b00000001 ~carry:false () in

  RLA
  |> print_execute_result t;

  [%expect {|
    A:02 F:---- BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "RLA (always unset zero flag)" =
  let t = create_cpu ~a:0b10000000 ~zero:true ~carry:false () in

  RLA
  |> print_execute_result t;

  [%expect {|
    A:00 F:---C BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]


let%expect_test "RRCA" =
  let t = create_cpu ~a:0b00010001 () in

  RRCA
  |> print_execute_result t;

  [%expect {|
    A:88 F:---C BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "RRA" =
  let t = create_cpu ~a:0b00010000 ~carry:true () in

  RRA
  |> print_execute_result t;

  [%expect {|
    A:88 F:---- BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "RRA no carry" =
  let t = create_cpu ~a:0b00010000 ~carry:false () in

  RRA
  |> print_execute_result t;

  [%expect {|
    A:08 F:---- BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "RLC A" =
  let t = create_cpu ~a:0b10000001 () in

  RLC (R A)
  |> print_execute_result t;

  [%expect {|
    A:03 F:---C BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "RLC A (sets zero flag)" =
  let t = create_cpu ~a:0b00000000 () in

  RLC (R A)
  |> print_execute_result t;

  [%expect {|
    A:00 F:Z--- BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "RL A" =
  let t = create_cpu ~a:0b00000001 ~carry:true () in

  RL (R A)
  |> print_execute_result t;

  [%expect {|
    A:03 F:---- BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "RL A (sets zero flag)" =
  let t = create_cpu ~a:0b10000000 () in

  RL (R A)
  |> print_execute_result t;

  [%expect {|
    A:00 F:Z--C BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "RRC A" =
  let t = create_cpu ~a:0b00010001 () in

  RRC (R A)
  |> print_execute_result t;

  [%expect {|
    A:88 F:---C BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "RRC A (sets zero flag)" =
  let t = create_cpu ~a:0b00000000 () in

  RRC (R A)
  |> print_execute_result t;

  [%expect {|
    A:00 F:Z--- BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "RR A" =
  let t = create_cpu ~a:0b00010000 ~carry:true () in

  RR (R A)
  |> print_execute_result t;

  [%expect {|
    A:88 F:---- BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "RR A no carry" =
  let t = create_cpu ~a:0b00010000 ~carry:false () in

  RR (R A)
  |> print_execute_result t;

  [%expect {|
    A:08 F:---- BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "RR A sets zero flag" =
  let t = create_cpu ~a:0b00000001 ~carry:false () in

  RR (R A)
  |> print_execute_result t;

  [%expect {|
    A:00 F:Z--- BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "SLA" =
  let t = create_cpu ~a:0b10000001 () in

  SLA (R A)
  |> print_execute_result t;

  [%expect {|
    A:02 F:---C BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "SLA set zero flag" =
  let t = create_cpu ~a:0b10000000 () in

  SLA (R A)
  |> print_execute_result t;

  [%expect {|
    A:00 F:Z--C BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "SLA no carry" =
  let t = create_cpu ~a:0b00001000 () in

  SLA (R A)
  |> print_execute_result t;

  [%expect {|
    A:10 F:---- BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "SRA" =
  let t = create_cpu ~a:0b10000001 () in

  SRA (R A)
  |> print_execute_result t;

  [%expect {|
    A:c0 F:---C BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "SRA zero flag" =
  let t = create_cpu ~a:0b00000000 () in

  SRA (R A)
  |> print_execute_result t;

  [%expect {|
    A:00 F:Z--- BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]


let%expect_test "SRL" =
  let t = create_cpu ~a:0b10000001 () in

  SRL (R A)
  |> print_execute_result t;

  [%expect {|
    A:40 F:---C BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "BIT (0, A) when A = 0b00000001" =
  let t = create_cpu ~a:0b00000001 ~sub:true () in

  BIT (Uint8.of_int 0, R A)
  |> print_execute_result t;

  [%expect {|
    A:01 F:--H- BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "BIT (1, A) when A = 0b00100000" =
  let t = create_cpu ~a:0b00100000 ~sub:true () in

  BIT (Uint8.of_int 5, R A)
  |> print_execute_result t;

  [%expect {|
    A:20 F:--H- BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "SET (5, A) when A = 0b00000000" =
  let t = create_cpu ~a:0b00000000 () in

  SET (Uint8.of_int 5, R A)
  |> print_execute_result t;

  [%expect {|
    A:20 F:---- BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "RES (4, A) when A = 0b00010011" =
  let t = create_cpu ~a:0b00010011 () in

  RES (Uint8.of_int 4, R A)
  |> print_execute_result t;

  [%expect {|
    A:03 F:---- BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "RES (4, A) when A = 0b00000011" =
  let t = create_cpu ~a:0b00000011 () in

  RES (Uint8.of_int 4, R A)
  |> print_execute_result t;

  [%expect {|
    A:03 F:---- BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "PUSH BC" =
  let mmu = Mmu.create ~size:0x10 in
  let t = create_cpu ~b:0xBB ~c:0xCC ~sp:8 ~mmu () in

  PUSH BC
  |> print_execute_result t;

  [%expect {|
    A:00 F:---- BC:bbcc DE:0000 HL:0000 SP:0006 PC:0000 |}];

  print_addr_content mmu 0x7;
  print_addr_content mmu 0x6;
  [%expect {|
     0xbb
     0xcc|}]

let%expect_test "POP BC" =
  let mmu = Mmu.create ~size:0x10 in
  let t = create_cpu ~b:0xBB ~c:0xCC ~sp:6 ~mmu () in
  Mmu.write_byte mmu ~addr:Uint16.(of_int 0x7) ~data:Uint8.(of_int 0xBB);
  Mmu.write_byte mmu ~addr:Uint16.(of_int 0x6) ~data:Uint8.(of_int 0xCC);

  POP BC
  |> print_execute_result t;

  [%expect {|
    A:00 F:---- BC:bbcc DE:0000 HL:0000 SP:0008 PC:0000 |}]

let%expect_test "JP 0x0010" =
  let t = create_cpu  () in

  JP (None, Immediate16 Uint16.(of_int 0x0010))
  |> print_execute_result t;

  [%expect {|
    A:00 F:---- BC:0000 DE:0000 HL:0000 SP:0000 PC:0010 |}]

let%expect_test "JP NZ, 0x0010 when z=0" =
  let t = create_cpu  ~zero:false () in

  JP (NZ, Immediate16 Uint16.(of_int 0x0010))
  |> print_execute_result t;

  [%expect {|
    A:00 F:---- BC:0000 DE:0000 HL:0000 SP:0000 PC:0010 |}]

let%expect_test "JP NZ, 0x0010 when z=1" =
  let t = create_cpu  ~zero:true () in

  JP (NZ, Immediate16 Uint16.(of_int 0x0010))
  |> print_execute_result t;

  [%expect {|
    A:00 F:Z--- BC:0000 DE:0000 HL:0000 SP:0000 PC:0000 |}]

let%expect_test "JP HL" =
  let t = create_cpu ~h:0xAA ~l:0xBB  () in

  JP (None, RR HL)
  |> print_execute_result t;

  [%expect {|
    A:00 F:---- BC:0000 DE:0000 HL:aabb SP:0000 PC:aabb |}]

let%expect_test "JR 0x0c" =
  let t = create_cpu ~pc:2 () in

  JR (None, Int8.of_byte (Uint8.of_int 0x0c))
  |> print_execute_result t;

  [%expect {|
    A:00 F:---- BC:0000 DE:0000 HL:0000 SP:0000 PC:000e |}]

let%expect_test "JR C, 0x0e when c=1" =
  let t = create_cpu ~carry:true ~pc:2 () in

  JR (C, Int8.of_int 0x0c)
  |> print_execute_result t;

  [%expect {|
    A:00 F:---C BC:0000 DE:0000 HL:0000 SP:0000 PC:000e |}]

let%expect_test "JR 0xFB when pc = 0x000A" =
  let t = create_cpu ~pc:0x000A () in

  JR (None, Int8.of_int 0xFB)
  |> print_execute_result t;

  [%expect {|
    A:00 F:---- BC:0000 DE:0000 HL:0000 SP:0000 PC:0005 |}]

let%expect_test "JR NC, 0x0e when c=1" =
  let t = create_cpu ~carry:true ~pc:2 () in

  JR (NC, Int8.of_int 0x0e)
  |> print_execute_result t;

  [%expect {|
    A:00 F:---C BC:0000 DE:0000 HL:0000 SP:0000 PC:0002 |}]

let%expect_test "CALL 0x0010" =
  let mmu = Mmu.create ~size:0x10 in
  let t = create_cpu ~mmu ~pc:0xBBCC ~sp:0x8 () in

  CALL (None, Uint16.(of_int 0x0010))
  |> print_execute_result t;

  [%expect {|
    A:00 F:---- BC:0000 DE:0000 HL:0000 SP:0006 PC:0010 |}];

  print_addr_content mmu 0x7;
  print_addr_content mmu 0x6;
  [%expect {|
     0xbb
     0xcc|}]

let%expect_test "RET" =
  let mmu = Mmu.create ~size:0x10 in
  let t = create_cpu ~sp:6 ~mmu () in
  Mmu.write_byte mmu ~addr:Uint16.(of_int 0x7) ~data:Uint8.(of_int 0xBB);
  Mmu.write_byte mmu ~addr:Uint16.(of_int 0x6) ~data:Uint8.(of_int 0xCC);

  RET None
  |> print_execute_result t;

  [%expect {|
    A:00 F:---- BC:0000 DE:0000 HL:0000 SP:0008 PC:bbcc |}]

let%expect_test "RST 0x08" =
  let mmu = Mmu.create ~size:0x10 in
  let t = create_cpu ~pc:0xBBCC ~sp:8 ~mmu () in

  RST (Uint16.of_int 0x08)
  |> print_execute_result t;

  [%expect {|
    A:00 F:---- BC:0000 DE:0000 HL:0000 SP:0006 PC:0008 |}];

  print_addr_content mmu 0x7;
  print_addr_content mmu 0x6;
  [%expect {|
     0xbb
     0xcc|}]
