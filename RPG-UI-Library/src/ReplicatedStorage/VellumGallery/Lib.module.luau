--!strict
-- Resolves the component library folder (ReplicatedStorage.Vellum, or a fresh copy in Edit-mode preview).
local RS = game:GetService("ReplicatedStorage")
local name = script.Parent:GetAttribute("LibraryName") or "Vellum"
return RS:WaitForChild(name)
