module T =
struct
  type t = DirTree.t
  type label = DirTree.t
  let edges = Hashtbl.create 97
  let children t = 
    let l = DirTree.children t in
    List.iter (fun i -> Hashtbl.replace edges (DirTree.id t, DirTree.id i) ()) l;
    l
  let label x = x
  let string_of_label x = DirTree.string_of_label (DirTree.label x)
end
  
module HT = Htree.Make(T)

type drag_box = 
    { db_rect : GnoCanvas.rect;
      mutable db_x : float;
      mutable db_y : float;
      db_w : float;
      db_h : float;
    }
      
let drag_boxes = Hashtbl.create 97
let lines = Hashtbl.create 97

let show_tree canvas t width height =
  let rlimit = 0.98 in
  let xzoom = float(width)/.2.0
  and yzoom = float(height)/.2.0 in
  let origin = ref (-0.5,0.0) in
  let xy2gtk x y = float x -. 300., float(height)/.2. -. float y +. 50. in
  let gtk2xy gx gy = truncate (gx +. 300.), truncate ((float height)/.2. +. 50. -. gy) in
  let xy2c (x, y) =
    let zx = (float(x) -. xzoom)/.xzoom
    and zy = (float(y) -. yzoom)/.yzoom in
    let zn = sqrt(zx*.zx +. zy*.zy) in
    if zn > rlimit then
      (rlimit*.zx/.zn, rlimit*.zy/.zn)
    else
      (zx, zy)
  in
  let draw_edges () =
    let draw_edge (i,j) () = 
      try
	let dbi = Hashtbl.find drag_boxes i in
	let dbj = Hashtbl.find drag_boxes j in
	let l =
	  try
	    Hashtbl.find lines (i,j)
	  with Not_found-> 
	    let l = GnoCanvas.line canvas ~props:[ `FILL_COLOR "black" ;`WIDTH_PIXELS 1; `SMOOTH true]  in
	    Hashtbl.add lines (i,j) l;
	    l
	in
	let p = [| dbi.db_x; dbi.db_y; dbj.db_x; dbj.db_y |] in
	l#set [`POINTS p]
      with Not_found -> 
	()
    in
    Hashtbl.iter draw_edge T.edges
  in
  let rec draw_label lab (zx,zy) facteur_reduction = 
    let x = truncate (zx*.xzoom +. xzoom)
    and y = truncate (zy*.yzoom +. yzoom) in
    let name = T.string_of_label lab in
    let (w,h) = (40,15) in
    let x0 = x - w/2
    and y0 = y - h/2 in
    let fx,fy = xy2gtk x0 y0 in
    try
      let db = Hashtbl.find drag_boxes (DirTree.id lab) in
      db.db_x <- fx;
      db.db_y <- fy;
      db.db_rect#set [ `X1 fx; `Y1 fy; `X2 (fx +. db.db_w) ; `Y2 (fy +. db.db_h) ]
      (*db#set [ `X (fx -. 2.) ; `Y (fy +. float h -. 5.) ]*)
    with Not_found ->
      let rect = 
	GnoCanvas.rect 
	  ~props:[ `X1 fx; `Y1 fy; `X2 (fx +. float w) ; `Y2 (fy +. float h) ;
		   `FILL_COLOR "blue" ; `OUTLINE_COLOR "black" ; `WIDTH_PIXELS 0 ] canvas 
	(*GnoCanvas.text	~props:[ `X (fx+.20.) ; `Y fy; `TEXT name;  `FILL_COLOR "white"] canvas*)
      in
      let db = { db_rect = rect; db_x = fx; db_y = fy; db_w = float w; db_h = float h } in
      Hashtbl.add drag_boxes (DirTree.id lab) db;
      let sigs = rect#connect in
      let _ = sigs#event (drag_label db) in
      () 
  and draw_drv = 
    { HT.rlimit = rlimit ;
      HT.moveto = (fun _ -> ());
      HT.lineto = (fun _ -> ());
      HT.curveto = (fun _ _ _ -> ());
      HT.draw_label = draw_label ;
      HT.init_edge_pass = (fun () -> ());
      HT.init_label_pass = (fun () -> ());
      HT.finalize = (fun () -> ())
    } 
  and draw_linear_tree t c f = 
    (* mettre toutes les boites � faux *)
    HT.draw_linear_tree draw_drv t c f;
    (* d�truire toutes les boites rest�es � faux et les aretes correspondantes *)
    draw_edges ()
  and drag_label db ev =
    let item = db.db_rect in
    begin match ev with
      | `ENTER_NOTIFY _ ->
	  item#set [ `FILL_COLOR "red" ]
      | `LEAVE_NOTIFY ev ->
	  let state = GdkEvent.Crossing.state ev in
	  if not (Gdk.Convert.test_modifier `BUTTON1 state)
	  then item#set [ `FILL_COLOR "white" ; ]
      | `BUTTON_PRESS ev ->
	  let curs = Gdk.Cursor.create `FLEUR in
	  item#grab [`POINTER_MOTION; `BUTTON_RELEASE] curs 
	    (GdkEvent.Button.time ev)
      | `BUTTON_RELEASE ev ->
	  item#ungrab (GdkEvent.Button.time ev)
      | `MOTION_NOTIFY ev ->
	  let state = GdkEvent.Motion.state ev in
	  if Gdk.Convert.test_modifier `BUTTON1 state then 
	    begin
	      let z1 = xy2c (gtk2xy db.db_x db.db_y) in
	      let mx = GdkEvent.Motion.x ev in
	      let my = GdkEvent.Motion.y ev in
	      let z2 = xy2c (gtk2xy mx my) in
	      item#set [`X1 mx; `Y1 my; `X2 (mx+.db.db_w);  `Y2 (my+.db.db_h)];
	      db.db_x <- mx;
	      db.db_y <- my;
	      origin := HT.drag_origin !origin z1 z2;
	      draw_linear_tree t !origin 0.0
	    end
      | _ ->
	  ()
    end;
    false
  in
  draw_linear_tree t !origin 0.0
