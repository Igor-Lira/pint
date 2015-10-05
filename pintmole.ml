
open PintTypes
open AutomataNetwork
open An_export

let usage_msg = "pint-mole [opts] <local state> -- [mole opts]"
	^" # unfolding with mole [http://www.lsv.ens-cachan.fr/~schwoon/tools/mole]"

let opt_extra = ref []

let cmdopts = An_cli.common_cmdopts @ An_cli.input_cmdopts @ [
	("--", Arg.Rest (fun arg -> opt_extra := !opt_extra @ [arg]),
		"Extra options for mole");
]

let args, abort = An_cli.parse cmdopts usage_msg

let an, ctx = An_cli.process_input ()

let goal = match args with
	  [str_ls] -> [An_cli.parse_local_state an str_ls]
	| _ -> abort ()

let conds = List.fold_left (fun conds (a,i) -> SMap.add a i conds) SMap.empty goal

let opts = {
	contextual_ptnet = false;
}
let data = pep_of_an opts ~goal:(Some (conds, "GOAL")) an ctx

let netfile, netfile_out = Filename.open_temp_file "pint" ".ll"

let mcifile = Filename.temp_file "pint" ".mci"

let _ = output_string netfile_out data;
		close_out netfile_out

let _ =
	let cmdline = "mole -T GOAL"
		^" "^String.concat " " !opt_extra
		^" "^netfile
		^" -m "^mcifile
	in
	prerr_endline ("# "^cmdline);
	match Unix.system cmdline with
	  Unix.WEXITED 2 -> print_endline (string_of_ternary True)
	| Unix.WEXITED 0 -> print_endline (string_of_ternary False)
	| _ -> prerr_endline "Error."

let _ =
	Unix.unlink netfile;
	Unix.unlink mcifile

