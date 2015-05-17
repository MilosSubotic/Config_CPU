#!/usr/bin/env julia
###############################################################################
#
# @author Milos Subotic <milos.subotic.sm@gmail.com>
# @license MIT
#
# @brief Instruction set and assembler generator.
#
###############################################################################

import Base.string

program_name = basename(@__FILE__)

function p_error(args...)
	println("$program_name: error: ", args...)
	exit(1)
end

function f_error(file_name::String, args...)
	println("$file_name: error: ", args...)
	exit(1)
end

function fl_error(file_name::String, line::Int, args...)
	println("$file_name:$line: error: ", args...)
	exit(1)
end

function string(ex::Exception)
	io = IOBuffer()
	showerror(io, ex)
	takebuf_string(io)
end

usage = "usage:
	$program_name INSTR_SET_DEFINITION.isd VHDL_PACKAGE.vhd ASSEMBLER.jl
"

if length(ARGS) < 3
	p_error(usage)
end

isd_file_name = ARGS[1]
vhdl_pack_file_name = ARGS[2]
asm_file_name = ARGS[3]


try
	f = open(abspath(isd_file_name), "r")
	close(f)
catch
	f_error(isd_file_name, "No such file or directory")
end

try
	include(abspath(isd_file_name))
catch ex
	fl_error(isd_file_name, ex.line, string(ex.error))
end

#######################################
# Parse and calculate insruction set params.


predicate_width = ceil(Int, log2(maximum(keys(predicates))+1))


function pred_code_2_string(code)
	return bits(code)[end-predicate_width+1:end]
end

predicate_table = Dict{String, UInt}()
for (code, preds) in predicates
	for p in preds
		if haskey(predicate_table, p)
			m = "predicate \"" * p * "\""
			if haskey(predicate_aliases, p)
				m *= " (" * predicate_aliases[p] * ")"
			end
			m *= " defined under two codes: 0b" * 
				pred_code_2_string(predicate_table[p]) * " and 0b" *
				pred_code_2_string(code) * ""
			f_error(isd_file_name, m)
		else
			predicate_table[p] = code
		end
	end
end




const expand_field_type = Dict(
	"d" => "dst",
	"s" => "src",
	"n" => "num",
	"a" => "addr",
)

# instruction name => opcode.
opcodes = Dict{String, UInt}()
oc = 0
# field name => field range.
fields = Dict{String, UnitRange{Int64}}()

types_expr = :(begin
	type FieldParams
		nice_field_name::String
		num_bits::UInt
		arg_pos_or_field_init::Int
		conv_fun_name::String
	end
	type ArgsParseParam
		regex::Regex
		nice_fmt::String
		fields_params::Vector{FieldParams}
	end
	type ArgsForParsing
		line_num::UInt
		instr_name::String
		opcode::UInt
		args::String
	end
end)
eval(types_expr)

args_parse_params = ArgsParseParam[]
# opcode => index to args_parse_params.
idx_args_parse_param = Dict{UInt, UInt}()

for (format, instr_names) in instructions
	pos = 0
	regex_l = ""
	regex_r = ""
	nice_fmt_l = ""
	nice_fmt_r = ""
	arg_pos_l = 1
	arg_pos_r = 101
	fields_params = FieldParams[]
	
	for field in split(format)
		m = match(r"^([dsna]?)([0-9]+)_([0-9]+)$", field)
		if m == nothing
			f_error(isd_file_name, "in instruction format \"" *
				format * "\" field \"" * field * 
				"\" is wrongly formated"
			)
		else
			short_field_type = m.captures[1]
			if short_field_type ≠ ""
				field_type = expand_field_type[short_field_type]
				field_idx = m.captures[2]
				field_name = field_type * field_idx
				len = parse(Int, m.captures[3])
				range = pos:pos+len-1
				pos += len
				if haskey(fields, field_name)
					if range ≠ fields[field_name]
						f_error(isd_file_name, "in instruction format \"" *
							format * "\" in field \"" * field * 
							"\" range " * string(range) * 
							" of field is different then range " *
							string(fields[field_name]) * 
							" defined in previous definitions"
						)
					end
				else
					fields[field_name] = range
				end

				if field_type == "dst"
					if regex_l ≠ ""
						regex_l *= ","
						nice_fmt_l *= ","
					end
					regex_l *= "%(\\d+)"
					nice_field_name = "%" * field_name
					nice_fmt_l *= nice_field_name
					
					push!(
						fields_params,
						FieldParams(
							nice_field_name,
							len,
							arg_pos_l,
							"conv_reg"
						)
					)

					arg_pos_l += 1
				else
					if regex_r ≠ ""
						regex_r *= ","
						nice_fmt_r *= ","
					end
					nice_field_name = field_name
					if field_type == "src"
						regex_r *= "%(\\d+)"
						conv_fun_name = "conv_reg"
						nice_field_name = "%" * field_name
					elseif field_type == "num"
						regex_r *= "(\\d+)"
						conv_fun_name = "conv_num"
					elseif field_type == "addr"
						regex_r *= "(\\w+)"
						conv_fun_name = "conv_addr"
					end
					nice_fmt_r *= nice_field_name

					push!(
						fields_params,
						FieldParams(
							nice_field_name,
							len,
							arg_pos_r,
							conv_fun_name
						)
					)

					arg_pos_r += 1
				end
			else
				len = parse(Int, m.captures[3])
				field_init = parse(Int, m.captures[2])
				if field_init >= 2^len
					f_error(isd_file_name, "in instruction format \"" *
						format * "\" in field \"" * field * 
						"\" is too small (" * string(len) * " bits)" *
						" for init value " * string(field_init)
					)
				end
				push!(
					fields_params,
					FieldParams(
						"init",
						len,
						-field_init,
						"conv_init"
					)
				)
				pos += len
			end
		end
	end

	regex = "^"
	nice_fmt = ""
	if regex_l ≠ ""
		regex *= regex_l * "="
		nice_fmt *= nice_fmt_l * "="
	end
	regex *= regex_r * "\$"
	nice_fmt *= nice_fmt_r

	for field_params in fields_params
		if field_params.arg_pos_or_field_init >= 101
			# Correct rvalue arg_pos
			field_params.arg_pos_or_field_init += -101 + arg_pos_l
		end
	end
	push!(
		args_parse_params,
		ArgsParseParam(Regex(regex), nice_fmt, fields_params)
	)

	for instr_name in instr_names
		if match(r"^([a-z][a-z0-9_]*)$", instr_name) == nothing
			f_error(isd_file_name, "instruction name \"" * instr_name *
				"\" is wrongly formated"
			)
		end
		opcodes[instr_name] = oc
		idx_args_parse_param[oc] = length(args_parse_params)
		oc += 1
	end

end

opcodes_num = oc
opcode_width = ceil(Int, log2(opcodes_num+1))

function opcode_2_string(opcode)
	return bits(opcode)[end-opcode_width+1:end]
end


max_left = maximum(map((range) -> range.stop, values(fields)))
instruction_width = predicate_width + opcode_width + max_left + 1
instruction_range = 0:instruction_width-1

predicate_range = instruction_width-predicate_width:instruction_width-1

opcode_range = predicate_range.start-opcode_width:predicate_range.start-1

fields_start = opcode_range.start-1
for (field_name, range) in fields
	fields[field_name] = fields_start-range.stop:fields_start-range.start
end


#######################################
# Generate instruction set VHDL package.

f = try
	open(vhdl_pack_file_name, "w")
catch ex
	if ex.errnum == 2
		f_error(vhdl_pack_file_name, "No such file or directory")
	elseif ex.errnum == 13
		f_error(vhdl_pack_file_name, "Permission denied")
	end
end
try
	write(f, 
"-- Do NOT edit this file, it's generated by $program_name script.

library  ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package instruction_set is
")



	write(f, "
	-- Instruction fields.
")


	function subtype(name, range, type_)
		write(
			f, 
			@sprintf(
				"	subtype t_%-11s is %16s(%2d downto %2d);\n",
				name,
				type_,
				range.stop,
				range.start
			)
		)
	end
	subtype("instruction", instruction_range, "std_logic_vector")
	subtype("predicate", predicate_range, "std_logic_vector")
	subtype("opcode", opcode_range, "std_logic_vector")
	for (field_name, range) in fields
		subtype(field_name, range, "unsigned")
	end



	write(f, "
	-- Predicate codings.
")
	for (pred, code) in predicate_table
		pc = pred_code_2_string(code)
		if pred ≠ ""
			write(
				f, 
				@sprintf(
					"	constant P_%-20s : t_predicate := \"%s\";\n",
					uppercase(pred),
					pc
				)
			)
		end
		if haskey(predicate_aliases, pred)
			p = uppercase(predicate_aliases[pred])
			p = replace(p, " ", (s) -> "_")
			p = replace(p, "-", (s) -> "_")
			write(
				f, 
				@sprintf(
					"	constant P_%-20s : t_predicate := \"%s\";\n",
					p,
					pc
				)
			)
		end
	end

	write(f, "
	-- Operation codes.
")
	for (instr_name, opcode) in opcodes
		write(
			f, 
			@sprintf(
				"	constant OC_%-19s : t_opcode := \"%s\";\n",
				uppercase(instr_name),
				opcode_2_string(opcode)
			)
		)
	end


	write(f, "
end package instruction_set;

")

catch ex
	close(f)
	p_error("while writing to $asm_file_name: ", string(ex))
finally
	close(f)
end

#######################################
# Assembler code.

asm_defs = """

registers_number=$registers_number
predicate_table = $predicate_table
opcodes = $opcodes
predicate_width = $predicate_width
opcode_width = $opcode_width
instruction_width = $instruction_width
args_parse_params = $args_parse_params
idx_args_parse_param = $idx_args_parse_param


macro error(args...)
	quote
		println(input_file_name, ':', line_num, \": error: \", \$args...)
	end
end
macro note(args...)
	quote
		println(input_file_name, ':', line_num, \": note: \", \$args...)
	end
end

"""

asm_code = :( begin
	program_name = basename(@__FILE__)

	function p_error(args...)
		println("$program_name: error: ", args...)
		exit(1)
	end

	function f_error(file_name::String, args...)
		println("$file_name: error: ", args...)
		exit(1)
	end

	function fl_error(file_name::String, line::Int, args...)
		println("$file_name:$line: error: ", args...)
		exit(1)
	end

	function Base.string(ex::Exception)
		io = IOBuffer()
		showerror(io, ex)
		takebuf_string(io)
	end

	usage = "usage:
		$program_name INPUT_ASM_FILE.asm OUTPUT_ROM_FILE.vhd
	"

	if length(ARGS) < 2
		p_error(usage)
	end

	input_file_name = ARGS[1]
	output_file_name = ARGS[2]


	function pred_code_2_string(code)
		return bits(code)[end-predicate_width+1:end]
	end

	function opcode_2_string(opcode)
		return bits(opcode)[end-opcode_width+1:end]
	end

	conv_funs = Dict{String, Function}(
		"conv_reg" => function(line_num, num_bits, arg, nice_field_name)
			u = parse(UInt, arg)
			if u >= registers_number
				@error("asdf conv_reg 1")
			end
			if u >= 2^num_bits
				@error("asdf conv_reg 2")
			end
			return bits(u)[end-num_bits+1:end]
		end,
		"conv_num" => function(line_num, num_bits, arg, nice_field_name)
			i = parse(Int, arg)
			if i >= 0
				if i >= 2^num_bits
					@error("asdf conv_num 1")
				end
			else
				if -i > 2^(num_bits-1)
					@error("asdf conv_num 2")
				end
			end
			return bits(i)[end-num_bits+1:end]
		end,
		"conv_addr" => function(line_num, num_bits, arg, nice_field_name)
			label = arg
			if !haskey(label_to_addr, label)
				@error("asdf conv_label 1")
			else
				addr = label_to_addr[label]
			end
			if addr >= 2^num_bits
				@error("asdf conv_label 2")
			end
			return bits(addr)[end-num_bits+1:end]
		end,
		"conv_init" => function(line_num, num_bits, field_init)
			# Check if field_init value could fit to field is done
			# while parsing ISD file.
			return bits(field_init)[end-num_bits+1:end]
		end
	)


	label_to_addr = Dict{String, UInt}()
	label_to_line_num = Dict{String, UInt}()
	addr = 0
	# In bits.
	machine_code = String[]
	args_for_parsing = ArgsForParsing[]

	f = try
		open(input_file_name, "r")
	catch ex
		if ex.errnum == 2
			f_error(input_file_name, "No such file or directory")
		elseif ex.errnum == 13
			f_error(input_file_name, "Permission denied")
		end
	end
	try
		# Read input asm file.
		
		line_reg = r"^((\w+):)?(\s*(\((\w+)\)\s+)?(\w+)(\s+([=,%\w]+))?)?\s*(//\s*(.*)\s*)?$"
		for (line_num, line) in enumerate(readlines(f))

			m = match(line_reg, line)
			if m == nothing
				@error("cannot parse line")
				@note("assembler line format is: \"[label:] [[(pred)] instr_name [args] [// comments]]\"")
				close(f)
				exit(1)
			else
				label = m.captures[2]
				predicate = m.captures[5]
				instr_name = m.captures[6]
				args = m.captures[8]
				comment = m.captures[10]

				if label ≠ nothing
					if haskey(label_to_line_num, label)
						@error("duplicated label \"$label\"")
						@note("already exists on line ", label_to_line_num[label])
						close(f)
						exit(1)
					else
						label_to_line_num[label] = line_num
						label_to_addr[label] = addr
					end	
				end

				if instr_name ≠ nothing
					if predicate ≠ nothing
						if !haskey(predicate_table, predicate)
							@error("non-existing predicate \"$predicate\"")
							close(f)
							exit(1)
						else
							pred_code = predicate_table[predicate]
						end
					else
						pred_code = predicate_table[""]
					end

					if !haskey(opcodes, instr_name)
						@error("non-existing instruction \"$instr_name\"")
						close(f)
						exit(1)
					else
						opcode = opcodes[instr_name]
					end

					instr_part = pred_code_2_string(pred_code) *
						opcode_2_string(opcode)
					push!(machine_code, instr_part)
					push!(
						args_for_parsing,
						ArgsForParsing(line_num, instr_name, opcode, args)
					)

					addr += 1
				end

			end
		end

	catch ex
		close(f)
		p_error("while reading to $input_file_name: ", string(ex))
	finally
		close(f)
	end

	if length(machine_code) == 0
		f_error(input_file_name, "cannot have 0 insructions")
	end

	for (i, a) in enumerate(args_for_parsing)
		line_num = a.line_num

		idx = idx_args_parse_param[a.opcode]
		p = args_parse_params[idx]

		m = match(p.regex, a.args)
		if m == nothing
			@error("wrong insruction arguments")
			@note("format for instruction \"$(a.instr_name)\" is \"$(p.nice_fmt)\"")
			close(f)
			exit(1)
		else
			args_bits = ""
			for fp in p.fields_params
				conv_fun = conv_funs[fp.conv_fun_name]
				if fp.arg_pos_or_field_init > 0
					arg_pos = fp.arg_pos_or_field_init
					arg = m.captures[arg_pos]
					arg_bits = conv_fun(
						line_num,
						fp.num_bits,
						arg,
						fp.nice_field_name
					)
				else
					field_init = fp.arg_pos_or_field_init
					field_init = -fp.arg_pos_or_field_init
					arg_bits = conv_fun(
						line_num,
						fp.num_bits,
						field_init
					)
				end
				args_bits *= arg_bits
			end
		end

		instr = machine_code[i] * args_bits
		machine_code[i] = instr * "0"^(instruction_width - length(instr))
	end


	f = try
		open(output_file_name, "w")
	catch ex
		if ex.errnum == 2
			f_error(output_file_name, "No such file or directory")
		elseif ex.errnum == 13
			f_error(output_file_name, "Permission denied")
		end
	end
	try
		# Write output VHDL ROM file.

		p = input_file_name
		p = replace(p, " ", (s) -> "_")
		p = replace(p, "-", (s) -> "_")
		p = replace(p, ".", (s) -> "_")
		p = replace(p, "/", (s) -> "_")
		arch_name = "arch_" * p

		instr_num = length(machine_code)

		write(f, 
"-- Do NOT edit this file, it's generated by $program_name script.

library  ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.instruction_set.all;
use work.instruction_rom;

architecture $arch_name of instruction_rom is

	type t_instructions is array (0 to $(instr_num-1)) of t_instruction;
	constant rom : t_instructions := (
")


		for instr in machine_code[1:end-1]
			println(f, "\t\t\"", instr, "\",")
		end
		println(f, "\t\t\"", machine_code[end], "\"")


		write(f, 
"	);
begin

	o_instruction <= rom(to_integer(i_addr));

end architecture $arch_name;

")


	catch ex
		close(f)
		p_error("while writing to $output_file_name: ", string(ex))
	finally
		close(f)
	end


end)

#######################################
# Generate assembler.

f = try
	open(asm_file_name, "w")
catch ex
	if ex.errnum == 2
		f_error(asm_file_name, "No such file or directory")
	elseif ex.errnum == 13
		f_error(asm_file_name, "Permission denied")
	end
end
try

	write(f, 
"#!/usr/bin/env julia
# Do NOT edit this file, it's generated by $program_name script.

")
	
	println(f, types_expr)

	write(f, asm_defs)

	println(f, asm_code)


catch ex
	close(f)
	p_error("while writing to $asm_file_name: ", string(ex))
finally
	close(f)
end
chmod(asm_file_name, 0o755)


###############################################################################

