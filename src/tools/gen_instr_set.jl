#!/usr/bin/env julia
###############################################################################
#
# @author Milos Subotic <milos.subotic.sm@gmail.com>
# @license MIT
#
# @brief Generate instruction set.
#
###############################################################################


function print_and_exit(args...)
	println(args...)
	exit(1)
end

usage = "Usage:
	gen_instr_set.jl INSTR_SET_DEFINITION.isd VHDL_PACKAGE.vhd ASSEMBLER.jl
"

if length(ARGS) < 3
	print_and_exit(usage)
end

isd_file_name = ARGS[1]
vhdl_pack_file_name = ARGS[2]
asm_file_name = ARGS[3]

include(abspath(isd_file_name))

predicate_width = ceil(Int, log2(maximum(keys(predicates))+1))
@show predicate_width


# Key is instruction name, value is opcode.
opcodes = Dict{String, UInt}()
oc = 0
for instr_names in values(instructions)
	for instr_name in instr_names
		if match(r"^([a-z][a-z0-9_]*)$", instr_name) == nothing
			error("gen_instr_set.jl: instruction name \"" * instr_name *
				"\" is wrongly formated!"
			)
		end
		opcodes[instr_name] = oc
		oc += 1
	end
end

opcodes_num = oc
opcode_width = ceil(Int, log2(opcodes_num+1))
@show opcodes_num
@show opcode_width

function opcode_2_string(opcode)
	return bits(opcode)[end-opcode_width+1:end]
end



function pred_code_2_string(code)
	return bits(code)[end-predicate_width+1:end]
end

predicate_table = Dict{String, UInt}()
for (code, preds) in predicates
	for p in preds
		if haskey(predicate_table, p)
			m = "gen_instr_set.jl: predicate \"" * p * "\""
			if haskey(predicate_aliases, p)
				m *= " (" * predicate_aliases[p] * ")"
			end
			m *= " defined under two codes: 0b" * 
				pred_code_2_string(predicate_table[p]) * " and 0b" *
				pred_code_2_string(code) * "!"
			error(m)
		else
			predicate_table[p] = code
		end
	end
end




exp_field_type = Dict(
	"d" => "dst",
	"s" => "src",
	"c" => "const",
	"l" => "addr",
)

fields = Dict{String, UnitRange{Int64}}()
for format in keys(instructions)
	pos = 0
	for field in split(format)
		m = match(r"^([dscl]?)([0-9]+)_([0-9]+)$", field)
		if m == nothing
			error("gen_instr_set.jl: in instruction format \"" *
				format * "\" field \"" * field * 
				"\" is wrongly formated!"
			)
		else
			t = m.captures[1]
			if t ≠ ""
				field_name = exp_field_type[t] * m.captures[2]
				len = parse(Int, m.captures[3])
				range = pos:pos+len-1
				pos += len
				if haskey(fields, field_name)
					if range ≠ fields[field_name]
						error("gen_instr_set.jl: in instruction format \"" *
							format * "\" in field \"" * field * 
							"\" range " * string(range) * 
							" of field is different then range " *
							string(fields[field_name]) * 
							" defined in previous definitions!"
						)
					end
				else
					fields[field_name] = range
				end
			else
				# TODO Meaningless fields.
				len = parse(Int, m.captures[3])
				pos += len
			end
		end
	end
end

max_left = maximum(map((range) -> range.stop, values(fields)))
@show max_left
instruction_width = predicate_width + opcode_width + max_left + 1
@show instruction_width
instruction_range = 0:instruction_width-1
@show instruction_range

predicate_range = instruction_width-predicate_width:instruction_width-1
@show predicate_range

opcode_range = predicate_range.start-opcode_width:predicate_range.start-1
@show opcode_range

fields_start = opcode_range.start-1
for (field_name, range) in fields
	fields[field_name] = fields_start-range.stop:fields_start-range.start
end


open(vhdl_pack_file_name, "w") do f
	write(f, "
-- Do NOT edit this file, generated by gen_instr_set.jl script.
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
		p = uppercase(get(predicate_aliases, pred, pred))
		p = replace(p, " ", (s) -> "_")
		p = replace(p, "-", (s) -> "_")
		write(
			f, 
			@sprintf(
				"	constant P_%-20s : t_predicate := \"%s\";\n",
				p,
				pred_code_2_string(code)
			)
		)
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

end



###############################################################################

