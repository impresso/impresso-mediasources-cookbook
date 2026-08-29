#### BEGIN OF INSTRUCTIONS FOR ChatGPT
#### UNDERSTANDING THIS TEMPLATE
#### - Text between < ... > are placeholders and should be replaced with actual values.  
#### - <ONE LINE DESCRIPTION> should be concise summary and fit one line. Keep or add : at the begin of the line where the template specifies it.
#### - <further multiline docs> can span multiple lines and should be detailed documentation (but not redundant)
#### - white-space: put always two empty lines between different things
#### - use UPPERCASE for variable names
#### - use CamelCase for make function names
#### - use kebab-case for meta-documentation such as USER-VARIABLE
#### - note that the colon after #: <ONE LINE DESCRIPTION OF FOOBAR2> is important for targets as remake --tasks reports these information as documentation for a target
#### - NEVER change the functionality of the script, improve/adapt only the comments, maybe reorder a few things to make more sense
#### - The indentation by two spaces lines starting   $(call log.debug, OS) is deliberatly made. Do not change the indentation. 
#### - Do not introduce additional separator lines.
#### -  Recommended Order for Restructuring a Makefile
####     1. User-Configurable Variables (`?=`)
####     2. Internal Computed Variables (`:=`)
####     3. Functions (`define … endef`)
####     4. Collect Phony Targets (add `.PHONY: foo bar`)
####     5. Dependency-Only Targets (No Recipe)  (add `.PHONY: foo bar`)
####     6. File Rules (`FILE-RULE`, `STAMPED-FILE-RULE`)
####     7. Custom Build Targets
####     8. Double-Colon Phony Targets (`::`) (add `.PHONY: foo bar`)
####     9. Double-Colon Targets (`::`) 
####
#### END OF INSTRUCTIONS FOR ChatGPT

BEGIN-OF-TEMPLATE
$(call log.debug, COOKBOOK BEGIN INCLUDE: cookbook/<INPUTFILE>.mk)
###############################################################################
# <SHORT_TITLE FOR INPUTFILE>
# <ONE LINE DESCRIPTION>
#
# <further multiline docs>
###############################################################################

# DOUBLE-COLON-TARGET: <FOOBAR8>
# <ONE LINE DESCRIPTION OF FOOBAR8>
#
# <further multiline docs>
<FOOBAR8> :: <DEPENDENCY1> <DEPENDENCY2>


# DOUBLE-COLON-TARGET-RULE: <FOOBAR9>
# <ONE LINE DESCRIPTION OF FOOBAR9>
#
# <further multiline docs>
<FOOBAR9> :: <DEPENDENCY1>
	<COMMANDS>


# USER-VARIABLE: <FOOBAR1>
# <ONE LINE DESCRIPTION OF FOOBAR1>
#
# <further multiline docs>
FOOBAR1 ?= <SOME DEFAULT VALUE>


# VARIABLE: <FOOBAR2>
# <ONE LINE DESCRIPTION OF FOOBAR2>
#
# <further multiline docs>
FOOBAR2 := <SOME DEFAULT VALUE>


# TARGET: <FOOBAR7>
#: <ONE LINE DESCRIPTION OF FOOBAR7>
#
# <further multiline docs>
<FOOBAR7> : <PREREQUISITS OF FOOBAR7>


# PATTERN-FILE-RULE: %.<FOOBAR3>
#: <ONE LINE DESCRIPTION OF FOOBAR3>
#
# <further multiline docs>
%.<FOOBAR3> : %.<FOOBAR3_DEPENDENCY>
	<COMMANDS>

# STAMPED-FILE-RULE: <FOOSTAMPEDFILE>
#: <ONE LINE DESCRIPTION OF FOOSTAMPEDFILE>
#
# <further multiline docs>
<FOOSTAMPEDFILE> : <FOOSTAMPEDFILE_DEPENDENCY>
	<COMMANDS>


# FUNCTION: <FooBar5>
# <ONE LINE DESCRIPTION OF FooBar5>
#
# <further multiline docs>
define FooBar5
	<COMMANDS>
endef


$(call log.debug, COOKBOOK END INCLUDE: cookbook/<INPUTFILE>.mk)
END-OF-TEMPLATE
