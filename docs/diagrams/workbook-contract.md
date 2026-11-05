# Reference workbook observations

The sample input and output are independent product sets, not a matching input/output pair. The checked-in files under `spec/fixtures/files/` are reference examples; product data is not a production knowledge source or evidence of verified fitment.

Both files have these sheets in order: `Origen`, `Métricas`, `Aplicaciones`, `Intercambios`, `Atributos`, `Catálogo`. Exact observed table headers and metric labels are captured in `Catalog::WorkbookContract` and exercised in specs. `Métricas` is a positional report, not a header-based table.

The output example merges `Métricas!A1:B1`; its four normalized table sheets use a common header style, while `Origen` uses several header styles. These are observed formatting details, not yet a complete presentation contract. No other merged ranges were observed in those output sheets. Raw XLSX style IDs are workbook-local and should not be used as portable style definitions.

| Sheet | Input populated data rows | Output populated data rows |
|---|---:|---:|
| Origen | 5 | 10 |
| Aplicaciones | 0 | 2,610 |
| Intercambios | 0 | 31 |
| Atributos | 0 | 74 |
| Catálogo | 0 | 10 |

The output metrics report 10 references, 2,610 applications, 31 interchanges and 74 attributes. Its increment cells B6, B10 and B14 use formulas `B4-B5`, `B8-B9` and `B12-B13`; the sample input uses literal zeros. The rows and cells are frequently formatted beyond actual data, so worksheet dimensions are not record counts.

## Observed field values and relationships

These observations describe the fixture, not universal validation rules. Table headers are row 1; `Métricas` has labels in column A and values in column B. Text is predominantly stored as spreadsheet strings; source `Cod interno`, application year, liters and cylinder count are numeric in this sample. Application model and submodel can be numeric or text; CC and CID contain both numbers and text. Attribute `Valor` also mixes numbers and text. Do not coerce identifiers or mixed-type fields to numbers merely because some samples are numeric. `Posición` is blank in every example application; attribute `Unidad` is blank in 45 of the 74 example rows. These observations alone do not establish required versus optional fields.

In the output example, `Origen` column B and the other four table sheets' column A contain matching references. Every output reference joins to one `Catálogo` row, with the following associated counts:

| Reference | Brand in source | Applications | Interchanges | Attributes |
|---|---|---:|---:|---:|
| 2C4516+STD | HASTING | 299 | 3 | 6 |
| 31-04256-000 | YENMAK | 31 | 3 | 3 |
| 44338+20 | TEIKIN | 150 | 6 | 9 |
| 9-4180SA | CLOYES | 85 | 3 | 10 |
| CK329LK1 | CONTITECH | 605 | 2 | 5 |
| DDM-77020 | TECH TIMMING | 833 | 3 | 8 |
| DM-152 | TECH OIL PUMPS | 120 | 6 | 12 |
| FSX-5840299 | FRACO | 69 | 2 | 3 |
| S35034+STD | ENGINETECH | 85 | 1 | 3 |
| TK4650 | REVO | 333 | 2 | 15 |

There are no exact duplicate populated table rows in this output example; future workbooks may legitimately contain duplicates, so the comparator must not discard them. No output reference in these four sheets was unmatched in this sample. SKU alone is an observed join key here, not a guaranteed globally unique product identity: brand and variant must be retained.

## Extraction and evidence hypotheses

- `2C4516+STD` contains an engine-code candidate `QR25DE` and a dimension expression `89X1.2X1.2X2`; its `+STD` suffix is part of its identity.
- `44338+20` contains an oversize suffix, engine candidate `KA24DE` and a ring-width expression `1.2 1.2 2.5`; the suffix must not be dropped when matching variants.
- `FSX-5840299` contains `QR25DE`, `16 VAL`, `MLS` and `89MM` candidates. Extracted text is evidence of a supplier assertion, not by itself proof of every vehicle application in the output.
- `CK329LK1` contains a `197 DIENTES` count; interpreting its attribute and applicability requires a product-family rule.
- Descriptions can contain several reference-like tokens, models and abbreviated year ranges. Their meanings and century boundaries require explicit rules; avoid treating every token as a verified interchange or fitment.
- The output provides no source-level evidence for the large application sets. Their provenance and terms are unknown; they cannot automatically become verified knowledge.

`spec/fixtures/files/canonical_reference_cases.json` captures a small set of source-located candidate facts for later parser specs. These are example expectations, not verified fitments, interchanges or a complete canonical product schema.

The initial comparator compares cached metric values by position and table rows as multisets; it preserves duplicate rows and ignores ordering and trailing empty cells. When comparison keys uniquely identify a row on both sides, it reports field differences for `Origen`, `Catálogo`, `Aplicaciones`, `Intercambios` and `Atributos`. The latter three use conservative combinations of part and relationship fields; ambiguous or incomplete keys fall back to multiset differences rather than guessing a pairing. These comparison keys are not claims of universal product or fitment identity. It does **not** yet check cell formatting, formulas, required types, reference integrity or deterministic export ordering. Those remain M0/M3 work, not implied guarantees. Confirm data provenance and permissible use before promoting any reference facts into knowledge releases.
