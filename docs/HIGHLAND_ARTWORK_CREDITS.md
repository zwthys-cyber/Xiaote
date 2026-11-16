# 2024 Tesla Model 3 Highland

This document preserves upstream model credits and describes the Xiaote line-art adaptation. The full 3D asset pipeline described below belongs to the upstream reference project, not this repository's iOS build. Current Xiaote documentation is indexed in [docs/README.md](README.md).

- Artist embedded in the source asset: [RBLXSupercars](https://sketchfab.com/RBLXSupercars).
- Download-page uploader: [brandonleong28](https://sketchfab.com/3d-models/tesla-model-3-2024-36c52f3f89f6439c90310f14e8ff33f2).
- Original source embedded in the GLB: https://sketchfab.com/3d-models/2024-tesla-model-3-fd22be415215453693d67e33aa7812d0
- License embedded in the GLB: [Creative Commons Attribution 4.0 International](https://creativecommons.org/licenses/by/4.0/).
- Downloaded from the credited public copy in [erictfree/Carbon-Footprint-AI-Visualizer](https://github.com/erictfree/Carbon-Footprint-AI-Visualizer/tree/af4bef33ca371b24c1f043486f09a13571f4919b/models/tesla-model-3-2024).

The embedded source URL was reported unavailable by that repository. Both the embedded artist and the download-page uploader are credited here. Attribution metadata is preserved in `model.glb` and `manifest.json`.

Tesla Studio changes: lossless mesh compression; externalized original textures; transform normalization to 4.72 m length; configurable paint, upholstery, wheel finish and lighting; approximate hinged presentation groups; and an optional illustrative spoiler. The source has 179,692 triangles, all retained by the rig. Panel partitions are not a factory rig, and wheel/trim treatments are illustrative rather than exact OEM options.

Upstream rebuild reference: the original model pipeline uses `scripts/assets/import-highland.mjs`, `manifest.json`, and `src/studio/vehicles/highland.ts`. These are not Xiaote build instructions or files supplied by this repository. Xiaote's local reference materials and source credits are in [design-previews/highland-source](../design-previews/highland-source/README.md).

This is not a Tesla-endorsed model. Tesla and its vehicle names remain trademarks of Tesla, Inc.

## Xiaote artwork adaptation

The bundled SVG derives selected hood and emblem contours from the model. Windshield, front silhouette and mirrors were refined for the welcome layout. Lamp shell and DRL were separately traced from a user-provided reference and fitted symmetrically. This is stylized artwork, not factory CAD.
