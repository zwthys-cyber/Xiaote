import json,math,pathlib
s=[json.loads(l) for l in open(pathlib.Path(__file__).with_name('projected-strokes.jsonl'))]
def mirror(p):return [(860-x,y) for x,y in p]
def path(p,width=1,opacity=1):
 # Preserve projected vertices; only join gaps between selected model contours.
 d='M'+' L'.join(f'{x/2:.2f},{(1220-y)/2:.2f}' for x,y in p)
 return f'<path d="{d}" stroke-width="{width}" opacity="{opacity}"/>'
hood=list(reversed(s[240]))+mirror(s[240])
# Two nested windshield contours, following the supplied welcome-screen reference.
# Both lower arcs are symmetric about x=215 and remain separate from the hood.
glass_outer = "M 68,-14 C 60,57 51,134 44,189 C 45,213 49,241 54,265 C 101,291 158,308 215,308 C 272,308 329,291 376,265 C 381,241 385,213 386,189 C 379,134 370,57 362,-14"
glass_inner = "M 81,-14 C 70,66 62,144 58,187 C 57,207 58,226 62,239 C 107,265 162,281 215,281 C 268,281 323,265 368,239 C 372,226 373,207 372,187 C 368,144 360,66 349,-14"
roof_edge = "M 80,-7 C 116,3 171,9 215,9 C 259,9 314,3 350,-7"
glass_art = ''.join(f'<path d="{d}" stroke-width="1.2" opacity="0.58"/>' for d in (glass_outer,glass_inner,roof_edge))
# Lamp shell and DRL traced separately from the user's close-up photograph.
# Coordinates below refer to the 1800 x 1368 reference, not factory CAD.
shell = "M 460,980 C 488,926 532,845 571,797 C 622,733 775,663 945,574 C 1109,489 1209,409 1275,325 C 1280,398 1274,507 1251,578 C 1225,660 1138,718 1030,769 C 865,850 639,929 460,980 Z"
drl = "M 568,852 C 681,817 831,775 957,731 C 988,721 1006,720 1030,731 C 1118,690 1196,637 1226,581 C 1250,535 1255,452 1257,382"
def lamp_group():
 # Fit the photographed detail into the projected body's right front corner.
 # This is a stylized view adaptation, not an exact perspective reconstruction.
 return ('<g transform="matrix(0.105 0 0 0.165 269 344)">'
         f'<path d="{shell}" stroke-width="9"/>'
         f'<path d="{drl}" stroke-width="12"/>'
         '</g>')
lamps=lamp_group()+'<g transform="translate(430 0) scale(-1 1)">'+lamp_group()+'</g>'
# Refined continuous front silhouette. Mirrored Bezier handles keep the
# shoulder-to-lip transition tangent-continuous and flatten the center gently.
# This is a design refinement of the projected outline, not factory geometry.
front_outline = (
    "M 13,-20 "
    "C 14,70 18,161 16,231 "
    "C 14,301 8,350 11,400 "
    "C 12.5,425 17,443 34,463 "
    "C 51,483 83,510 116,525 "
    "C 149,540 178,543 215,543 "
    "C 252,543 281,540 314,525 "
    "C 347,510 379,483 396,463 "
    "C 413,443 417.5,425 419,400 "
    "C 422,350 416,301 414,231 "
    "C 412,161 416,70 417,-20"
)
# Mirrors sit beside the base of the windshield. Their outer ends are
# intentionally cropped by the same viewport as the enlarged vehicle.
mirror_shell = (
    "M 10,229 C 3,224 -10,216 -22,215 "
    "C -28,214.5 -31,217 -30,221 "
    "C -28,227 -18,235 -7,240 "
    "C 0,243 6,244 9,242 C 11,240 12,233 10,229 Z"
)
# Short tapered mounting arm, distinct from the aerodynamic shell.
mirror_stem = "M 10,234 C 13,237 15,240 16,242 M 9,241 C 12,244 14,246 15.7,247"
# A restrained lower seam adds shell depth without a second full outline.
mirror_seam = "M -25,223 C -16,232 -4,238 5,239"
mirror_left = (f'<g stroke-width="1.2" opacity="0.8"><path d="{mirror_shell}"/>'
               f'<path d="{mirror_stem}"/><path d="{mirror_seam}" stroke-width="0.7" opacity="0.5"/></g>')
mirrors = mirror_left+'<g transform="translate(430 0) scale(-1 1)">'+mirror_left+'</g>'
front_art=f'<path d="{front_outline}" stroke-width="1.4"/>'
# Use the emblem contours already present in the attributed source model.
# Scale around its projected center to keep the hood badge understated.
emblem_paths = ''.join(path(s[i],0.85,1) for i in (470,471,473,474,476,477,478))
emblem = '<g transform="translate(215 508) scale(0.72) translate(-215 -510)" opacity="0.9">'+emblem_paths+'</g>'
art='<g fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round">'+glass_art+path(hood,1.2,.65)+front_art+mirrors+lamps+emblem+'</g>'
pathlib.Path(__file__).with_name('clean-art.txt').write_text(art)
