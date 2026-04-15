-- Test data files are Lua data/config files (e.g. WoW SavedVariables format)
-- that define top-level globals and are not executed as scripts.
files["**/tests/data/Assignments.lua"].ignore = {"111", "112"}
files["**/tests/data/WoWSavedVariables.lua"].ignore = {"111", "112"}
