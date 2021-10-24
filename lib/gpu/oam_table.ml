open Uints

type sprite = {
  y_pos : int;
  x_pos : int;
  tile_index : uint8;
  priority : [`Sprite_top | `Sprite_bottom];
  y_flip : bool;
  x_flip : bool;
  pallete : [`OBP0 | `OBP1];
} [@@deriving show]

type t = {
  oam_ram : Ram.t;
  start_addr : uint16;
  end_addr : uint16;
}

let create ~start_addr ~end_addr ~oam_ram = { start_addr; end_addr; oam_ram; }

let read_byte t = Ram.read_byte t.oam_ram

let write_byte t = Ram.write_byte t.oam_ram

let accepts t = Ram.accepts t.oam_ram

let get_sprite t ~index =
  let offset = (Uint16.to_int t.start_addr) + (index * 4) in
  let y_pos =
    offset
    |> Uint16.of_int
    |> Ram.read_byte t.oam_ram
    |> Uint8.to_int
    |> (fun y -> y - 16)
  in
  let x_pos =
    (offset + 1)
    |> Uint16.of_int
    |> Ram.read_byte t.oam_ram
    |> Uint8.to_int
    |> (fun x -> x - 8)
  in
  let tile_index =
    (offset + 2)
    |> Uint16.of_int
    |> Ram.read_byte t.oam_ram
  in
  let (b7, y_flip, x_flip, b4, _, _, _, _) =
    (offset + 3)
    |> Uint16.of_int
    |> Ram.read_byte t.oam_ram
    |> Bit_util.bitflags_of_byte
  in
  let priority = if b7 then `Sprite_bottom else `Sprite_top in
  let pallete = if b4 then `OBP1 else `OBP0 in
  {
    y_pos;
    x_pos;
    tile_index;
    priority;
    y_flip;
    x_flip;
    pallete;
  }

(* TODO: Optimize *)
let sprite_indexes = List.init 40 (fun i -> i)
let get_all_sprites t =
  sprite_indexes
  |> List.map (fun index -> get_sprite t ~index)

let write_with_offset t ~offset ~data =
  Ram.write_byte t.oam_ram ~addr:Uint16.(t.start_addr + of_int offset) ~data
