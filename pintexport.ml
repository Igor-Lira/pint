
open PintTypes;;
open AutomataNetwork;;
open An_export;;

let languages = ["dump";"nusmv";"pep";"ph";"prism";"romeo"]
and opt_language = ref "dump"
and opt_output = ref ""
and opt_ptnet_context = ref false
and opt_goal = ref ""
and opt_partial = ref ""
and opt_simplify = ref false
and opt_squeeze = ref false
and opt_mapfile = ref ""

let cmdopts = An_cli.common_cmdopts @ An_cli.input_cmdopts @ [
		("-l", Arg.Symbol (languages, (fun l -> opt_language := l)), 
			"\tOutput language (default: dump)");
		("-o", Arg.Set_string opt_output, "<filename>\tOutput filename");
		("--contextual-ptnet", Arg.Set opt_ptnet_context,
			"\tContextual petri net (used by: pep)");
		("--mapfile", Arg.Set_string opt_mapfile,
			"\tOutput mapping of identifiers (used by: pep, romeo)");
		("--partial", Arg.Set_string opt_partial,
			"a,b,..\tConsider only the sub-network composed of a, b, ..");
		("--reduce-for-goal", Arg.Set_string opt_goal,
			"\"a\"=i\tBefore exportation, reduce the model to include only transitions that may "
			^ "be involved in the reachability of the given local state");
		("--simplify", Arg.Set opt_simplify,
			"\tTry to simplify transition conditions of the automata network");
		("--squeeze", Arg.Set opt_squeeze,
			"\tRemove unused automata and local states");
	]
and usage_msg = "pint-export"

let args, abort = An_cli.parse cmdopts usage_msg

let _ = if args <> [] || !opt_language = "" then (abort ())

let opts = {
	contextual_ptnet = !opt_ptnet_context;
}
let languages = [
	("dump", dump_of_an);
	("pep", pep_of_an opts ~mapfile:!opt_mapfile);
	("nusmv", nusmv_of_an);
	("ph", ph_of_an);
	("prism", prism_of_an);
	("romeo", romeo_of_an ~map:None ~mapfile:!opt_mapfile);
]
let translator = List.assoc !opt_language languages

let an, ctx = An_cli.process_input ()

let an, ctx = if !opt_partial = "" then an, ctx else
	let spec = "{"^(!opt_partial)^"}"
	in
	let aset = An_input.parse_string An_parser.automata_set spec
	in
	SSet.iter (fun a -> if not(Hashtbl.mem an.automata a) then
					failwith ("Unknown automaton '"^a^"'")) aset;
	let an = partial an aset
	and ctx = SMap.filter (fun a _ -> SSet.mem a aset) ctx
	in
	an, ctx

let an =
	if !opt_goal <> "" then
		let goal = [An_cli.parse_local_state an !opt_goal]
		in
		let env = An_reach.init_env an ctx goal
		in
		An_reach.reduced_an env
	else an

let an, ctx = if !opt_squeeze then squeeze an ctx else (an, ctx)

let an = if !opt_simplify then simplify an else an

let data = translator an ctx

let channel_out = if !opt_output = "" then stdout else open_out !opt_output

let _ =
	output_string channel_out data;
	close_out channel_out

