# The Sovereign Substrate: research papers

[![Principal paper DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.19960841.svg)](https://doi.org/10.5281/zenodo.19960841)
[![Companion paper DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.20237900.svg)](https://doi.org/10.5281/zenodo.20237900)
[![Formal companion DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.20478803.svg)](https://doi.org/10.5281/zenodo.20478803)
[![Licence: CC BY 4.0](https://img.shields.io/badge/Licence-CC%20BY%204.0-blue.svg)](https://creativecommons.org/licenses/by/4.0/)

Research papers on the Sovereign Substrate: an architecture for preserving authority through computational composition.

## The papers

### Principal paper

*The Sovereign Substrate: A constitutional architecture for governed computation* (S. Wheeler).

The architectural treatise. Develops the structural problem, specifies three primitive types composing under eight protocol mechanisms, anchors authority chains at constitutional source credentials, and uses canonical cases from public record to exhibit how the architecture's machinery would have surfaced or constrained the failure in each.

- Zenodo: <https://doi.org/10.5281/zenodo.19960841>
- Latest PDF in this repository: [sovereign_substrate_v1_0.pdf](sovereign_substrate_v1_0.pdf)
- Markdown source: [sovereign_substrate_v1_0.md](sovereign_substrate_v1_0.md)

### Companion paper

*The Sovereign Substrate: Reference Architecture and Implementation* (S. Wheeler).

The technical companion. Specifies the architecture at conformance depth and documents the reference implementation that conforms to it. Names the architectural commitments not yet substantiated by the prototype.

- Zenodo: <https://doi.org/10.5281/zenodo.20237900>
- Latest PDF in this repository: [sovereign_substrate_reference_architecture.pdf](sovereign_substrate_reference_architecture.pdf)
- Markdown source: [sovereign_substrate_reference_architecture.md](sovereign_substrate_reference_architecture.md)

### Formal companion

*The Sovereign Substrate: A Machine-Checked Model of Constitutional Currency* (S. Wheeler).

The formal companion. Answers two of the architecture's open formal questions about constitutional currency: the correct formalisation of "no act executes under stale governance" (an invocation-event property, with the natural state-invariant encoding machine-refuted), and a certified bound under which affected compiled forms cease to authorise execution within bounded latency, uniform across all six invalidation triggers and proved through the genuine transitive cascade. The model is checked with the TLA+ Proof System and TLC; the proof artifacts accompany the paper.

- Zenodo: <https://doi.org/10.5281/zenodo.20478803>
- Latest PDF in this repository: [sovereign_substrate_currency_model.pdf](sovereign_substrate_currency_model.pdf)
- Markdown source: [sovereign_substrate_currency_model.md](sovereign_substrate_currency_model.md)
- Proof artifacts: [currency-model/artifacts/](currency-model/artifacts/)

## Reference implementation

The Python reference implementation lives in a separate repository, independently archived on Zenodo:

- Repository: <https://github.com/swheeler-research/substrate-reference>
- Zenodo: <https://doi.org/10.5281/zenodo.20238427>

## Citation

Principal paper:

> Wheeler, S. *The Sovereign Substrate: A constitutional architecture for governed computation*. Zenodo. <https://doi.org/10.5281/zenodo.19960841>

Companion paper:

> Wheeler, S. *The Sovereign Substrate: Reference Architecture and Implementation*. Zenodo. <https://doi.org/10.5281/zenodo.20237900>

Formal companion:

> Wheeler, S. *The Sovereign Substrate: A Machine-Checked Model of Constitutional Currency*. Zenodo. <https://doi.org/10.5281/zenodo.20478803>

BibTeX, RIS, CSL, and CFF exports are available on each Zenodo record's landing page. The repository's `CITATION.cff` carries citation metadata in machine-readable form.

## Licence

Both papers are licensed under the [Creative Commons Attribution 4.0 International licence](https://creativecommons.org/licenses/by/4.0/) (CC BY 4.0). Copy, redistribute, adapt, and build upon the work in any medium or format, including for commercial purposes, on the single condition that the author and the work are attributed.

## Correspondence

S. Wheeler, independent researcher. ORCID: [0009-0009-8693-0148](https://orcid.org/0009-0009-8693-0148). Email: swheeler-research@proton.me.