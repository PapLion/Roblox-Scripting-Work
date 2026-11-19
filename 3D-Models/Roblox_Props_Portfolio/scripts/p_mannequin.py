"""Presentation-only standing R6-style mannequin (~1.52 m, same scale as the Guard),
used as the scale reference in the urban props scene.  Not exported."""
import bpy, bmesh
import lib
from lib import V

M = lib.mats()
c = lib.get_coll("Mannequin_R6_Standing")
lib.clear_coll(c)
LOC = V(4.0, 10.6, 0)
c.instance_offset = LOC
root = lib.make_root("Mannequin_R6_Standing", c, LOC)
bm = bmesh.new()
LEG_H, TOR_H, HEAD = 0.600, 0.520, 0.360
for s in (1, -1):
    lib.rounded_box(bm, V(s * 0.098, 0, LEG_H / 2), 0.094, 0.095, LEG_H / 2, 0.022, seg=2)              # legs
    lib.rounded_box(bm, V(s * 0.292, 0, LEG_H + TOR_H - 0.255), 0.088, 0.092, 0.255, 0.022, seg=2)     # arms
lib.rounded_box(bm, V(0, 0, LEG_H + TOR_H / 2), 0.200, 0.100, TOR_H / 2, 0.024, seg=2)                 # torso
lib.rounded_box(bm, V(0, 0, LEG_H + TOR_H + 0.020 + HEAD / 2), 0.165, 0.150, HEAD / 2, 0.070, seg=3)   # head
ob = lib.bm_to_obj("Mannequin_R6_Standing_Body", bm, c, M["M_Mannequin"], root)
lib.finish(ob, sharp=50)
print("mannequin height", LEG_H + TOR_H + 0.020 + HEAD)
