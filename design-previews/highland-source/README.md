# Highland pairing artwork — design preview

These are design mockups, not iOS screenshots or released app assets.

Source: RBLXSupercars, shared by brandonleong28, **2024 Tesla Model 3**, CC BY 4.0. See SOURCE-CREDITS.md for provenance and license links. The source artist URL is reported unavailable upstream; the public copy retains attribution metadata. This is an artist model, not Tesla CAD.

Downloaded source SHA-256: 6ef6933d93ee0812d4049446a38e9b46273cab03b21be1e2ef1d502eccdb684b.

Changes: Blender orthographic top projection, opaque material override for contour extraction, selected major contours, joined small contour gaps, mirrored selected contours for symmetry, omitted wipers/interior/mirrors, monochrome SVG styling. The SVG is derived artwork, not an original SVG provided by the model author.

- light.png / dark.png: welcome-page mockups at 430 × 932 points, 2× export.
- highland-projected.svg: derived vector artwork.
- model-top-reference.png: original-model top render for comparison.
- projected-strokes.jsonl: Blender Freestyle projection coordinates used to build the vector.

Rebuild with Python 3, CairoSVG and Noto Sans CJK SC installed:

```sh
python3 clean-projection.py
python3 build-preview.py
```

Typography and status-bar symbols are illustrative. No SwiftUI source or production asset has been changed.

## Headlight revision

Lamp shell and DRL are now separately traced from the user-provided red-car close-up. The small step belongs to the internal DRL, not the shell. The traced detail is fitted to the top-view illustration and mirrored. It is a stylized perspective adaptation, not a measured orthographic reconstruction. The supplied photograph is not redistributed in this folder.
